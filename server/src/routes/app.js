import express from 'express';
import crypto from 'crypto';
import fs from 'fs/promises';
import multer from 'multer';
import path from 'path';
import { fileURLToPath } from 'url';

import { config } from '../config.js';
import { pool, withTransaction } from '../db.js';
import { ok, fail } from '../utils/http.js';
import { findUserById, findUserByPhone, listUsersByIds, upsertUser } from '../repositories/users.js';
import { incrementFollowCount, incrementFanCount } from '../repositories/profiles.js';
import {
  createPost,
  findPostById,
  listPosts,
  listPostsByUser,
  updatePostLikes,
} from '../repositories/posts.js';
import { ensureChatRoom, findOrderById, findOrderByMerchantOrderNo } from '../repositories/orders.js';
import {
  freezeWithdrawBalance,
  recordWalletTransaction,
  refundWithdrawBalance,
  releasePendingBalance,
} from '../repositories/wallets.js';
import { assertPayloadAllowed, assertTextAllowed, reviewImage, reviewText } from '../services/moderation.js';
import {
  queryAlipayTransfer,
  transferToAlipayAccount,
} from '../services/alipay.js';
import {
  buildTrtcCredential,
  buildTrtcRoomId,
} from '../services/trtc.js';
import { bindAxbVirtualNumber } from '../services/virtual_number.js';
import { hasSmsConfig, sendSmsCode } from '../services/sms.js';

export const appRouter = express.Router();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const uploadsDir = path.resolve(__dirname, '../../uploads');
const reviewImageUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

function handleRoute(handler) {
  return async (req, res, next) => {
    try {
      await handler(req, res, next);
    } catch (error) {
      console.error(`[appRouter] ${req.method} ${req.originalUrl}`, error);
      if (res.headersSent) return;
      if (error.statusCode) {
        return fail(res, error.statusCode, error.message || '请求失败');
      }
      return fail(res, 500, error.message || '服务器内部错误');
    }
  };
}

function getSessionUserId(req) {
  return (
    req.sessionUserId ||
    req.headers['x-user-id']?.toString().trim() ||
    req.authToken ||
    ''
  );
}

function mergeGuideUserFields(row) {
  const firstNonEmpty = (...values) => {
    for (const value of values) {
      const text = value?.toString().trim() ?? '';
      if (text) return text;
    }
    return '';
  };
  const userTags = Array.isArray(row.user_guide_tags)
    ? row.user_guide_tags.filter(Boolean).map((tag) => tag.toString())
    : [];
  return {
    ...row,
    name: firstNonEmpty(row.user_nickname, row.name) || '地陪',
    avatar: firstNonEmpty(row.user_avatar, row.avatar),
    gender: firstNonEmpty(row.user_gender, row.gender),
    city: firstNonEmpty(row.user_city, row.city),
    description: firstNonEmpty(
      row.user_guide_introduction,
      row.user_bio,
      row.description,
    ),
    tags: userTags.length > 0 ? userTags : (row.tags ?? []),
  };
}

function isLegacyAllysaGuide(row) {
  const name = (row.name ?? '').toString().trim().toLowerCase();
  const avatar = (row.avatar ?? '').toString();
  return (
    name === 'allysa艾丽莎' &&
    avatar === 'https://picsum.photos/seed/guide2/100/100'
  );
}

function normalizePhone(phone) {
  const compact = phone.replace(/\s+/g, '');
  if (compact.startsWith('+86')) {
    return compact.slice(3);
  }
  if (compact.startsWith('0086')) {
    return compact.slice(4);
  }
  if (compact.startsWith('86') && compact.length === 13) {
    return compact.slice(2);
  }
  return compact;
}

function readWhitelistCode(phone) {
  return config.authWhitelist[phone] ?? '';
}

function normalizeSmsPurpose(value) {
  const purpose = value?.toString().trim() || 'login';
  if (!/^[a-z_]{1,32}$/.test(purpose)) {
    const error = new Error('验证码用途无效');
    error.statusCode = 400;
    throw error;
  }
  return purpose;
}

function hashSmsCode(phone, purpose, code) {
  return crypto
    .createHash('sha256')
    .update(`${phone}:${purpose}:${code}`)
    .digest('hex');
}

function generateSmsCode() {
  return crypto.randomInt(100000, 1000000).toString();
}

async function issueAuthCode(client, phone, purpose) {
  if (config.aliyunSmsEnabled && !hasSmsConfig()) {
    const error = new Error('阿里云短信环境变量未配置完整');
    error.statusCode = 503;
    throw error;
  }
  if (!config.aliyunSmsEnabled) {
    if (config.authWhitelistEnabled) {
      const whitelistCode = readWhitelistCode(phone);
      if (!whitelistCode) {
        const error = new Error('该手机号不在测试白名单中');
        error.statusCode = 403;
        throw error;
      }
      return whitelistCode;
    }
    const error = new Error('短信服务未开启');
    error.statusCode = 503;
    throw error;
  }

  const recent = await client.query(
    `
      select id
      from public.auth_sms_codes
      where phone = $1 and purpose = $2 and created_at > now() - interval '60 seconds'
      order by created_at desc
      limit 1
    `,
    [phone, purpose],
  );
  if (recent.rows.length > 0) {
    const error = new Error('验证码发送过于频繁，请稍后再试');
    error.statusCode = 429;
    throw error;
  }

  const code = generateSmsCode();
  await client.query(
    `
      insert into public.auth_sms_codes (phone, purpose, code_hash, expires_at)
      values ($1, $2, $3, now() + interval '5 minutes')
    `,
    [phone, purpose, hashSmsCode(phone, purpose, code)],
  );
  try {
    await sendSmsCode(phone, code);
  } catch (error) {
    await client.query(
      `delete from public.auth_sms_codes where phone = $1 and purpose = $2 and consumed_at is null`,
      [phone, purpose],
    );
    throw error;
  }
  return code;
}

async function verifyAuthCode(client, phone, purpose, code) {
  if (config.aliyunSmsEnabled && !hasSmsConfig()) {
    const error = new Error('阿里云短信环境变量未配置完整');
    error.statusCode = 503;
    throw error;
  }
  if (!config.aliyunSmsEnabled) {
    if (!config.authWhitelistEnabled) {
      const error = new Error('短信服务未开启');
      error.statusCode = 503;
      throw error;
    }
    const whitelistCode = readWhitelistCode(phone);
    if (!whitelistCode) {
      const error = new Error('该手机号不在测试白名单中');
      error.statusCode = 403;
      throw error;
    }
    if (code !== whitelistCode) {
      const error = new Error('验证码错误');
      error.statusCode = 400;
      throw error;
    }
    return;
  }

  const result = await client.query(
    `
      select id, code_hash, expires_at, attempts
      from public.auth_sms_codes
      where phone = $1 and purpose = $2 and consumed_at is null
      order by created_at desc
      limit 1
    `,
    [phone, purpose],
  );
  const record = result.rows[0];
  if (!record || new Date(record.expires_at).getTime() <= Date.now()) {
    const error = new Error('验证码已过期，请重新获取');
    error.statusCode = 400;
    throw error;
  }
  if (Number(record.attempts ?? 0) >= 5) {
    const error = new Error('验证码错误次数过多，请重新获取');
    error.statusCode = 429;
    throw error;
  }
  if (hashSmsCode(phone, purpose, code) !== record.code_hash) {
    await client.query('update public.auth_sms_codes set attempts = attempts + 1 where id = $1', [record.id]);
    const error = new Error('验证码错误');
    error.statusCode = 400;
    throw error;
  }
  await client.query('update public.auth_sms_codes set consumed_at = now() where id = $1', [record.id]);
}

function assertPasswordFormat(password) {
  const value = password?.toString() ?? '';
  if (!/^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d!@#$%^&*._-]{8,64}$/.test(value)) {
    const error = new Error('密码需为8-64位，并同时包含字母和数字');
    error.statusCode = 400;
    throw error;
  }
  return value;
}

function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 64).toString('hex');
  return `scrypt$${salt}$${hash}`;
}

function verifyPassword(password, storedHash) {
  const [algorithm, salt, expectedHex] = (storedHash ?? '').split('$');
  if (algorithm !== 'scrypt' || !salt || !expectedHex) return false;
  const actual = crypto.scryptSync(password, salt, 64);
  const expected = Buffer.from(expectedHex, 'hex');
  return actual.length === expected.length && crypto.timingSafeEqual(actual, expected);
}

function assertAuthCode(phone, code) {
  if (config.authWhitelistEnabled) {
    const whitelistCode = readWhitelistCode(phone);
    if (!whitelistCode) {
      const error = new Error('该手机号不在测试白名单中');
      error.statusCode = 403;
      throw error;
    }
    if (code !== whitelistCode) {
      const error = new Error('验证码错误');
      error.statusCode = 400;
      throw error;
    }
  }
}

function sanitizeFilenamePart(value, fallback = 'file') {
  const normalized = value?.toString().trim() ?? '';
  const safe = normalized.replace(/[^0-9A-Za-z._-]/g, '_');
  return safe || fallback;
}

function detectExtension(filename, mimeType) {
  const ext = path.extname(filename ?? '').toLowerCase();
  if (ext) return ext;
  switch ((mimeType ?? '').toLowerCase()) {
    case 'image/png':
      return '.png';
    case 'image/webp':
      return '.webp';
    case 'image/gif':
      return '.gif';
    default:
      return '.jpg';
  }
}

async function persistBase64Upload({
  category,
  filename,
  mimeType,
  bytesBase64,
}) {
  if (!bytesBase64?.toString().trim()) {
    throw new Error('缺少图片数据');
  }

  const categoryDir = path.join(uploadsDir, category);
  await fs.mkdir(categoryDir, { recursive: true });

  const safeName = sanitizeFilenamePart(
    path.basename(filename ?? '', path.extname(filename ?? '')),
    category,
  );
  const ext = detectExtension(filename, mimeType);
  const finalName = `${Date.now()}_${safeName}${ext}`;
  const absolutePath = path.join(categoryDir, finalName);
  const buffer = Buffer.from(bytesBase64, 'base64');
  await fs.writeFile(absolutePath, buffer);

  return `/uploads/${category}/${finalName}`;
}

async function persistUploadedFile({ category, file }) {
  if (!file?.buffer?.length) {
    throw new Error('缺少图片文件');
  }
  const categoryDir = path.join(uploadsDir, category);
  await fs.mkdir(categoryDir, { recursive: true });
  const safeName = sanitizeFilenamePart(
    path.basename(file.originalname ?? '', path.extname(file.originalname ?? '')),
    category,
  );
  const ext = detectExtension(file.originalname, file.mimetype);
  const finalName = `${Date.now()}_${safeName}${ext}`;
  const absolutePath = path.join(categoryDir, finalName);
  await fs.writeFile(absolutePath, file.buffer);
  return `/uploads/${category}/${finalName}`;
}

function buildPublicUrl(req, relativePath) {
  const forwardedProto = req.headers['x-forwarded-proto']?.toString().trim();
  const protocol = forwardedProto || req.protocol || 'http';
  const host = req.headers.host?.toString().trim();
  if (!host) {
    return relativePath;
  }
  return `${protocol}://${host}${relativePath}`;
}

function toNullableNumber(value) {
  if (value == null || value === '') return null;
  const parsed = Number.parseFloat(value.toString());
  return Number.isFinite(parsed) ? parsed : null;
}

function haversineDistanceMeters(lat1, lng1, lat2, lng2) {
  if ([lat1, lng1, lat2, lng2].some((item) => item == null)) {
    return null;
  }
  const toRadians = (value) => (value * Math.PI) / 180;
  const earthRadius = 6371000;
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(earthRadius * c);
}

function parseServiceDate(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date;
}

function dateOnly(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function daysFromToday(date) {
  const today = new Date();
  const start = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const target = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  return Math.floor((target.getTime() - start.getTime()) / 86400000);
}

function assertDateWindow(date, maxOffsetDays, errorCode) {
  const offset = daysFromToday(date);
  if (offset < 0 || offset > maxOffsetDays) {
    const error = new Error(errorCode);
    error.statusCode = 400;
    throw error;
  }
}

function timeOnly(date) {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}:00`;
}

function didiTravelFare(distanceMeters, serviceDate) {
  if (distanceMeters == null || distanceMeters <= 0) return 0;
  const date = serviceDate instanceof Date ? serviceDate : new Date(serviceDate);
  const isRestDay = date.getDay() === 0 || date.getDay() === 6;
  const minutes = Math.max(8, Math.round((distanceMeters / 1000 / 30) * 60));
  const km = distanceMeters / 1000;
  let base = isRestDay ? 9.4 : 9.4;
  let kmRate = isRestDay ? 1.44 : 1.38;
  let minuteRate = isRestDay ? 0.28 : 0.31;
  const hour = date.getHours() + date.getMinutes() / 60;
  if (isRestDay) {
    if (hour >= 0 && hour < 6) { base = 10.2; kmRate = 2.44; minuteRate = 0.33; }
    else if (hour >= 7 && hour < 9) { base = 9.7; kmRate = 1.49; minuteRate = 0.42; }
    else if (hour >= 16 && hour < 19) { base = 10.2; kmRate = 1.48; minuteRate = 0.43; }
    else if (hour >= 20 && hour < 22) { base = 9.8; kmRate = 1.44; minuteRate = 0.35; }
    else if (hour >= 23) { base = 10.2; kmRate = 2.44; minuteRate = 0.33; }
  } else if (hour < 5 || hour >= 23) {
    base = 10.2; kmRate = 2.38; minuteRate = 0.35;
  } else if (hour >= 7 && hour < 9) {
    base = 10.3; kmRate = 1.58; minuteRate = 0.47;
  } else if (hour >= 17 && hour < 19) {
    base = 9.9; kmRate = 1.56; minuteRate = 0.43;
  }
  const includedKm = 3;
  const includedMinutes = 8;
  const longDistanceFee =
    Math.max(0, Math.min(km, 24) - 12) * 0.39 +
    Math.max(0, Math.min(km, 35) - 24) * 0.60 +
    Math.max(0, km - 35) * 0.68;
  const fare = base +
    Math.max(0, km - includedKm) * kmRate +
    Math.max(0, minutes - includedMinutes) * minuteRate +
    longDistanceFee;
  return Math.round(fare * 100) / 100;
}

async function calculateOrderPricing(client, { guideId, serviceItemId, serviceHours, serviceDate, serviceLat, serviceLng }) {
  const hours = Number(serviceHours);
  if (!Number.isFinite(hours) || hours <= 0 || hours > 24) {
    const error = new Error('service_hours_invalid');
    error.statusCode = 400;
    throw error;
  }
  const date = parseServiceDate(serviceDate);
  if (!date) {
    const error = new Error('service_date_invalid');
    error.statusCode = 400;
    throw error;
  }
  assertDateWindow(date, 6, 'service_date_must_be_within_7_days');
  const itemResult = await client.query(
    `select s.*, u.nickname as guide_nickname, u.avatar as guide_avatar, u.guide_tags, g.current_lat, g.current_lng
     from public.guide_service_items s
     join public.users u on u.id = s.guide_id
     join public.guides g on g.id = s.guide_id
     where s.id = $1 and s.guide_id = $2 and s.enabled = true and g.verified = true
     limit 1`,
    [serviceItemId, guideId],
  );
  const item = itemResult.rows[0];
  if (!item) {
    const error = new Error('service_item_not_available');
    error.statusCode = 400;
    throw error;
  }
  const tags = Array.isArray(item.guide_tags) ? item.guide_tags.map((tag) => tag?.toString()) : [];
  if (!tags.includes(item.service_type || item.name)) {
    const error = new Error('service_item_not_in_guide_profile');
    error.statusCode = 400;
    throw error;
  }
  const endDate = new Date(date.getTime() + hours * 60 * 60 * 1000);
  if (dateOnly(endDate) !== dateOnly(date)) {
    const error = new Error('service_cannot_cross_midnight');
    error.statusCode = 400;
    throw error;
  }
  const availability = await client.query(
    `select 1 from public.guide_availability
     where guide_id = $1 and is_available = true
       and start_time <= $3::time and end_time >= $4::time
       and (
         (coalesce(recurrence_type, 'exact') = 'exact' and (service_date = $2::date or date_start = $2::date))
         or (coalesce(recurrence_type, 'exact') = 'daily' and (date_start is null or date_start <= $2::date) and (date_end is null or date_end >= $2::date))
         or (coalesce(recurrence_type, 'exact') = 'weekly' and extract(isodow from $2::date)::int = any(weekdays) and (date_start is null or date_start <= $2::date) and (date_end is null or date_end >= $2::date))
       ) limit 1`,
    [guideId, dateOnly(date), timeOnly(date), timeOnly(endDate)],
  );
  if (!availability.rows[0]) {
    const error = new Error('guide_not_available_at_selected_time');
    error.statusCode = 400;
    throw error;
  }
  const guideLat = toNullableNumber(item.current_lat);
  const guideLng = toNullableNumber(item.current_lng);
  const customerLat = toNullableNumber(serviceLat);
  const customerLng = toNullableNumber(serviceLng);
  const straightDistance = haversineDistanceMeters(guideLat, guideLng, customerLat, customerLng);
  const routeDistance = straightDistance == null
    ? null
    : Math.round(straightDistance * config.serviceRoadDistanceMultiplier);
  const serviceFee = Math.round(Number(item.price_per_hour) * hours * 100) / 100;
  const travelFee = didiTravelFare(routeDistance, date);
  const platformFee = Math.round(serviceFee * 0.4 * 100) / 100;
  const guideIncome = Math.round((serviceFee * 0.6 + travelFee) * 100) / 100;
  return {
    item,
    serviceHours: hours,
    serviceFee,
    travelFee,
    platformFee,
    guideIncome,
    totalAmount: Math.round((serviceFee + travelFee) * 100) / 100,
    guideServiceLat: guideLat,
    guideServiceLng: guideLng,
    routeDistanceMeters: routeDistance,
  };
}

function withDistanceFields(row, guideLocation) {
  if (!row) return row;
  const serviceLat = toNullableNumber(row.service_lat);
  const serviceLng = toNullableNumber(row.service_lng);
  const guideLat = toNullableNumber(
    guideLocation?.current_lat ?? row.current_lat ?? row.guide_current_lat,
  );
  const guideLng = toNullableNumber(
    guideLocation?.current_lng ?? row.current_lng ?? row.guide_current_lng,
  );
  const straightDistanceMeters = haversineDistanceMeters(
    guideLat,
    guideLng,
    serviceLat,
    serviceLng,
  );
  return {
    ...row,
    service_lat: serviceLat,
    service_lng: serviceLng,
    guide_current_lat: guideLat,
    guide_current_lng: guideLng,
    distance_meters: row.distance_meters ?? straightDistanceMeters,
    route_distance_meters:
      row.route_distance_meters ?? straightDistanceMeters,
    route_duration_seconds:
      row.route_duration_seconds ??
      (straightDistanceMeters == null
        ? null
        : Math.max(60, Math.round(straightDistanceMeters / 1.1))),
  };
}

async function fetchGuideLocation(client, guideId) {
  if (!guideId) return null;
  const result = await client.query(
    `
      select
        current_lat,
        current_lng,
        current_location_text,
        location_updated_at
      from public.guides
      where id = $1
      limit 1
    `,
    [guideId],
  );
  return result.rows[0] ?? null;
}

async function requireSessionUser(req, res) {
  const userId = getSessionUserId(req);
  if (!userId) {
    fail(res, 401, '未登录');
    return null;
  }
  return userId;
}

async function requireAdminUser(req, res) {
  const userId = await requireSessionUser(req, res);
  if (!userId) return null;
  const user = await hydrateUser(pool, userId);
  if (!user?.is_admin) {
    fail(res, 403, '无管理员权限');
    return null;
  }
  return userId;
}

async function requireGuideUser(req, res) {
  const userId = await requireSessionUser(req, res);
  if (!userId) return null;
  const result = await pool.query(
    `select exists(select 1 from public.guides where id = $1) as is_guide`,
    [userId],
  );
  if (!result.rows[0]?.is_guide) {
    fail(res, 403, '只有已通过地陪申请的账号才能操作钱包提现');
    return null;
  }
  return userId;
}

async function hydrateUser(client, userId) {
  const user = await findUserById(client, userId);
  if (!user) return null;
  const roleResult = await client.query(
    `
      select
        coalesce((select count(*) from public.follows where follower_id = $1), 0) as follow_count,
        coalesce((select count(*) from public.follows where followed_id = $1), 0) as fans_count,
        exists(select 1 from public.guides where id = $1) as is_guide,
        (
          select status
          from public.guide_applications
          where user_id = $1
          order by created_at desc
          limit 1
        ) as guide_application_status
    `,
    [userId],
  );
  const role = roleResult.rows[0] ?? {};
  return {
    ...user,
    follow_count: Number(role.follow_count ?? 0),
    fans_count: Number(role.fans_count ?? 0),
    is_guide: role.is_guide === true || role.guide_application_status === 'approved',
    guide_application_status: role.guide_application_status,
  };
}

appRouter.post('/auth/send-code', handleRoute(async (req, res) => {
  const phone = normalizePhone(req.body?.phone?.toString().trim() ?? '');
  const purpose = normalizeSmsPurpose(req.body?.purpose);
  if (!phone) return fail(res, 400, '手机号不能为空');
  await issueAuthCode(pool, phone, purpose);
  return ok(res, { message: '验证码已发送', data: { phone } });
}));

appRouter.post('/auth/verify-code', handleRoute(async (req, res) => {
  const phone = normalizePhone(req.body?.phone?.toString().trim() ?? '');
  const code = req.body?.code?.toString().trim() ?? '';
  if (!phone) return fail(res, 400, '手机号不能为空');
  if (!code) return fail(res, 400, '验证码不能为空');

  await verifyAuthCode(pool, phone, 'login', code);

  const existingUser = await findUserByPhone(pool, phone);
  const userId = existingUser?.id ?? crypto.randomUUID();
  const session = {
    access_token: userId,
    user_id: userId,
  };
  // Existing users may have edited their profile in either client. Do not
  // run the default initialization upsert again at every login, otherwise
  // the login flow would overwrite their nickname, avatar and guide profile.
  if (!existingUser) {
    await upsertUser(pool, {
      id: userId,
      phone,
      nickname: phone,
      avatar: 'https://picsum.photos/seed/user/100/100',
      vip_level: 1,
      title: '初级旅行家',
      balance: 0,
      coupon_count: 0,
      follow_count: 0,
      fans_count: 0,
      is_banned: false,
      cancel_count: 0,
      is_admin: false,
    });
  }
  return ok(res, { message: '登录成功', session });
}));

appRouter.post('/auth/login-password', handleRoute(async (req, res) => {
  const phone = normalizePhone(req.body?.phone?.toString().trim() ?? '');
  const password = req.body?.password?.toString() ?? '';
  if (!phone) return fail(res, 400, '手机号不能为空');
  if (!password) return fail(res, 400, '密码不能为空');

  const user = await findUserByPhone(pool, phone);
  if (!user?.password_hash || !verifyPassword(password, user.password_hash)) {
    return fail(res, 401, '手机号或密码错误');
  }
  return ok(res, {
    message: '登录成功',
    session: { access_token: user.id, user_id: user.id },
  });
}));

appRouter.post('/auth/reset-password', handleRoute(async (req, res) => {
  const phone = normalizePhone(req.body?.phone?.toString().trim() ?? '');
  const code = req.body?.code?.toString().trim() ?? '';
  const newPassword = assertPasswordFormat(req.body?.new_password);
  if (!phone) return fail(res, 400, '手机号不能为空');
  if (!code) return fail(res, 400, '验证码不能为空');
  await verifyAuthCode(pool, phone, 'reset_password', code);

  const user = await findUserByPhone(pool, phone);
  if (!user) return fail(res, 404, '该手机号尚未注册');
  await pool.query(
    'update public.users set password_hash = $1 where id = $2',
    [hashPassword(newPassword), user.id],
  );
  return ok(res, { message: '密码已重置' });
}));

appRouter.post('/auth/logout', async (_req, res) => {
  return ok(res, { message: '已退出登录' });
});

appRouter.post('/moderation/review', handleRoute(async (req, res) => {
  const payload = req.body ?? {};
  await assertTextAllowed(payload.text?.toString() ?? '', {
    field: payload.field?.toString() || '内容',
  });
  return ok(res, { data: { passed: true }, message: '审核通过' });
}));

appRouter.get('/users/me', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const user = await hydrateUser(pool, userId);
  if (!user) return fail(res, 404, '用户不存在');
  return ok(res, { data: user });
});

appRouter.put('/users/me', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const currentUser = await findUserById(pool, userId);
  if (!currentUser) return fail(res, 404, '用户不存在');
  const updated = await upsertUser(pool, {
    id: userId,
    phone: currentUser.phone,
    nickname: payload.nickname ?? currentUser.nickname ?? '新用户',
    avatar: payload.avatar ?? currentUser.avatar ?? '',
    bio: payload.bio ?? currentUser.bio ?? '',
    gender: payload.gender ?? currentUser.gender ?? '',
    city: payload.city ?? currentUser.city ?? '',
    birthday: payload.birthday ?? currentUser.birthday ?? '',
    wechat: payload.wechat ?? currentUser.wechat ?? '',
    occupation: payload.occupation ?? currentUser.occupation ?? '',
    ethnicity: payload.ethnicity ?? currentUser.ethnicity ?? '',
    education: payload.education ?? currentUser.education ?? '',
    height_cm: payload.height_cm ?? currentUser.height_cm ?? 0,
    weight_kg: payload.weight_kg ?? currentUser.weight_kg ?? 0,
    guide_introduction:
      payload.guide_introduction ?? currentUser.guide_introduction ?? '',
    guide_tags: payload.guide_tags ?? currentUser.guide_tags ?? [],
    service_description:
      payload.service_description ?? currentUser.service_description ?? '',
    extra_fee_description:
      payload.extra_fee_description ?? currentUser.extra_fee_description ?? '',
    vip_level: currentUser.vip_level ?? 0,
    title: payload.title ?? currentUser.title ?? '',
    balance: currentUser.balance ?? 0,
    coupon_count: currentUser.coupon_count ?? 0,
    follow_count: currentUser.follow_count ?? 0,
    fans_count: currentUser.fans_count ?? 0,
    is_banned: currentUser.is_banned ?? false,
    cancel_count: currentUser.cancel_count ?? 0,
    is_admin: currentUser.is_admin ?? false,
  });
  if (updated?.id) {
    const guideRole = await pool.query(
      `
        select
          exists(select 1 from public.guides where id = $1) as guide_exists,
          exists(
            select 1
            from public.guide_applications
            where user_id = $1 and status = 'approved'
          ) as approved_application
      `,
      [updated.id],
    );
    const role = guideRole.rows[0] ?? {};
    if (role.guide_exists || role.approved_application) {
      await pool.query(
        `
          insert into public.guides (
            id, name, avatar, gender, verified, tags, description, city
          ) values ($1, $2, $3, $4, true, $5::text[], $6, $7)
          on conflict (id) do update set
            name = excluded.name,
            avatar = excluded.avatar,
            gender = excluded.gender,
            verified = true,
            tags = excluded.tags,
            description = excluded.description,
            city = excluded.city
        `,
        [
          updated.id,
          updated.nickname ?? '',
          updated.avatar ?? '',
          updated.gender ?? '',
          updated.guide_tags ?? [],
          (updated.guide_introduction ?? '').toString().trim() ||
            (updated.bio ?? '').toString(),
          updated.city ?? '',
        ],
      );
    }
  }
  if (updated?.id && (payload.guide_tags ?? payload.guideTags)) {
    await pool.query(
      `
        update public.guides
        set tags = $2::text[]
        where id = $1
      `,
      [updated.id, payload.guide_tags ?? payload.guideTags ?? []],
    );
  }
  // The raw users row has no guide role columns. Return the hydrated profile so
  // editing an avatar cannot make an approved guide look like a normal user.
  return ok(res, { data: await hydrateUser(pool, updated.id) });
});

appRouter.get('/users/:id', async (req, res) => {
  const user = await hydrateUser(pool, req.params.id);
  if (!user) return fail(res, 404, '用户不存在');
  return ok(res, { data: user });
});

appRouter.get('/users/:id/context', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const targetId = req.params.id;
  const following = await pool.query(
    `select 1 from public.follows where follower_id = $1 and followed_id = $2 limit 1`,
    [userId, targetId],
  );
  return ok(res, { data: { is_following: following.rowCount > 0 } });
});

appRouter.get('/users/:id/interactions', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const favoriteIds = await pool.query(
    `select guide_id from public.favorites where user_id = $1`,
    [userId],
  );
  const likedIds = await pool.query(
    `select guide_id from public.guide_likes where user_id = $1`,
    [userId],
  );
  const footprints = await pool.query(
    `
      select g.*
      from public.footprints f
      join public.guides g on g.id = f.guide_id
      where f.user_id = $1
      order by f.last_visited_at desc
    `,
    [userId],
  );
  const followingGuides = await pool.query(
    `
      select followed_id
      from public.follows f
      join public.guides g on g.id = f.followed_id
      where f.follower_id = $1
    `,
    [userId],
  );
  return ok(res, {
    data: {
      favorite_ids: favoriteIds.rows.map((row) => row.guide_id),
      liked_ids: likedIds.rows.map((row) => row.guide_id),
      following_guide_ids: followingGuides.rows.map((row) => row.followed_id),
      footprints: footprints.rows,
    },
  });
});

appRouter.get('/users/me/following', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const result = await pool.query(
    `
      select
        u.*,
        true as is_guide,
        coalesce((
          select status
          from public.guide_applications
          where user_id = u.id
          order by created_at desc
          limit 1
        ), 'approved') as guide_application_status
      from public.follows f
      join public.users u on u.id = f.followed_id
      join public.guides g on g.id = f.followed_id
      where f.follower_id = $1
      order by f.created_at desc
    `,
    [userId],
  );
  return ok(res, { data: result.rows });
});

appRouter.post('/users/:id/follow', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const targetId = req.params.id;
  await pool.query(
    `insert into public.follows (follower_id, followed_id) values ($1, $2) on conflict do nothing`,
    [userId, targetId],
  );
  await incrementFollowCount(pool, userId, 1);
  await incrementFanCount(pool, targetId, 1);
  return ok(res, { message: '关注成功' });
});

appRouter.delete('/users/:id/follow', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const targetId = req.params.id;
  await pool.query(
    `delete from public.follows where follower_id = $1 and followed_id = $2`,
    [userId, targetId],
  );
  await incrementFollowCount(pool, userId, -1);
  await incrementFanCount(pool, targetId, -1);
  return ok(res, { message: '取消关注成功' });
});

appRouter.get('/guides', async (_req, res) => {
  const durableGuides = await pool.query(
    `
      select
        g.*,
        u.nickname as user_nickname,
        u.avatar as user_avatar,
        u.gender as user_gender,
        u.city as user_city,
        u.bio as user_bio,
        u.guide_introduction as user_guide_introduction,
        u.guide_tags as user_guide_tags,
        u.ethnicity,
        u.education,
        u.height_cm,
        u.weight_kg,
        u.service_description,
        u.extra_fee_description,
        coalesce((select count(*) from public.orders o where o.guide_id = g.id), 0)::int as total_orders,
        coalesce((select avg(r.rating) / 5.0 * 100 from public.guide_reviews r where r.guide_id = g.id), 0)::double precision as good_rate,
        coalesce((
          select json_agg(item order by item.updated_at desc)
          from (
            select id, name, service_type, description, price_per_hour, price_per_day, updated_at
            from public.guide_service_items
            where guide_id = g.id and enabled = true and price_per_hour > 0
          ) item
        ), '[]'::json) as service_items,
        coalesce((
          select json_agg(schedule order by schedule.date_start, schedule.start_time)
          from (
            select id, service_date, date_start, date_end, start_time, end_time,
              recurrence_type, weekdays, is_available
            from public.guide_availability
            where guide_id = g.id and is_available = true
              and (service_date >= current_date or date_end >= current_date or date_end is null)
          ) schedule
        ), '[]'::json) as availability
      from public.guides g
      left join public.users u on u.id = g.id
      where g.verified = true
      order by g.created_at desc
    `,
  );
  return ok(res, {
    data: durableGuides.rows
      .filter((row) => !isLegacyAllysaGuide(row))
      .map(mergeGuideUserFields),
  });

  /* Legacy application-table fallback removed: guides is the single source of truth.
  const result = await pool.query(
    `
      select
        u.id,
        coalesce(nullif(u.nickname, ''), nullif(g.name, ''), nullif(ga.full_name, ''), '地陪') as name,
        coalesce(nullif(u.avatar, ''), nullif(g.avatar, ''), nullif(ga.avatar, ''), '') as avatar,
        coalesce(g.rating, 0) as rating,
        coalesce(nullif(u.gender, ''), nullif(g.gender, ''), nullif(ga.gender, ''), '') as gender,
        true as verified,
        case
          when coalesce(array_length(u.guide_tags, 1), 0) > 0 then u.guide_tags
          when coalesce(array_length(g.tags, 1), 0) > 0 then g.tags
          else coalesce(ga.service_tags, '{}'::text[])
        end as tags,
        coalesce(
          nullif(u.guide_introduction, ''),
          nullif(u.bio, ''),
          nullif(g.description, ''),
          nullif(ga.bio, ''),
          ''
        ) as description,
        coalesce(g.images, ga.images, '{}'::text[]) as images,
        coalesce(g.views, 0) as views,
        coalesce(g.likes, 0) as likes,
        coalesce(g.fans, 0) as fans,
        coalesce(nullif(u.city, ''), nullif(g.city, ''), nullif(ga.city, ''), '') as city,
        coalesce(g.created_at, u.created_at, ga.created_at) as created_at
      from public.users u
      left join public.guides g on g.id = u.id
      left join lateral (
        select full_name, avatar, gender, city, bio, service_tags, images, created_at
        from public.guide_applications
        where user_id = u.id and status = 'approved'
        order by created_at desc nulls last
        limit 1
      ) ga on true
      where g.id is not null or ga.created_at is not null
      order by coalesce(g.created_at, u.created_at, ga.created_at) desc nulls last
    `,
  );
  return ok(res, {
    data: result.rows
      .filter((row) => !isLegacyAllysaGuide(row))
      .map(mergeGuideUserFields),
  });
  */
});

appRouter.get('/guides/:id', async (req, res) => {
  const durableGuide = await pool.query(
    `
      select
        g.*,
        u.nickname as user_nickname,
        u.avatar as user_avatar,
        u.gender as user_gender,
        u.city as user_city,
        u.bio as user_bio,
        u.guide_introduction as user_guide_introduction,
        u.guide_tags as user_guide_tags,
        u.ethnicity,
        u.education,
        u.height_cm,
        u.weight_kg,
        u.service_description,
        u.extra_fee_description,
        coalesce((select count(*) from public.orders o where o.guide_id = g.id), 0)::int as total_orders,
        coalesce((select avg(r.rating) / 5.0 * 100 from public.guide_reviews r where r.guide_id = g.id), 0)::double precision as good_rate,
        coalesce((
          select json_agg(item order by item.updated_at desc)
          from (
            select id, name, service_type, description, price_per_hour, price_per_day, updated_at
            from public.guide_service_items
            where guide_id = g.id and enabled = true and price_per_hour > 0
          ) item
        ), '[]'::json) as service_items,
        coalesce((
          select json_agg(schedule order by schedule.date_start, schedule.start_time)
          from (
            select id, service_date, date_start, date_end, start_time, end_time,
              recurrence_type, weekdays, is_available
            from public.guide_availability
            where guide_id = g.id and is_available = true
              and (service_date >= current_date or date_end >= current_date or date_end is null)
          ) schedule
        ), '[]'::json) as availability,
        coalesce((
          select json_agg(review order by review.created_at desc)
          from (
            select rating, content, images, guide_reply, created_at
            from public.guide_reviews
            where guide_id = g.id
            limit 10
          ) review
        ), '[]'::json) as reviews
      from public.guides g
      left join public.users u on u.id = g.id
      where g.id = $1 and g.verified = true
      limit 1
    `,
    [req.params.id],
  );
  if (!durableGuide.rows[0] || isLegacyAllysaGuide(durableGuide.rows[0])) {
    return fail(res, 404, 'guide not found');
  }
  return ok(res, { data: mergeGuideUserFields(durableGuide.rows[0]) });

  /* Legacy application-table fallback removed: guides is the single source of truth.
  const result = await pool.query(
    `
      select
        u.id,
        coalesce(nullif(u.nickname, ''), nullif(g.name, ''), nullif(ga.full_name, ''), '地陪') as name,
        coalesce(nullif(u.avatar, ''), nullif(g.avatar, ''), nullif(ga.avatar, ''), '') as avatar,
        coalesce(g.rating, 0) as rating,
        coalesce(nullif(u.gender, ''), nullif(g.gender, ''), nullif(ga.gender, ''), '') as gender,
        true as verified,
        case
          when coalesce(array_length(u.guide_tags, 1), 0) > 0 then u.guide_tags
          when coalesce(array_length(g.tags, 1), 0) > 0 then g.tags
          else coalesce(ga.service_tags, '{}'::text[])
        end as tags,
        coalesce(
          nullif(u.guide_introduction, ''),
          nullif(u.bio, ''),
          nullif(g.description, ''),
          nullif(ga.bio, ''),
          ''
        ) as description,
        coalesce(g.images, ga.images, '{}'::text[]) as images,
        coalesce(g.views, 0) as views,
        coalesce(g.likes, 0) as likes,
        coalesce(g.fans, 0) as fans,
        coalesce(nullif(u.city, ''), nullif(g.city, ''), nullif(ga.city, ''), '') as city,
        coalesce((
          select json_agg(item order by item.updated_at desc)
          from (
            select id, name, service_type, description, price_per_hour, price_per_day, updated_at
            from public.guide_service_items
            where guide_id = u.id and enabled = true and price_per_hour > 0
          ) item
        ), '[]'::json) as service_items,
        coalesce((
          select json_agg(review order by review.created_at desc)
          from (
            select rating, content, guide_reply, created_at
            from public.guide_reviews
            where guide_id = u.id
            limit 10
          ) review
        ), '[]'::json) as reviews
      from public.users u
      left join public.guides g on g.id = u.id
      left join lateral (
        select full_name, avatar, gender, city, bio, service_tags, images, created_at
        from public.guide_applications
        where user_id = u.id and status = 'approved'
        order by created_at desc nulls last
        limit 1
      ) ga on true
      where u.id = $1 and (g.id is not null or ga.created_at is not null)
      limit 1
    `,
    [req.params.id],
  );
  if (!result.rows[0] || isLegacyAllysaGuide(result.rows[0])) {
    return fail(res, 404, '地陪不存在');
  }
  return ok(res, { data: mergeGuideUserFields(result.rows[0]) });
  */
});

appRouter.post('/guides/:id/favorite', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(
    `insert into public.favorites (user_id, guide_id) values ($1, $2) on conflict do nothing`,
    [userId, req.params.id],
  );
  return ok(res, { message: '已收藏' });
});
appRouter.delete('/guides/:id/favorite', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(
    `delete from public.favorites where user_id = $1 and guide_id = $2`,
    [userId, req.params.id],
  );
  return ok(res, { message: '已取消收藏' });
});
appRouter.post('/guides/:id/like', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(
    `insert into public.guide_likes (user_id, guide_id) values ($1, $2) on conflict do nothing`,
    [userId, req.params.id],
  );
  return ok(res, { message: '已点赞' });
});
appRouter.delete('/guides/:id/like', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(
    `delete from public.guide_likes where user_id = $1 and guide_id = $2`,
    [userId, req.params.id],
  );
  return ok(res, { message: '已取消点赞' });
});
appRouter.post('/guides/:id/footprint', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(
    `
      insert into public.footprints (user_id, guide_id, last_visited_at)
      values ($1, $2, now())
      on conflict (user_id, guide_id) do update set last_visited_at = excluded.last_visited_at
    `,
    [userId, req.params.id],
  );
  return ok(res, { message: '已记录足迹' });
});

appRouter.get('/posts', async (req, res) => {
  const viewerId = getSessionUserId(req);
  const posts = await listPosts(pool, {
    query: req.query.q?.toString().trim() || '',
    viewerId,
  });
  return ok(res, { data: posts });
});

appRouter.get('/posts/following', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const postsResult = await pool.query(
    `
      select
        p.id,
        p.user_id,
        p.author_name,
        p.author_avatar,
        p.content,
        p.images,
        p.location,
        (
          select count(*)
          from public.post_likes pl
          where pl.post_id = p.id
        )::int as likes,
        (
          select count(*)
          from public.post_favorites pf2
          where pf2.post_id = p.id
        )::int as favorites,
        (
          select count(*)
          from public.post_comments pc
          where pc.post_id = p.id
        )::int as comments,
        exists(
          select 1
          from public.post_likes vpl
          where vpl.user_id = $1 and vpl.post_id = p.id
        ) as is_liked,
        exists(
          select 1
          from public.post_favorites vpf
          where vpf.user_id = $1 and vpf.post_id = p.id
        ) as is_favorited,
        p.created_at
      from public.posts p
      join public.follows f on f.followed_id = p.user_id
      where f.follower_id = $1
      order by p.created_at desc
    `,
    [userId],
  );
  return ok(res, { data: postsResult.rows });
  /*
  const parentCommentId = req.body?.parent_comment_id?.toString().trim() ?? '';
  const replyToCommentId = req.body?.reply_to_comment_id?.toString().trim() ?? '';
  const normalizedParentCommentId = parentCommentId.isEmpty ? null : parentCommentId;
  const normalizedReplyToCommentId = replyToCommentId.isEmpty
    ? normalizedParentCommentId
    : replyToCommentId;
  if (normalizedReplyToCommentId != null) {
    const referenceCommentResult = await pool.query(
      `
        select id, post_id
        from public.post_comments
        where id = $1
        limit 1
      `,
      [normalizedReplyToCommentId],
    );
    const referenceComment = referenceCommentResult.rows[0];
    if (!referenceComment || referenceComment.post_id !== req.params.id) {
      return fail(res, 400, '鍥炲鐨勮瘎璁轰笉瀛樺湪');
    }
  }
  const parentCommentId = req.body?.parent_comment_id?.toString().trim() ?? '';
  const replyToCommentId = req.body?.reply_to_comment_id?.toString().trim() ?? '';
  const normalizedParentCommentId = parentCommentId.isEmpty ? null : parentCommentId;
  const normalizedReplyToCommentId = replyToCommentId.isEmpty
    ? normalizedParentCommentId
    : replyToCommentId;
  if (normalizedReplyToCommentId != null) {
    const referenceCommentResult = await pool.query(
      `
        select id, post_id
        from public.post_comments
        where id = $1
        limit 1
      `,
      [normalizedReplyToCommentId],
    );
    const referenceComment = referenceCommentResult.rows[0];
    if (!referenceComment || referenceComment.post_id !== req.params.id) {
      return fail(res, 400, '鍥炲鐨勮瘎璁轰笉瀛樺湪');
    }
  }
  */
  const parentCommentId = req.body?.parent_comment_id?.toString().trim() ?? '';
  const replyToCommentId = req.body?.reply_to_comment_id?.toString().trim() ?? '';
  const normalizedParentCommentId = parentCommentId.isEmpty ? null : parentCommentId;
  const normalizedReplyToCommentId = replyToCommentId.isEmpty
    ? normalizedParentCommentId
    : replyToCommentId;
  if (normalizedReplyToCommentId != null) {
    const referenceCommentResult = await pool.query(
      `
        select id, post_id
        from public.post_comments
        where id = $1
        limit 1
      `,
      [normalizedReplyToCommentId],
    );
    const referenceComment = referenceCommentResult.rows[0];
    if (!referenceComment || referenceComment.post_id !== req.params.id) {
      return fail(res, 400, '鍥炲鐨勮瘎璁轰笉瀛樺湪');
    }
  }
  const result = await pool.query(
    `
      select
        p.id,
        p.user_id,
        p.author_name,
        p.author_avatar,
        p.content,
        p.images,
        p.location,
        (
          select count(*)
          from public.post_likes pl
          where pl.post_id = p.id
        )::int as likes,
        (
          select count(*)
          from public.post_favorites pf2
          where pf2.post_id = p.id
        )::int as favorites,
        (
          select count(*)
          from public.post_comments pc
          where pc.post_id = p.id
        )::int as comments,
        exists(
          select 1
          from public.post_likes vpl
          where vpl.user_id = $1 and vpl.post_id = p.id
        ) as is_liked,
        exists(
          select 1
          from public.post_favorites vpf
          where vpf.user_id = $1 and vpf.post_id = p.id
        ) as is_favorited,
        p.created_at
      from public.posts p
      join public.follows f on f.followed_id = p.user_id
      where f.follower_id = $1
      order by p.created_at desc
    `,
    [userId],
  );
  return ok(res, { data: result.rows });
});

appRouter.get('/users/:id/posts', async (req, res) => {
  const viewerId = getSessionUserId(req);
  const posts = await listPostsByUser(pool, req.params.id, viewerId);
  return ok(res, { data: posts });
});

appRouter.post('/posts', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const moderation = await assertPayloadAllowed(payload, [
    { key: 'title', label: '标题' },
    { key: 'content', label: '正文' },
    { key: 'tag', label: '位置/标签' },
  ]);
  const created = await createPost(pool, {
    user_id: userId,
    author_name: payload.author_name ?? '我',
    author_avatar: payload.author_avatar ?? '',
    content: `${payload.title ?? ''}\n${payload.content ?? ''}`.trim(),
    images: payload.images ?? [],
    location: payload.location ?? payload.tag ?? '',
    review_status: moderation.reviewStatus,
    reject_reason: moderation.reviewStatus === 'pending'
      ? `命中审核规则: ${moderation.hits.join(', ')}`
      : null,
    moderation_hits: moderation.hits,
    moderation_source: moderation.results?.map((item) => item.source).filter(Boolean).join(',') ?? '',
  });
  return ok(res, {
    data: created,
    message: moderation.reviewStatus === 'pending' ? '内容已提交，等待人工审核' : '发布成功',
  });
});

appRouter.post('/posts/:id/like', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const insertResult = await pool.query(
    `insert into public.post_likes (user_id, post_id) values ($1, $2) on conflict do nothing`,
    [userId, req.params.id],
  );
  if (insertResult.rowCount > 0) {
    await updatePostLikes(pool, req.params.id, 1);
  }
  return ok(res, { message: '已点赞' });
});
appRouter.delete('/posts/:id/like', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const deleteResult = await pool.query(
    `delete from public.post_likes where user_id = $1 and post_id = $2`,
    [userId, req.params.id],
  );
  if (deleteResult.rowCount > 0) {
    await updatePostLikes(pool, req.params.id, -1);
  }
  return ok(res, { message: '已取消点赞' });
});
appRouter.post('/posts/:id/favorite', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(
    `insert into public.post_favorites (user_id, post_id) values ($1, $2) on conflict do nothing`,
    [userId, req.params.id],
  );
  return ok(res, { message: '已收藏' });
});
appRouter.delete('/posts/:id/favorite', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(
    `delete from public.post_favorites where user_id = $1 and post_id = $2`,
    [userId, req.params.id],
  );
  return ok(res, { message: '已取消收藏' });
});
appRouter.get('/posts/favorites', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const result = await pool.query(
    `
      select
        p.id,
        p.user_id,
        p.author_name,
        p.author_avatar,
        p.content,
        p.images,
        p.location,
        (
          select count(*)
          from public.post_likes pl
          where pl.post_id = p.id
        )::int as likes,
        (
          select count(*)
          from public.post_favorites pf2
          where pf2.post_id = p.id
        )::int as favorites,
        (
          select count(*)
          from public.post_comments pc
          where pc.post_id = p.id
        )::int as comments,
        exists(
          select 1
          from public.post_likes vpl
          where vpl.user_id = $1 and vpl.post_id = p.id
        ) as is_liked,
        exists(
          select 1
          from public.post_favorites vpf
          where vpf.user_id = $1 and vpf.post_id = p.id
        ) as is_favorited,
        p.created_at
      from public.post_favorites pf
      join public.posts p on p.id = pf.post_id
      where pf.user_id = $1
      order by pf.created_at desc
    `,
    [userId],
  );
  return ok(res, { data: result.rows });
});
appRouter.get('/posts/liked', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const result = await pool.query(
    `
      select
        p.id,
        p.user_id,
        p.author_name,
        p.author_avatar,
        p.content,
        p.images,
        p.location,
        (
          select count(*)
          from public.post_likes pl2
          where pl2.post_id = p.id
        )::int as likes,
        (
          select count(*)
          from public.post_favorites pf3
          where pf3.post_id = p.id
        )::int as favorites,
        (
          select count(*)
          from public.post_comments pc
          where pc.post_id = p.id
        )::int as comments,
        true as is_liked,
        exists(
          select 1
          from public.post_favorites pf2
          where pf2.user_id = $1 and pf2.post_id = p.id
        ) as is_favorited,
        p.created_at
      from public.post_likes pl
      join public.posts p on p.id = pl.post_id
      where pl.user_id = $1
      order by pl.created_at desc
    `,
    [userId],
  );
  return ok(res, { data: result.rows });
});
appRouter.get('/posts/:id/comments', async (req, res) => {
  const viewerId = getSessionUserId(req);
  const normalizedViewerIdForComments = viewerId.trim();
  const result = await pool.query(
    `
      select
        pc.*,
        u.nickname as user_name,
        u.avatar as user_avatar,
        reply_to_comment.user_id as reply_to_user_id,
        reply_to_user.nickname as reply_to_user_name,
        reply_to_user.avatar as reply_to_user_avatar,
        (
          select count(*)
          from public.post_comment_likes pcl
          where pcl.comment_id = pc.id
        )::int as like_count,
        ${
          normalizedViewerIdForComments !== ''
            ? `
        exists(
          select 1
          from public.post_comment_likes viewer_pcl
          where viewer_pcl.comment_id = pc.id and viewer_pcl.user_id = $2
        ) as is_liked
        `
            : `
        false as is_liked
        `
        }
      from public.post_comments pc
      join public.users u on u.id = pc.user_id
      left join public.post_comments reply_to_comment on reply_to_comment.id = pc.reply_to_comment_id
      left join public.users reply_to_user on reply_to_user.id = reply_to_comment.user_id
      where pc.post_id = $1
      order by coalesce(pc.parent_comment_id, pc.id), pc.parent_comment_id nulls first, pc.created_at asc
    `,
    normalizedViewerIdForComments !== ''
      ? [req.params.id, normalizedViewerIdForComments]
      : [req.params.id],
  );
  return ok(res, { data: result.rows });
});
appRouter.post('/posts/:id/comments', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const post = await findPostById(pool, req.params.id, userId);
  if (!post) return fail(res, 404, 'post not found');

  const content = req.body?.content?.toString().trim() ?? '';
  if (!content) return fail(res, 400, 'comment cannot be empty');
  const moderation = await assertTextAllowed(content, { field: '评论' });

  const parentCommentIdRaw =
    req.body?.parent_comment_id?.toString().trim() ?? '';
  const replyToCommentIdRaw =
    req.body?.reply_to_comment_id?.toString().trim() ?? '';

  let normalizedParentCommentId =
    parentCommentIdRaw === '' ? null : parentCommentIdRaw;
  let normalizedReplyToCommentId =
    replyToCommentIdRaw === '' ? null : replyToCommentIdRaw;

  if (normalizedParentCommentId != null) {
    const parentLookupResult = await pool.query(
      `
        select id, post_id, parent_comment_id
        from public.post_comments
        where id = $1
        limit 1
      `,
      [normalizedParentCommentId],
    );
    const parentLookup = parentLookupResult.rows[0];
    if (!parentLookup || parentLookup.post_id !== req.params.id) {
      return fail(res, 400, 'parent comment not found');
    }
    normalizedParentCommentId = parentLookup.parent_comment_id || parentLookup.id;
  }

  if (normalizedReplyToCommentId != null) {
    const replyLookupResult = await pool.query(
      `
        select id, post_id, parent_comment_id
        from public.post_comments
        where id = $1
        limit 1
      `,
      [normalizedReplyToCommentId],
    );
    const replyLookup = replyLookupResult.rows[0];
    if (!replyLookup || replyLookup.post_id !== req.params.id) {
      return fail(res, 400, 'reply target not found');
    }
    const threadRootId = replyLookup.parent_comment_id || replyLookup.id;
    if (
      normalizedParentCommentId != null &&
      normalizedParentCommentId !== threadRootId
    ) {
      return fail(res, 400, 'reply target does not match thread');
    }
    normalizedParentCommentId = threadRootId;
    normalizedReplyToCommentId = replyLookup.id;
  }

  if (normalizedParentCommentId != null && normalizedReplyToCommentId == null) {
    normalizedReplyToCommentId = normalizedParentCommentId;
  }

  const result = await pool.query(
    `
      insert into public.post_comments (
        post_id,
        user_id,
        parent_comment_id,
        reply_to_comment_id,
        content,
        review_status,
        reject_reason
      )
      values ($1, $2, $3, $4, $5, $6, $7)
      returning *
    `,
    [
      req.params.id,
      userId,
      normalizedParentCommentId,
      normalizedReplyToCommentId,
      content,
      moderation.reviewStatus,
      moderation.reviewStatus === 'pending'
        ? `命中审核规则: ${moderation.hits.join(', ')}`
        : null,
    ],
  );
  return ok(res, {
    data: result.rows[0],
    message: moderation.reviewStatus === 'pending' ? '评论已提交，等待人工审核' : 'commented',
  });
});
appRouter.post('/posts/comments/:id/like', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(
    `
      insert into public.post_comment_likes (user_id, comment_id)
      values ($1, $2)
      on conflict do nothing
    `,
    [userId, req.params.id],
  );
  return ok(res, { message: 'liked' });
});
appRouter.delete('/posts/comments/:id/like', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(
    `
      delete from public.post_comment_likes
      where user_id = $1 and comment_id = $2
    `,
    [userId, req.params.id],
  );
  return ok(res, { message: 'unliked' });
});
appRouter.post('/posts/:id/footprint', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(
    `
      insert into public.post_footprints (user_id, post_id, last_visited_at)
      values ($1, $2, now())
      on conflict (user_id, post_id) do update set last_visited_at = excluded.last_visited_at
    `,
    [userId, req.params.id],
  );
  return ok(res, { message: '记录成功' });
});
appRouter.get('/posts/footprints', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const result = await pool.query(
    `
      select
        p.id,
        p.user_id,
        p.author_name,
        p.author_avatar,
        p.content,
        p.images,
        p.location,
        (
          select count(*)
          from public.post_likes pl
          where pl.post_id = p.id
        )::int as likes,
        (
          select count(*)
          from public.post_favorites pf2
          where pf2.post_id = p.id
        )::int as favorites,
        (
          select count(*)
          from public.post_comments pc
          where pc.post_id = p.id
        )::int as comments,
        exists(
          select 1
          from public.post_likes vpl
          where vpl.user_id = $1 and vpl.post_id = p.id
        ) as is_liked,
        exists(
          select 1
          from public.post_favorites vpf
          where vpf.user_id = $1 and vpf.post_id = p.id
        ) as is_favorited,
        p.created_at
      from public.post_footprints pf
      join public.posts p on p.id = pf.post_id
      where pf.user_id = $1
      order by pf.last_visited_at desc
    `,
    [userId],
  );
  return ok(res, { data: result.rows });
});

appRouter.get('/demands', async (req, res) => {
  const viewerId = getSessionUserId(req);
  const guideLocation = viewerId ? await fetchGuideLocation(pool, viewerId) : null;
  const result = await pool.query(
    `
      select
        d.*,
        coalesce(nullif(u.nickname, ''), d.author_name, '') as author_name,
        coalesce(nullif(u.avatar, ''), d.author_avatar, '') as author_avatar
      from public.demands d
      left join public.users u on u.id = d.author_id
      where not exists (
        select 1
        from public.guide_blocked_users b
        where b.guide_id = $1 and b.blocked_user_id = d.author_id
      )
      order by d.created_at desc
    `,
    [viewerId || null],
  );
  return ok(res, {
    data: result.rows.map((row) => withDistanceFields(row, guideLocation)),
  });
});

appRouter.get('/demands/me', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const result = await pool.query(
    `
      select
        d.*,
        coalesce(nullif(u.nickname, ''), d.author_name, '') as author_name,
        coalesce(nullif(u.avatar, ''), d.author_avatar, '') as author_avatar
      from public.demands d
      left join public.users u on u.id = d.author_id
      where d.author_id = $1
      order by d.created_at desc
    `,
    [userId],
  );
  return ok(res, {
    data: result.rows.map((row) => ({
      ...row,
      service_lat: toNullableNumber(row.service_lat),
      service_lng: toNullableNumber(row.service_lng),
    })),
  });
});

appRouter.get('/demands/applied', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const guideLocation = await fetchGuideLocation(pool, userId);
  const result = await pool.query(
    `
      select
        d.*,
        coalesce(nullif(customer.nickname, ''), d.author_name, '') as author_name,
        coalesce(nullif(customer.avatar, ''), d.author_avatar, '') as author_avatar,
        da.id as application_id,
        da.status as application_status,
        da.note as application_note,
        da.quote_amount as application_quote_amount,
        da.created_at as application_created_at
      from public.demand_applications da
      join public.demands d on d.id = da.demand_id
      left join public.users customer on customer.id = d.author_id
      where da.guide_id = $1
      order by da.created_at desc
    `,
    [userId],
  );
  return ok(res, {
    data: result.rows.map((row) => withDistanceFields(row, guideLocation)),
  });
});

appRouter.get('/demands/:id', async (req, res) => {
  const viewerId = getSessionUserId(req);
  const guideLocation = viewerId ? await fetchGuideLocation(pool, viewerId) : null;
  const demandResult = await pool.query(
    `
      select
        d.*,
        coalesce(nullif(u.nickname, ''), d.author_name, '') as author_name,
        coalesce(nullif(u.avatar, ''), d.author_avatar, '') as author_avatar
      from public.demands d
      left join public.users u on u.id = d.author_id
      where d.id = $1
      limit 1
    `,
    [req.params.id],
  );
  const demand = demandResult.rows[0];
  if (!demand) return fail(res, 404, '需求不存在');

  const applications = await pool.query(
    `
      select
        da.*,
        coalesce(nullif(u.nickname, ''), da.guide_name, '') as guide_name,
        coalesce(nullif(u.avatar, ''), da.guide_avatar, '') as guide_avatar
      from public.demand_applications da
      left join public.users u on u.id = da.guide_id
      where da.demand_id = $1
      order by da.created_at desc
    `,
    [req.params.id],
  );

  return ok(res, {
    data: {
      ...withDistanceFields(demand, guideLocation),
      applications: applications.rows,
    },
  });
});

appRouter.post('/demands', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const moderation = await assertPayloadAllowed(payload, [
    { key: 'title', label: '需求标题' },
    { key: 'content', label: '需求内容' },
    { key: 'city', label: '服务城市' },
    { key: 'location', label: '服务地点' },
  ]);
  const result = await pool.query(
    `
      insert into public.demands (
        title, content, city, location, service_lat, service_lng, service_start_at, service_end_at,
        people_count, gender, budget, budget_min, budget_max, status, author_id, author_name,
        author_avatar, images, tags, review_status, reject_reason
      ) values (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18::text[],$19::text[],$20,$21
      ) returning *
    `,
    [
      payload.title,
      payload.content,
      payload.city,
      payload.location,
      toNullableNumber(payload.service_lat),
      toNullableNumber(payload.service_lng),
      payload.service_start_at,
      payload.service_end_at,
      payload.people_count,
      payload.gender,
      payload.budget,
      toNullableNumber(payload.budget_min ?? payload.budgetMin),
      toNullableNumber(payload.budget_max ?? payload.budgetMax),
      payload.status ?? 'open',
      userId,
      payload.author_name ?? '我',
      payload.author_avatar ?? '',
      payload.images ?? [],
      payload.tags ?? [],
      moderation.reviewStatus,
      moderation.reviewStatus === 'pending'
        ? `命中审核规则: ${moderation.hits.join(', ')}`
        : null,
    ],
  );
  return ok(res, {
    data: {
      ...result.rows[0],
      service_lat: toNullableNumber(result.rows[0].service_lat),
      service_lng: toNullableNumber(result.rows[0].service_lng),
    },
    message: moderation.reviewStatus === 'pending' ? 'pending manual review' : 'published',
  });
});

appRouter.post('/demands/:id/apply', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;

  const demandResult = await pool.query(
    `select * from public.demands where id = $1 limit 1`,
    [req.params.id],
  );
  const demand = demandResult.rows[0];
  if (!demand) return fail(res, 404, '需求不存在');
  const blocked = await pool.query(
    `select 1 from public.guide_blocked_users where guide_id = $1 and blocked_user_id = $2 limit 1`,
    [userId, demand.author_id],
  );
  if (blocked.rows[0]) return fail(res, 403, '该用户已在你的屏蔽名单中');
  if (demand.author_id === userId) return fail(res, 400, '不能报名自己的需求');

  const guideResult = await pool.query(
    `select * from public.guides where id = $1 limit 1`,
    [userId],
  );
  const guide = guideResult.rows[0];
  if (!guide) return fail(res, 403, '当前账号还不是已入驻地陪');

  const payload = req.body ?? {};
  const demandStart = parseServiceDate(payload.service_start_at);
  const demandEnd = parseServiceDate(payload.service_end_at);
  if (!demandStart || !demandEnd || demandEnd <= demandStart) {
    return fail(res, 400, '需求时间不正确');
  }
  try {
    assertDateWindow(demandStart, 13, 'demand_start_must_be_within_14_days');
    assertDateWindow(demandEnd, 13, 'demand_end_must_be_within_14_days');
  } catch (error) {
    return fail(res, error.statusCode || 400, error.message);
  }
  await assertPayloadAllowed(payload, [
    { key: 'note', label: '报名备注' },
    { key: 'quote_amount', label: '报名报价' },
  ]);
  const result = await pool.query(
    `
      insert into public.demand_applications (
        demand_id, guide_id, guide_name, guide_avatar, guide_city, note, quote_amount, status
      ) values ($1,$2,$3,$4,$5,$6,$7,'pending')
      on conflict (demand_id, guide_id) do update
      set
        note = excluded.note,
        guide_name = excluded.guide_name,
        guide_avatar = excluded.guide_avatar,
        guide_city = excluded.guide_city,
        quote_amount = excluded.quote_amount
      returning *
    `,
    [
      req.params.id,
      userId,
      guide.name ?? '',
      guide.avatar ?? '',
      guide.city ?? '',
      payload.note?.toString() ?? '',
      toNullableNumber(payload.quote_amount ?? payload.quoteAmount),
    ],
  );

  await pool.query(
    `
      update public.demands
      set applicant_count = (
        select count(*)
        from public.demand_applications
        where demand_id = $1
      )
      where id = $1
    `,
    [req.params.id],
  );

  return ok(res, { data: result.rows[0], message: '报名成功' });
});

appRouter.get('/demands/:id/applications', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const demandResult = await pool.query(
    `select * from public.demands where id = $1 limit 1`,
    [req.params.id],
  );
  const demand = demandResult.rows[0];
  if (!demand) return fail(res, 404, '需求不存在');
  if (demand.author_id !== userId) return fail(res, 403, '无权限查看该需求报名列表');

  const applications = await pool.query(
    `
      select *
      from public.demand_applications
      where demand_id = $1
      order by created_at desc
    `,
    [req.params.id],
  );

  return ok(res, { data: applications.rows });
});

appRouter.post('/demands/:id/select-guide', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const applicationId = payload.application_id?.toString().trim() ?? '';
  if (!applicationId) return fail(res, 400, '缺少 application_id');

  const demandResult = await pool.query(
    `select * from public.demands where id = $1 limit 1`,
    [req.params.id],
  );
  const demand = demandResult.rows[0];
  if (!demand) return fail(res, 404, '需求不存在');
  if (demand.author_id !== userId) return fail(res, 403, '无权限操作该需求');

  const applicationResult = await pool.query(
    `select * from public.demand_applications where id = $1 and demand_id = $2 limit 1`,
    [applicationId, req.params.id],
  );
  const application = applicationResult.rows[0];
  if (!application) return fail(res, 404, '报名记录不存在');

  const selectedGuideLocation = await fetchGuideLocation(pool, application.guide_id);

  const created = await withTransaction(async (client) => {
    await client.query(
      `update public.demand_applications set status = 'selected' where id = $1`,
      [applicationId],
    );
    await client.query(
      `update public.demand_applications set status = 'rejected' where demand_id = $1 and id <> $2 and status = 'pending'`,
      [req.params.id, applicationId],
    );
    await client.query(
      `update public.demands set status = 'matched' where id = $1`,
      [req.params.id],
    );
    const orderResult = await client.query(
      `
        insert into public.orders (
          user_id, guide_id, guide_name, guide_avatar, status, amount,
          service_name, service_address, service_city, service_lat, service_lng,
          service_date, payment_method, payment_status, created_at
        ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'alipay','pending', now())
        returning *
      `,
      [
        demand.author_id,
        application.guide_id,
        application.guide_name ?? '',
        application.guide_avatar ?? '',
        0,
        Number.parseFloat(payload.amount?.toString() ?? '') ||
          Number.parseFloat(application.quote_amount?.toString() ?? '') || 0,
        demand.title ?? demand.content ?? '地陪服务订单',
        demand.location ?? '',
        demand.city ?? '',
        toNullableNumber(demand.service_lat),
        toNullableNumber(demand.service_lng),
        demand.service_start_at,
      ],
    );
    return withDistanceFields(orderResult.rows[0], selectedGuideLocation);
  });

  return ok(res, { data: created, message: '已选定地陪并生成订单' });
});

appRouter.get('/chat/rooms', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const result = await pool.query(
    `
      select *
      from public.chat_rooms
      where $1 = any(participant_ids)
      order by last_message_time desc
    `,
    [userId],
  );
  return ok(res, { data: result.rows });
});

appRouter.get('/chat/rooms/:id', async (req, res) => {
  const result = await pool.query(`select * from public.chat_rooms where id = $1 limit 1`, [req.params.id]);
  if (!result.rows[0]) return fail(res, 404, '会话不存在');
  const messages = await pool.query(
    `select * from public.messages where room_id = $1 order by created_at asc`,
    [req.params.id],
  );
  return ok(res, { data: { ...result.rows[0], messages: messages.rows } });
});

appRouter.post('/chat/rooms', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const otherUserId = req.body?.other_user_id?.toString().trim();
  if (!otherUserId) return fail(res, 400, '缺少对方用户');
  if (otherUserId === userId) return fail(res, 400, '不能和自己创建会话');
  const existing = await pool.query(
    `
      select id
      from public.chat_rooms
      where participant_ids @> array[$1::uuid, $2::uuid]
      limit 1
    `,
    [userId, otherUserId],
  );
  if (existing.rows[0]) {
    return ok(res, { data: { id: existing.rows[0].id } });
  }
  const created = await ensureChatRoom(pool, '', [userId, otherUserId]);
  return ok(res, { data: created });
});

appRouter.post('/chat/rooms/:id/messages', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const roomId = req.params.id;
  const content = req.body?.content?.toString() ?? '';
  const type = req.body?.type?.toString() ?? 'text';
  if (type === 'text') {
    await assertTextAllowed(content, { field: '聊天内容' });
  }
  const result = await pool.query(
    `
      insert into public.messages (room_id, sender_id, content, type)
      values ($1, $2, $3, $4)
      returning *
    `,
    [roomId, userId, content, type],
  );
  return ok(res, { data: result.rows[0] });
});

appRouter.post('/chat/rooms/:id/read', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(
    `
      update public.messages
      set is_read = true
      where room_id = $1 and sender_id <> $2
    `,
    [req.params.id, userId],
  );
  return ok(res, { message: '已读' });
});

appRouter.get('/orders', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const result = await pool.query(
    `
      select
        o.*,
        coalesce(nullif(guide_user.nickname, ''), nullif(o.guide_name, ''), '') as guide_name,
        coalesce(nullif(guide_user.avatar, ''), nullif(o.guide_avatar, ''), '') as guide_avatar,
        o.user_id as customer_id,
        coalesce(nullif(customer.nickname, ''), '') as customer_name,
        coalesce(nullif(customer.avatar, ''), '') as customer_avatar
      from public.orders o
      left join public.users customer on customer.id = o.user_id
      left join public.users guide_user on guide_user.id = o.guide_id
      where o.user_id = $1
         or (
           o.guide_id = $1
           and exists (
             select 1
             from public.guides
             where id = $1
           )
         )
      order by o.created_at desc
    `,
    [userId],
  );
  const enriched = [];
  for (const row of result.rows) {
    const guideLocation = await fetchGuideLocation(pool, row.guide_id);
    enriched.push(withDistanceFields(row, guideLocation));
  }
  return ok(res, { data: enriched });
}));

appRouter.post('/orders', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const guideId = payload.guideId ?? payload.guide_id;
  if (!guideId?.toString().trim()) {
    return fail(res, 400, 'missing guide_id');
  }
  const serviceItemId = payload.serviceItemId ?? payload.service_item_id;
  if (!serviceItemId?.toString().trim()) {
    return fail(res, 400, 'missing service_item_id');
  }
  const serviceDate = payload.serviceDate ?? payload.service_date;
  const serviceLat = payload.serviceLat ?? payload.service_lat;
  const serviceLng = payload.serviceLng ?? payload.service_lng;
  const pricing = await calculateOrderPricing(pool, {
    guideId: guideId.toString().trim(),
    serviceItemId: serviceItemId.toString().trim(),
    serviceHours: payload.serviceHours ?? payload.service_hours,
    serviceDate,
    serviceLat,
    serviceLng,
  });
  const result = await pool.query(
    `
      insert into public.orders (
        user_id, guide_id, guide_name, guide_avatar, status, amount,
        service_name, service_address, service_city, service_lat, service_lng,
        service_date, payment_method, payment_status, merchant_order_no,
        service_item_id, service_hours, service_fee, travel_fee, platform_fee,
        guide_income, guide_service_lat, guide_service_lng, route_distance_meters, created_at
      )
      values ($1,$2,$3,$4,0,$5,$6,$7,$8,$9,$10,$11,$12,'pending',$13,
              $14,$15,$16,$17,$18,$19,$20,$21,$22,now())
      returning *
    `,
    [
      userId,
      guideId,
      pricing.item.guide_nickname ?? payload.guideName ?? payload.guide_name ?? '',
      pricing.item.guide_avatar ?? payload.guideAvatar ?? payload.guide_avatar ?? '',
      pricing.totalAmount,
      pricing.item.service_type || pricing.item.name,
      payload.serviceAddress ?? payload.service_address ?? '',
      payload.serviceCity ?? payload.service_city ?? '',
      toNullableNumber(serviceLat),
      toNullableNumber(serviceLng),
      serviceDate,
      payload.paymentMethod ?? payload.payment_method ?? 'alipay',
      payload.merchantOrderNo ?? payload.merchant_order_no ?? null,
      pricing.item.id,
      pricing.serviceHours,
      pricing.serviceFee,
      pricing.travelFee,
      pricing.platformFee,
      pricing.guideIncome,
      pricing.guideServiceLat,
      pricing.guideServiceLng,
      pricing.routeDistanceMeters,
    ],
  );
  const guideLocation = await fetchGuideLocation(pool, guideId);
  return ok(res, {
    data: {
      ...withDistanceFields(result.rows[0], guideLocation),
      pricing: {
        service_fee: pricing.serviceFee,
        travel_fee: pricing.travelFee,
        platform_fee: pricing.platformFee,
        guide_income: pricing.guideIncome,
        total_amount: pricing.totalAmount,
        route_distance_meters: pricing.routeDistanceMeters,
      },
    },
  });
}));

appRouter.post('/orders/one-cent-test', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  let guideId;
  let guide;

  const guideResult = await pool.query(
    `
      select g.*
      from public.guides g
      join public.users u on u.id = g.id
      where u.phone = '13900010003'
        and g.verified = true
        and g.id <> $1
      limit 1
    `,
    [userId],
  );
  guide = guideResult.rows[0];
  guideId = guide?.id;

  if (!guide || !guideId) {
    return fail(res, 404, '没有可用于测试的地陪账号');
  }
  if (guideId === userId) {
    return fail(res, 400, '测试订单不能下给自己');
  }

  const merchantOrderNo = `TEST001${Date.now()}${userId.replaceAll('-', '').slice(0, 8)}`;
  const result = await pool.query(
    `
      insert into public.orders (
        user_id, guide_id, guide_name, guide_avatar, status, amount,
        service_name, service_address, service_city, service_lat, service_lng,
        service_date, payment_method, payment_status, merchant_order_no, created_at
      )
      values ($1,$2,$3,$4,0,0.10,$5,$6,$7,$8,$9,$10,'alipay','pending',$11,now())
      returning *
    `,
    [
      userId,
      guideId,
      guide.name ?? payload.guideName ?? payload.guide_name ?? '测试地陪',
      guide.avatar ?? payload.guideAvatar ?? payload.guide_avatar ?? '',
      payload.serviceName ?? payload.service_name ?? '0.10元地陪接单支付测试',
      payload.serviceAddress ?? payload.service_address ?? '0.10测试服务地点',
      payload.serviceCity ?? payload.service_city ?? guide.city ?? '',
      toNullableNumber(payload.serviceLat ?? payload.service_lat),
      toNullableNumber(payload.serviceLng ?? payload.service_lng),
      payload.serviceDate ?? payload.service_date ?? null,
      merchantOrderNo,
    ],
  );
  const guideLocation = await fetchGuideLocation(pool, guideId);
  return ok(res, {
    data: withDistanceFields(result.rows[0], guideLocation),
    message: '0.10测试订单已创建，等待地陪接单后付款',
  });
}));

appRouter.put('/orders/:id', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const order = await findOrderById(pool, req.params.id);
  if (!order) return fail(res, 404, '订单不存在');
  if (order.user_id !== userId && order.guide_id !== userId) {
    return fail(res, 403, '无权限操作订单');
  }
  const result = await pool.query(
    `
      update public.orders
      set
        payment_status = coalesce($2, payment_status),
        merchant_order_no = coalesce($3, merchant_order_no),
        payment_request_id = coalesce($4, payment_request_id)
      where id = $1
      returning *
    `,
    [req.params.id, payload.payment_status, payload.merchant_order_no, payload.payment_request_id],
  );
  return ok(res, { data: result.rows[0] });
}));

appRouter.post('/orders/:id/accept', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const order = await findOrderById(pool, req.params.id);
  if (!order) return fail(res, 404, '订单不存在');
  if (order.guide_id !== userId) {
    return fail(res, 403, '只有该订单的地陪可以接单');
  }
  if (Number(order.status) !== 0) {
    return fail(res, 400, '当前订单状态不能接单');
  }
  if (order.payment_status === 'paid') {
    return fail(res, 400, '订单已支付，不能重复接单');
  }
  const result = await pool.query(
    `
      update public.orders
      set payment_status = 'accepted'
      where id = $1
      returning *
    `,
    [req.params.id],
  );
  return ok(res, { data: result.rows[0], message: '地陪已接单，等待用户付款' });
}));

appRouter.post('/orders/:id/complete', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const order = await findOrderById(pool, req.params.id);
  if (!order) return fail(res, 404, '订单不存在');
  if (order.user_id !== userId && order.guide_id !== userId) {
    return fail(res, 403, '无权限操作订单');
  }
  if (Number(order.status) === 3) {
    return ok(res, { message: '订单已完成' });
  }
  if (Number(order.status) === 2) {
    return ok(res, { message: '服务已完成，等待客户评价' });
  }
  await withTransaction(async (client) => {
    await client.query(`update public.orders set status = 2 where id = $1`, [req.params.id]);
    if (order.payment_status === 'paid') {
      const guideIncome = Number(order.guide_income ?? order.amount);
      await releasePendingBalance(client, order.guide_id, guideIncome);
      await recordWalletTransaction(client, {
        userId: order.guide_id,
        orderId: order.id,
        type: 'income_available',
        amount: guideIncome,
        actualAmount: guideIncome,
        description: `订单完成，收入转为可提现：${order.service_name ?? '地陪服务订单'}`,
      });
    }
  });
  return ok(res, { message: '服务已完成，等待客户评价' });
}));

appRouter.post('/orders/:id/review', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const order = await findOrderById(pool, req.params.id);
  if (!order) return fail(res, 404, '订单不存在');
  if (order.user_id !== userId) return fail(res, 403, '只有下单用户可以评价');
  if (Number(order.status) === 4) return fail(res, 400, '已取消订单不能评价');
  const rating = Number(req.body?.rating);
  const content = req.body?.content?.toString().trim() ?? '';
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) return fail(res, 400, '评分必须是1到5分');
  if (!content) return fail(res, 400, '请填写评价内容');
  const moderation = await reviewText(content, { field: '客户评价' });
  if (!moderation.passed) {
    return fail(res, 400, moderation.reason || '评价内容包含违规信息，请修改后再提交');
  }
  const result = await pool.query(
    `insert into public.guide_reviews (order_id,guide_id,customer_id,rating,content,images,is_anonymous)
     values ($1,$2,$3,$4,$5,$6::text[],$7)
     on conflict (order_id) do update set rating=excluded.rating,content=excluded.content,images=excluded.images,is_anonymous=excluded.is_anonymous
     returning *`,
    [order.id, order.guide_id, userId, rating, content, req.body?.images ?? [], req.body?.is_anonymous !== false],
  );
  await pool.query(
    `update public.guides set rating = coalesce((select round(avg(rating)::numeric, 2) from public.guide_reviews where guide_id = $1), 0) where id = $1`,
    [order.guide_id],
  );
  await pool.query(`update public.orders set status = 3 where id = $1`, [order.id]);
  return ok(res, { data: result.rows[0], message: '评价已提交' });
}));

appRouter.post('/orders/:id/cancel', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const order = await findOrderById(pool, req.params.id);
  if (!order) return fail(res, 404, '订单不存在');
  if (order.user_id !== userId && order.guide_id !== userId) {
    return fail(res, 403, '无权限操作订单');
  }
  await pool.query(`update public.orders set status = 4 where id = $1`, [req.params.id]);
  return ok(res, { message: '已取消' });
}));

appRouter.post('/orders/:id/virtual-number', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;

  const orderResult = await pool.query(
    `
      select
        o.id,
        o.user_id,
        o.guide_id,
        customer.phone as customer_phone,
        guide_user.phone as guide_phone
      from public.orders o
      join public.users customer on customer.id = o.user_id
      join public.users guide_user on guide_user.id = o.guide_id
      where o.id = $1
      limit 1
    `,
    [req.params.id],
  );
  const order = orderResult.rows[0];
  if (!order) return fail(res, 404, '订单不存在');
  if (order.user_id !== userId && order.guide_id !== userId) {
    return fail(res, 403, '无权联系该订单用户');
  }
  if (!order.customer_phone || !order.guide_phone) {
    return fail(res, 400, '订单双方手机号不完整，无法绑定虚拟号');
  }

  const existing = await pool.query(
    `
      select *
      from public.virtual_number_bindings
      where order_id = $1 and expires_at > now()
      order by created_at desc
      limit 1
    `,
    [order.id],
  );
  if (existing.rows[0]) {
    return ok(res, {
      data: {
        phone_no_x: existing.rows[0].phone_no_x,
        expires_at: existing.rows[0].expires_at,
      },
      message: '已获取虚拟号',
    });
  }

  const outId = `order_${order.id}_${Date.now()}`;
  const bindResult = await bindAxbVirtualNumber({
    phoneNoA: order.customer_phone,
    phoneNoB: order.guide_phone,
    outId,
    expirationSeconds: 3600,
  });
  const saved = await pool.query(
    `
      insert into public.virtual_number_bindings (
        order_id, user_id, guide_id, phone_no_x, bind_id, out_id, expires_at, provider_payload
      ) values ($1,$2,$3,$4,$5,$6,now() + interval '1 hour',$7::jsonb)
      returning *
    `,
    [
      order.id,
      order.user_id,
      order.guide_id,
      bindResult.phoneNoX,
      bindResult.bindId,
      outId,
      JSON.stringify(bindResult.raw ?? {}),
    ],
  );

  return ok(res, {
    data: {
      phone_no_x: saved.rows[0].phone_no_x,
      expires_at: saved.rows[0].expires_at,
    },
    message: '已获取虚拟号',
  });
}));

async function findOrderContactContext(orderId) {
  const result = await pool.query(
    `
      select
        o.id,
        o.user_id,
        o.guide_id,
        o.status,
        o.payment_status,
        customer.phone as customer_phone,
        guide_user.phone as guide_phone
      from public.orders o
      join public.users customer on customer.id = o.user_id
      join public.users guide_user on guide_user.id = o.guide_id
      where o.id = $1
      limit 1
    `,
    [orderId],
  );
  return result.rows[0] ?? null;
}

function buildCallPayload(call, credential) {
  const currentUserId = credential?.current_user_id?.toString() || '';
  const isCaller = currentUserId && call.caller_user_id === currentUserId;
  const peerName = isCaller ? call.callee_name : call.caller_name;
  const peerAvatar = isCaller ? call.callee_avatar : call.caller_avatar;
  return {
    call_id: call.id,
    order_id: call.order_id,
    caller_user_id: call.caller_user_id,
    callee_user_id: call.callee_user_id,
    room_id: call.room_id,
    provider: call.provider,
    status: call.status,
    started_at: call.started_at,
    answered_at: call.answered_at,
    ended_at: call.ended_at,
    duration_seconds: call.duration_seconds,
    end_reason: call.end_reason,
    peer_name: peerName || '订单对方',
    peer_avatar: peerAvatar || '',
    is_caller: Boolean(isCaller),
    ...(credential?.user_sig
      ? {
          trtc: {
            sdk_app_id: credential.sdk_app_id,
            user_id: credential.user_id,
            user_sig: credential.user_sig,
            expires_in: credential.expires_in,
          },
        }
      : {}),
  };
}

async function expireTimedOutCalls(db = pool) {
  await db.query(
    `
      update public.call_sessions
      set
        status = 'ended',
        ended_at = now(),
        duration_seconds = 0,
        end_reason = 'timeout',
        updated_at = now()
      where status = 'ringing'
        and created_at <= now() - ($1 * interval '1 second')
    `,
    [config.trtcRingTimeoutSeconds],
  );
  await db.query(
    `
      update public.call_sessions
      set
        status = 'ended',
        ended_at = now(),
        duration_seconds = case
          when answered_at is null then 0
          else greatest(0, floor(extract(epoch from (now() - answered_at)))::integer)
        end,
        end_reason = 'connection_lost',
        updated_at = now()
      where status = 'answered'
        and coalesce(updated_at, created_at) <= now() - ($1 * interval '1 second')
    `,
    [config.trtcHeartbeatTimeoutSeconds],
  );
}

async function findCallForUser(db, callId, userId) {
  const result = await db.query(
    `
      select
        calls.*,
        coalesce(nullif(caller.nickname, ''), caller.phone, '用户') as caller_name,
        coalesce(caller.avatar, '') as caller_avatar,
        coalesce(nullif(callee.nickname, ''), callee.phone, '用户') as callee_name,
        coalesce(callee.avatar, '') as callee_avatar
      from public.call_sessions calls
      join public.users caller on caller.id = calls.caller_user_id
      join public.users callee on callee.id = calls.callee_user_id
      where calls.id = $1
        and (calls.caller_user_id = $2 or calls.callee_user_id = $2)
      limit 1
    `,
    [callId, userId],
  );
  return result.rows[0] ?? null;
}

function credentialForUser(userId) {
  return {
    ...buildTrtcCredential(userId),
    current_user_id: userId,
  };
}

appRouter.post('/orders/:id/calls', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;

  const order = await findOrderContactContext(req.params.id);
  if (!order) return fail(res, 404, '订单不存在');
  if (order.user_id !== userId && order.guide_id !== userId) {
    return fail(res, 403, '无权联系该订单用户');
  }

  const calleeUserId = order.user_id === userId ? order.guide_id : order.user_id;
  const call = await withTransaction(async (client) => {
    const lockKey = [userId, calleeUserId].sort().join(':');
    await client.query('select pg_advisory_xact_lock(hashtext($1))', [lockKey]);
    await expireTimedOutCalls(client);

    const ownExisting = await client.query(
      `
        select id
        from public.call_sessions
        where order_id = $1
          and caller_user_id = $2
          and callee_user_id = $3
          and status in ('ringing', 'answered')
        order by created_at desc
        limit 1
      `,
      [order.id, userId, calleeUserId],
    );
    if (ownExisting.rows[0]) {
      return findCallForUser(client, ownExisting.rows[0].id, userId);
    }

    const active = await client.query(
      `
        select id, caller_user_id, callee_user_id
        from public.call_sessions
        where status in ('ringing', 'answered')
          and (
            caller_user_id in ($1, $2)
            or callee_user_id in ($1, $2)
          )
        order by created_at desc
        limit 1
      `,
      [userId, calleeUserId],
    );
    if (active.rows[0]) {
      const error = new Error(
        active.rows[0].callee_user_id === userId
          ? '对方正在呼叫你，请先接听或拒绝'
          : '你或对方正在通话中，请稍后再试',
      );
      error.statusCode = 409;
      throw error;
    }

    const roomId = buildTrtcRoomId(
      `${order.id}:${userId}:${calleeUserId}:${Date.now()}:${crypto.randomUUID()}`,
    );
    const created = await client.query(
      `
        insert into public.call_sessions (
          order_id, caller_user_id, callee_user_id, room_id, provider, status, started_at, updated_at
        ) values ($1,$2,$3,$4,'trtc','ringing',now(),now())
        returning id
      `,
      [order.id, userId, calleeUserId, roomId],
    );
    return findCallForUser(client, created.rows[0].id, userId);
  });
  const credential = credentialForUser(userId);
  return ok(res, {
    data: buildCallPayload(call, credential),
    message: '语音通话已创建',
  });
}));

appRouter.get('/calls/incoming', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await expireTimedOutCalls();
  const result = await pool.query(
    `
      select
        calls.*,
        coalesce(nullif(caller.nickname, ''), caller.phone, '用户') as caller_name,
        coalesce(caller.avatar, '') as caller_avatar,
        coalesce(nullif(callee.nickname, ''), callee.phone, '用户') as callee_name,
        coalesce(callee.avatar, '') as callee_avatar
      from public.call_sessions calls
      join public.users caller on caller.id = calls.caller_user_id
      join public.users callee on callee.id = calls.callee_user_id
      where calls.callee_user_id = $1
        and calls.status = 'ringing'
      order by calls.created_at desc
      limit 10
    `,
    [userId],
  );
  return ok(res, {
    data: result.rows.map((call) => buildCallPayload(call, {
      current_user_id: userId,
    })),
  });
}));

appRouter.get('/calls/:id', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await expireTimedOutCalls();
  const call = await findCallForUser(pool, req.params.id, userId);
  if (!call) return fail(res, 404, '通话不存在');
  return ok(res, { data: buildCallPayload(call, { current_user_id: userId }) });
}));

appRouter.post('/calls/:id/join', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const result = await pool.query(
    `
      update public.call_sessions
      set
        status = 'answered',
        answered_at = coalesce(answered_at, now()),
        updated_at = now()
      where id = $1
        and callee_user_id = $2
        and status = 'ringing'
      returning id
    `,
    [req.params.id, userId],
  );
  if (!result.rows[0]) return fail(res, 409, '来电已结束或已被处理');
  const call = await findCallForUser(pool, result.rows[0].id, userId);
  const credential = credentialForUser(userId);
  return ok(res, {
    data: buildCallPayload(call, credential),
    message: '已加入语音通话',
  });
}));

appRouter.post('/calls/:id/end', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const reason = req.body?.reason?.toString().trim() || 'ended';
  const result = await pool.query(
    `
      update public.call_sessions
      set
        status = 'ended',
        ended_at = now(),
        duration_seconds = case
          when answered_at is null then 0
          else greatest(0, floor(extract(epoch from (now() - answered_at)))::integer)
        end,
        end_reason = $3,
        updated_at = now()
      where id = $1
        and (caller_user_id = $2 or callee_user_id = $2)
        and status in ('created', 'ringing', 'answered')
      returning *
    `,
    [req.params.id, userId, reason],
  );
  let call = result.rows[0];
  if (!call) {
    call = await findCallForUser(pool, req.params.id, userId);
  }
  if (!call) return fail(res, 404, '通话不存在');
  return ok(res, { data: call, message: '语音通话已结束' });
}));

appRouter.post('/calls/:id/heartbeat', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await expireTimedOutCalls();
  const result = await pool.query(
    `
      update public.call_sessions
      set updated_at = now()
      where id = $1
        and (caller_user_id = $2 or callee_user_id = $2)
        and status = 'answered'
      returning id, status, updated_at
    `,
    [req.params.id, userId],
  );
  if (!result.rows[0]) {
    const call = await findCallForUser(pool, req.params.id, userId);
    if (!call) return fail(res, 404, '通话不存在');
    return ok(res, {
      data: {
        call_id: call.id,
        status: call.status,
        end_reason: call.end_reason,
      },
      message: '通话已结束',
    });
  }
  return ok(res, { data: result.rows[0], message: '通话心跳已更新' });
}));

appRouter.get('/wallet', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const wallet = await pool.query(`select * from public.wallets where user_id = $1 limit 1`, [userId]);
  const tx = await pool.query(`select * from public.transactions where user_id = $1 order by created_at desc`, [userId]);
  const payoutAccount = await pool.query(
    `select * from public.guide_payout_accounts where user_id = $1 limit 1`,
    [userId],
  );
  const withdrawals = await pool.query(
    `select * from public.withdrawal_requests where user_id = $1 order by created_at desc limit 50`,
    [userId],
  );
  return ok(res, {
    data: {
      wallet: wallet.rows[0] ?? null,
      payout_account: payoutAccount.rows[0] ?? null,
      withdrawals: withdrawals.rows,
      transactions: tx.rows,
    },
  });
});

appRouter.put('/wallet/payout-account', handleRoute(async (req, res) => {
  const userId = await requireGuideUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const alipayAccount = payload.alipay_account?.toString().trim() ?? '';
  const alipayUserId = payload.alipay_user_id?.toString().trim() ?? '';
  const realName = payload.real_name?.toString().trim() ?? '';
  if (!realName) return fail(res, 400, '真实姓名不能为空');
  if (!alipayAccount && !alipayUserId) {
    return fail(res, 400, '支付宝账号或支付宝 user_id 至少填写一个');
  }
  if (realName.length < 2 || realName.length > 40) {
    return fail(res, 400, '请填写有效的支付宝实名');
  }
  if (alipayAccount && !/^(1\d{10}|[^@\s]+@[^@\s]+\.[^@\s]+)$/.test(alipayAccount)) {
    return fail(res, 400, '支付宝账号应填写手机号或邮箱');
  }
  if (alipayUserId && !/^\d{8,32}$/.test(alipayUserId)) {
    return fail(res, 400, '支付宝 user_id 应为数字');
  }
  const result = await pool.query(
    `
      insert into public.guide_payout_accounts (
        user_id, alipay_account, alipay_user_id, real_name, status, reject_reason, updated_at
      ) values ($1,$2,$3,$4,'pending',null,now())
      on conflict (user_id) do update set
        alipay_account = excluded.alipay_account,
        alipay_user_id = excluded.alipay_user_id,
        real_name = excluded.real_name,
        status = 'pending',
        reject_reason = null,
        updated_at = now()
      returning *
    `,
    [userId, alipayAccount || null, alipayUserId || null, realName],
  );
  return ok(res, { data: result.rows[0], message: '收款账号已提交，等待平台审核' });
}));

appRouter.post('/wallet/withdraw', handleRoute(async (req, res) => {
  const userId = await requireGuideUser(req, res);
  if (!userId) return;
  const amount = Number(req.body?.amount ?? 0);
  if (!(amount > 0)) return fail(res, 400, '提现金额必须大于0');
  if (
    config.alipayTransferMinAmount > 0 &&
    amount < config.alipayTransferMinAmount
  ) {
    return fail(
      res,
      400,
      `支付宝单笔最低提现金额为 ${config.alipayTransferMinAmount.toFixed(2)} 元`,
    );
  }
  const accountResult = await pool.query(
    `select * from public.guide_payout_accounts where user_id = $1 limit 1`,
    [userId],
  );
  const account = accountResult.rows[0];
  if (!account || account.status !== 'approved') {
    return fail(res, 400, '请先绑定并通过审核支付宝收款账号');
  }

  const created = await withTransaction(async (client) => {
    const wallet = await freezeWithdrawBalance(client, userId, amount);
    if (!wallet) {
      const error = new Error('可提现余额不足');
      error.statusCode = 400;
      throw error;
    }
    const result = await client.query(
      `
        insert into public.withdrawal_requests (
          user_id, amount, status, payout_account_snapshot, provider, updated_at
        ) values ($1,$2,'pending',$3::jsonb,'alipay',now())
        returning *
      `,
      [userId, amount, JSON.stringify(account)],
    );
    await recordWalletTransaction(client, {
      userId,
      orderId: null,
      type: 'withdraw_freeze',
      amount: -amount,
      actualAmount: -amount,
      description: '申请提现，冻结可提现余额',
    });
    return result.rows[0];
  });

  return ok(res, { data: created, message: '提现申请已提交' });
}));

appRouter.get('/admin/withdrawals', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const status = req.query.status?.toString().trim();
  const result = await pool.query(
    `
      select wr.*, u.phone, u.nickname
      from public.withdrawal_requests wr
      join public.users u on u.id = wr.user_id
      where ($1::text is null or wr.status = $1)
      order by wr.created_at desc
      limit 200
    `,
    [status || null],
  );
  return ok(res, { data: result.rows });
}));

appRouter.get('/admin/payout-accounts', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const status = req.query.status?.toString().trim();
  const result = await pool.query(
    `
      select
        gpa.*,
        u.phone,
        u.nickname
      from public.guide_payout_accounts gpa
      join public.users u on u.id = gpa.user_id
      where ($1::text is null or gpa.status = $1)
      order by gpa.updated_at desc
      limit 200
    `,
    [status || null],
  );
  return ok(res, { data: result.rows });
}));

appRouter.post('/admin/payout-accounts/:userId/approve', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const result = await pool.query(
    `
      update public.guide_payout_accounts
      set status = 'approved', reject_reason = null, verified_at = now(), updated_at = now()
      where user_id = $1 and status = 'pending'
      returning *
    `,
    [req.params.userId],
  );
  if (!result.rows[0]) return fail(res, 404, '收款账号不存在或当前状态不能审核');
  return ok(res, { data: result.rows[0], message: '支付宝收款账号已审核通过' });
}));

appRouter.post('/admin/payout-accounts/:userId/reject', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const reason = req.body?.reason?.toString().trim() || '支付宝收款账号审核未通过';
  const result = await pool.query(
    `
      update public.guide_payout_accounts
      set status = 'rejected', reject_reason = $2, verified_at = null, updated_at = now()
      where user_id = $1 and status = 'pending'
      returning *
    `,
    [req.params.userId, reason],
  );
  if (!result.rows[0]) return fail(res, 404, '收款账号不存在或当前状态不能驳回');
  return ok(res, { data: result.rows[0], message: '支付宝收款账号已驳回' });
}));

appRouter.get('/admin/guide-insurance', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const result = await pool.query(
    `
      select i.*, u.nickname, u.phone
      from public.guide_insurance_policies i
      join public.users u on u.id = i.guide_id
      order by i.updated_at desc
      limit 200
    `,
  );
  return ok(res, { data: result.rows });
}));

appRouter.post('/admin/guide-insurance/:guideId/approve', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const result = await pool.query(
    `update public.guide_insurance_policies set status = 'approved', reject_reason = null, updated_at = now() where guide_id = $1 and status = 'pending' returning *`,
    [req.params.guideId],
  );
  if (!result.rows[0]) return fail(res, 404, '保险资料不存在或当前状态不能审核');
  return ok(res, { data: result.rows[0], message: '保险资料已审核通过' });
}));

appRouter.post('/admin/guide-insurance/:guideId/reject', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const reason = req.body?.reason?.toString().trim() || '保险资料审核未通过';
  const result = await pool.query(
    `update public.guide_insurance_policies set status = 'rejected', reject_reason = $2, updated_at = now() where guide_id = $1 and status = 'pending' returning *`,
    [req.params.guideId, reason],
  );
  if (!result.rows[0]) return fail(res, 404, '保险资料不存在或当前状态不能审核');
  return ok(res, { data: result.rows[0], message: '保险资料已驳回' });
}));

appRouter.get('/admin/guide-support-requests', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const result = await pool.query(
    `
      select r.*, u.nickname, u.phone
      from public.guide_support_requests r
      join public.users u on u.id = r.guide_id
      order by r.created_at desc
      limit 200
    `,
  );
  return ok(res, { data: result.rows });
}));

appRouter.post('/admin/guide-support-requests/:id/reply', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const reply = req.body?.reply?.toString().trim() ?? '';
  if (!reply) return fail(res, 400, '回复内容不能为空');
  const moderation = await reviewText(reply, { field: '运营回复' });
  if (!moderation.passed || moderation.reviewStatus === 'pending') return fail(res, 400, '回复内容需要审核后才能提交');
  const result = await pool.query(
    `update public.guide_support_requests set reply = $2, status = 'resolved', updated_at = now() where id = $1 returning *`,
    [req.params.id, reply],
  );
  if (!result.rows[0]) return fail(res, 404, '运营工单不存在');
  return ok(res, { data: result.rows[0], message: '回复已发送' });
}));

appRouter.post('/admin/withdrawals/:id/approve', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const result = await pool.query(
    `
      update public.withdrawal_requests
      set status = 'approved', reviewed_at = now(), updated_at = now()
      where id = $1 and status = 'pending'
      returning *
    `,
    [req.params.id],
  );
  if (!result.rows[0]) return fail(res, 404, '提现申请不存在或状态不可审核');
  return ok(res, { data: result.rows[0], message: '提现申请已审核通过' });
}));

appRouter.post('/admin/withdrawals/:id/reject', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const reason = req.body?.reason?.toString().trim() ?? '审核未通过';
  const rejected = await withTransaction(async (client) => {
    const query = await client.query(
      `
        update public.withdrawal_requests
        set status = 'rejected', reject_reason = $2, reviewed_at = now(), updated_at = now()
        where id = $1 and status in ('pending','approved','transfer_failed')
        returning *
      `,
      [req.params.id, reason],
    );
    const item = query.rows[0];
    if (!item) return null;
    await refundWithdrawBalance(client, item.user_id, Number(item.amount));
    await recordWalletTransaction(client, {
      userId: item.user_id,
      orderId: null,
      type: 'withdraw_reject_refund',
      amount: Number(item.amount),
      actualAmount: Number(item.amount),
      description: `提现驳回，余额退回：${reason}`,
    });
    return item;
  });
  if (!rejected) return fail(res, 404, '提现申请不存在或状态不可驳回');
  return ok(res, { data: rejected, message: '提现申请已驳回并退回余额' });
}));

appRouter.post('/admin/withdrawals/:id/transfer', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const remark = req.body?.remark?.toString().trim() ?? '';

  const withdrawal = await withTransaction(async (client) => {
    const query = await client.query(
      `
        update public.withdrawal_requests
        set
          status = 'transferring',
          reject_reason = null,
          updated_at = now()
        where id = $1 and status in ('approved','transfer_failed')
        returning *
      `,
      [req.params.id],
    );
    return query.rows[0] ?? null;
  });

  if (!withdrawal) {
    return fail(res, 404, '提现申请不存在，或当前状态不能自动打款');
  }

  const account = withdrawal.payout_account_snapshot ?? {};
  try {
    const transfer = await transferToAlipayAccount({
      withdrawalId: withdrawal.id,
      amount: Number(withdrawal.amount),
      alipayAccount: account.alipay_account,
      alipayUserId: account.alipay_user_id,
      realName: account.real_name,
      remark: remark || `一点伴提现 ${withdrawal.id}`,
    });

    const transferStatus = transfer.status?.toString().trim().toUpperCase() || 'SUCCESS';
    if (transferStatus !== 'SUCCESS') {
      await pool.query(
        `
          update public.withdrawal_requests
          set
            status = 'transferring',
            provider_order_no = coalesce($2, provider_order_no),
            reject_reason = $3,
            updated_at = now()
          where id = $1 and status = 'transferring'
        `,
        [
          withdrawal.id,
          transfer.orderId || transfer.payFundOrderId || transfer.outBizNo,
          `支付宝返回状态：${transfer.status}`,
        ],
      );
      return ok(res, {
        data: { withdrawal, transfer },
        message: `支付宝已受理，当前状态：${transfer.status}，请稍后查询`,
      });
    }

    const paid = await withTransaction(async (client) => {
      const query = await client.query(
        `
          update public.withdrawal_requests
          set
            status = 'paid',
            provider_order_no = $2,
            reject_reason = null,
            paid_at = now(),
            updated_at = now()
          where id = $1 and status = 'transferring'
          returning *
        `,
        [withdrawal.id, transfer.orderId || transfer.payFundOrderId || transfer.outBizNo],
      );
      const item = query.rows[0];
      if (!item) return null;
      await recordWalletTransaction(client, {
        userId: item.user_id,
        orderId: null,
        type: 'withdraw_paid',
        amount: -Number(item.amount),
        actualAmount: -Number(item.amount),
        description: `提现已通过支付宝自动打款，流水：${transfer.orderId || transfer.outBizNo}`,
      });
      return item;
    });

    return ok(res, {
      data: {
        withdrawal: paid,
        transfer,
      },
      message: '支付宝自动打款成功',
    });
  } catch (error) {
    const uncertain = error.remoteAttempted === true;
    const reason = error.message || '支付宝自动打款失败';
    await pool.query(
      `
        update public.withdrawal_requests
        set status = $2, reject_reason = $3, updated_at = now()
        where id = $1 and status = 'transferring'
      `,
      [
        withdrawal.id,
        uncertain ? 'transferring' : 'transfer_failed',
        `${uncertain ? '支付宝已请求但结果未知，请查询：' : ''}${reason}`.slice(0, 500),
      ],
    );
    return fail(
      res,
      502,
      uncertain
        ? `支付宝返回结果未知，请点击“查询转账状态”：${reason}`
        : `支付宝自动打款失败：${reason}`,
    );
  }
}));

appRouter.post('/admin/withdrawals/:id/query-transfer', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const result = await pool.query(
    `select * from public.withdrawal_requests where id = $1 limit 1`,
    [req.params.id],
  );
  const withdrawal = result.rows[0];
  if (!withdrawal) return fail(res, 404, '提现申请不存在');
  if (!['transferring', 'transfer_failed'].includes(withdrawal.status)) {
    return fail(res, 400, '当前提现状态不需要查询支付宝');
  }

  try {
    const transfer = await queryAlipayTransfer({ withdrawalId: withdrawal.id });
    const transferStatus = transfer.status?.toString().trim().toUpperCase() || 'DEALING';

    if (transferStatus === 'SUCCESS') {
      const paid = await withTransaction(async (client) => {
        const update = await client.query(
          `
            update public.withdrawal_requests
            set
              status = 'paid',
              provider_order_no = coalesce($2, provider_order_no),
              reject_reason = null,
              paid_at = now(),
              updated_at = now()
            where id = $1 and status <> 'paid'
            returning *
          `,
          [
            withdrawal.id,
            transfer.orderId || transfer.payFundOrderId || transfer.outBizNo,
          ],
        );
        const item = update.rows[0];
        if (!item) return withdrawal;
        await recordWalletTransaction(client, {
          userId: item.user_id,
          orderId: null,
          type: 'withdraw_paid',
          amount: -Number(item.amount),
          actualAmount: -Number(item.amount),
          description: `查询确认支付宝提现成功，流水：${transfer.orderId || transfer.outBizNo}`,
        });
        return item;
      });
      return ok(res, {
        data: { withdrawal: paid, transfer },
        message: '查询确认：支付宝已打款成功',
      });
    }

    if (transferStatus === 'FAIL' || transferStatus === 'FAILED') {
      const failed = await pool.query(
        `
          update public.withdrawal_requests
          set
            status = 'transfer_failed',
            provider_order_no = coalesce($2, provider_order_no),
            reject_reason = $3,
            updated_at = now()
          where id = $1
          returning *
        `,
        [
          withdrawal.id,
          transfer.orderId || transfer.payFundOrderId || transfer.outBizNo,
          transfer.failReason || '支付宝转账失败',
        ],
      );
      return ok(res, {
        data: { withdrawal: failed.rows[0], transfer },
        message: '查询确认：支付宝转账失败，可重试或驳回提现',
      });
    }

    const pending = await pool.query(
      `
        update public.withdrawal_requests
        set
          status = 'transferring',
          provider_order_no = coalesce($2, provider_order_no),
          reject_reason = $3,
          updated_at = now()
        where id = $1
        returning *
      `,
      [
        withdrawal.id,
        transfer.orderId || transfer.payFundOrderId || transfer.outBizNo,
        `支付宝当前状态：${transfer.status}`,
      ],
    );
    return ok(res, {
      data: { withdrawal: pending.rows[0], transfer },
      message: `支付宝当前状态：${transfer.status}，请稍后再次查询`,
    });
  } catch (error) {
    return fail(res, 502, `查询支付宝转账失败：${error.message}`);
  }
}));

appRouter.post('/admin/withdrawals/:id/mark-paid', handleRoute(async (req, res) => {
  const adminId = await requireAdminUser(req, res);
  if (!adminId) return;
  const providerOrderNo = req.body?.provider_order_no?.toString().trim() ?? '';
  const paid = await withTransaction(async (client) => {
    const query = await client.query(
      `
        update public.withdrawal_requests
        set
          status = 'paid',
          provider_order_no = coalesce($2, provider_order_no),
          reject_reason = null,
          paid_at = now(),
          updated_at = now()
        where id = $1 and status in ('approved','transfer_failed')
        returning *
      `,
      [req.params.id, providerOrderNo || null],
    );
    const item = query.rows[0];
    if (!item) return null;
    await recordWalletTransaction(client, {
      userId: item.user_id,
      orderId: null,
      type: 'withdraw_paid',
      amount: -Number(item.amount),
      actualAmount: -Number(item.amount),
      description: '提现已打款到支付宝',
    });
    return item;
  });
  if (!paid) return fail(res, 404, '提现申请不存在或尚未审核通过');
  return ok(res, { data: paid, message: '提现已标记为打款完成' });
}));

appRouter.post('/uploads/post-image', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const relativeUrl = await persistBase64Upload({
    category: 'posts',
    filename: payload.filename ?? `post_${userId}.jpg`,
    mimeType: payload.mime_type ?? payload.mimeType ?? 'image/jpeg',
    bytesBase64: payload.bytes_base64 ?? payload.bytesBase64,
  });
  const publicUrl = buildPublicUrl(req, relativeUrl);
  const moderation = await reviewImage(publicUrl, { field: 'post image' });
  if (!moderation.passed) {
    return fail(res, 400, 'image blocked by moderation', {
      moderation_hits: moderation.hits,
    });
  }
  return ok(res, {
    data: {
      url: publicUrl,
      review_status: moderation.reviewStatus,
      moderation_hits: moderation.hits,
    },
    message: moderation.reviewStatus === 'pending' ? 'pending manual review' : 'uploaded',
  });
}));

appRouter.post('/uploads/demand-image', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const relativeUrl = await persistBase64Upload({
    category: 'demands',
    filename: payload.filename ?? `demand_${userId}.jpg`,
    mimeType: payload.mime_type ?? payload.mimeType ?? 'image/jpeg',
    bytesBase64: payload.bytes_base64 ?? payload.bytesBase64,
  });
  return ok(res, { data: { url: buildPublicUrl(req, relativeUrl) } });
}));

appRouter.post('/uploads/review-image', reviewImageUpload.single('file'), handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const relativeUrl = await persistUploadedFile({
    category: 'reviews',
    file: req.file,
  });
  return ok(res, { data: { url: buildPublicUrl(req, relativeUrl) } });
}));

appRouter.post('/uploads/avatar', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const relativeUrl = await persistBase64Upload({
    category: 'avatars',
    filename: payload.filename ?? `avatar_${userId}.jpg`,
    mimeType: payload.mime_type ?? payload.mimeType ?? 'image/jpeg',
    bytesBase64: payload.bytes_base64 ?? payload.bytesBase64,
  });
  return ok(res, { data: { url: buildPublicUrl(req, relativeUrl) } });
}));

appRouter.get('/guide-applications/me', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const result = await pool.query(
    `select * from public.guide_applications where user_id = $1 order by created_at desc limit 1`,
    [userId],
  );
  return ok(res, { data: result.rows[0] ?? null });
});

appRouter.post('/guide-applications', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const result = await pool.query(
    `
      insert into public.guide_applications (
        user_id, full_name, gender, city, avatar, bio, service_tags, images, status
      ) values ($1,$2,$3,$4,$5,$6,$7::text[],$8::text[],'pending')
      on conflict (user_id) do update set
        full_name = excluded.full_name,
        gender = excluded.gender,
        city = excluded.city,
        avatar = excluded.avatar,
        bio = excluded.bio,
        service_tags = excluded.service_tags,
        images = excluded.images,
        status = 'pending'
      returning *
    `,
    [
      userId,
      payload.full_name ?? payload.fullName ?? '未命名',
      payload.gender ?? '',
      payload.city ?? '',
      payload.avatar ?? '',
      payload.bio ?? '',
      payload.service_tags ?? payload.serviceTags ?? [],
      payload.images ?? [],
    ],
  );
  return ok(res, { data: result.rows[0] });
});

appRouter.put('/guides/me/location', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const result = await pool.query(
    `
      update public.guides
      set
        current_lat = $2,
        current_lng = $3,
        current_location_text = coalesce($4, current_location_text),
        location_updated_at = now()
      where id = $1
      returning *
    `,
    [
      userId,
      toNullableNumber(payload.latitude ?? payload.current_lat),
      toNullableNumber(payload.longitude ?? payload.current_lng),
      payload.location_text?.toString() ??
          payload.current_location_text?.toString() ??
          null,
    ],
  );
  if (!result.rows[0]) {
    return fail(res, 404, 'guide not found');
  }
  return ok(res, {
    data: {
      ...result.rows[0],
      current_lat: toNullableNumber(result.rows[0].current_lat),
      current_lng: toNullableNumber(result.rows[0].current_lng),
    },
  });
}));

appRouter.get('/admin/guide-applications', async (_req, res) => {
  const result = await pool.query(`select * from public.guide_applications where status = 'pending' order by created_at desc`);
  return ok(res, { data: result.rows });
});

appRouter.post('/admin/guide-applications/:id/audit', async (req, res) => {
  await pool.query(
    `
      update public.guide_applications
      set status = $2, reject_reason = $3
      where id = $1
    `,
    [req.params.id, req.body?.status ?? 'rejected', req.body?.reject_reason ?? null],
  );
  return ok(res, { message: '审核完成' });
});
