import express from 'express';
import crypto from 'crypto';
import fs from 'fs/promises';
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
import { assertPayloadAllowed, assertTextAllowed, reviewImage } from '../services/moderation.js';
import {
  buildTrtcCredential,
  buildTrtcRoomId,
} from '../services/trtc.js';
import { bindAxbVirtualNumber } from '../services/virtual_number.js';

export const appRouter = express.Router();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const uploadsDir = path.resolve(__dirname, '../../uploads');

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
  return req.sessionUserId || req.headers['x-user-id']?.toString().trim() || '';
}

function normalizePhone(phone) {
  return phone.replace(/\s+/g, '');
}

function readWhitelistCode(phone) {
  return config.authWhitelist[phone] ?? '';
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
  if (!phone) return fail(res, 400, '手机号不能为空');
  if (config.authWhitelistEnabled) {
    const whitelistCode = readWhitelistCode(phone);
    if (!whitelistCode) {
      return fail(res, 403, '该手机号不在测试白名单中');
    }
  }
  return ok(res, { message: '验证码已发送', data: { phone } });
}));

appRouter.post('/auth/verify-code', handleRoute(async (req, res) => {
  const phone = normalizePhone(req.body?.phone?.toString().trim() ?? '');
  const code = req.body?.code?.toString().trim() ?? '';
  if (!phone) return fail(res, 400, '手机号不能为空');
  if (!code) return fail(res, 400, '验证码不能为空');

  if (config.authWhitelistEnabled) {
    const whitelistCode = readWhitelistCode(phone);
    if (!whitelistCode) {
      return fail(res, 403, '该手机号不在测试白名单中');
    }
    if (code !== whitelistCode) {
      return fail(res, 400, '验证码错误');
    }
  }

  const existingUser = await findUserByPhone(pool, phone);
  const userId = existingUser?.id ?? crypto.randomUUID();
  const session = {
    access_token: userId,
    user_id: userId,
  };
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
  return ok(res, { message: '登录成功', session });
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
    guide_introduction:
      payload.guide_introduction ?? currentUser.guide_introduction ?? '',
    guide_tags: payload.guide_tags ?? currentUser.guide_tags ?? [],
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
  return ok(res, { data: updated });
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
  const result = await pool.query(`select * from public.guides order by created_at desc`);
  return ok(res, { data: result.rows });
});

appRouter.get('/guides/:id', async (req, res) => {
  const result = await pool.query(`select * from public.guides where id = $1 limit 1`, [req.params.id]);
  if (!result.rows[0]) return fail(res, 404, '地陪不存在');
  return ok(res, { data: result.rows[0] });
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
    location: payload.tag ?? '',
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
  const result = await pool.query(`select * from public.demands order by created_at desc`);
  return ok(res, {
    data: result.rows.map((row) => withDistanceFields(row, guideLocation)),
  });
});

appRouter.get('/demands/me', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const result = await pool.query(
    `
      select *
      from public.demands
      where author_id = $1
      order by created_at desc
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
        da.id as application_id,
        da.status as application_status,
        da.note as application_note,
        da.created_at as application_created_at
      from public.demand_applications da
      join public.demands d on d.id = da.demand_id
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
    `select * from public.demands where id = $1 limit 1`,
    [req.params.id],
  );
  const demand = demandResult.rows[0];
  if (!demand) return fail(res, 404, '需求不存在');

  const applications = await pool.query(
    `
      select *
      from public.demand_applications
      where demand_id = $1
      order by created_at desc
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
        people_count, gender, budget, status, author_id, author_name,
        author_avatar, tags, review_status, reject_reason
      ) values (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16::text[],$17,$18
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
      payload.status ?? 'open',
      userId,
      payload.author_name ?? '我',
      payload.author_avatar ?? '',
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
  if (demand.author_id === userId) return fail(res, 400, '不能报名自己的需求');

  const guideResult = await pool.query(
    `select * from public.guides where id = $1 limit 1`,
    [userId],
  );
  const guide = guideResult.rows[0];
  if (!guide) return fail(res, 403, '当前账号还不是已入驻地陪');

  const payload = req.body ?? {};
  await assertPayloadAllowed(payload, [
    { key: 'note', label: '报名备注' },
  ]);
  const result = await pool.query(
    `
      insert into public.demand_applications (
        demand_id, guide_id, guide_name, guide_avatar, guide_city, note, status
      ) values ($1,$2,$3,$4,$5,$6,'pending')
      on conflict (demand_id, guide_id) do update
      set
        note = excluded.note,
        guide_name = excluded.guide_name,
        guide_avatar = excluded.guide_avatar,
        guide_city = excluded.guide_city
      returning *
    `,
    [
      req.params.id,
      userId,
      guide.name ?? '',
      guide.avatar ?? '',
      guide.city ?? '',
      payload.note?.toString() ?? '',
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
        Number.parseFloat(payload.amount?.toString() ?? '') || 0,
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
      select *
      from public.orders
      where user_id = $1 or guide_id = $1
      order by created_at desc
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
  const result = await pool.query(
    `
      insert into public.orders (
        user_id, guide_id, guide_name, guide_avatar, status, amount,
        service_name, service_address, service_city, service_lat, service_lng,
        service_date, payment_method, payment_status, merchant_order_no, created_at
      )
      values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14, now())
      returning *
    `,
    [
      userId,
      guideId,
      payload.guideName ?? payload.guide_name ?? '',
      payload.guideAvatar ?? payload.guide_avatar ?? '',
      payload.status ?? 0,
      payload.amount ?? 0,
      payload.serviceName ?? payload.service_name ?? '',
      payload.serviceAddress ?? payload.service_address ?? '',
      payload.serviceCity ?? payload.service_city ?? '',
      toNullableNumber(payload.serviceLat ?? payload.service_lat),
      toNullableNumber(payload.serviceLng ?? payload.service_lng),
      payload.serviceDate ?? payload.service_date ?? null,
      payload.paymentMethod ?? payload.payment_method ?? 'alipay',
      payload.paymentStatus ?? payload.payment_status ?? 'pending',
      payload.merchantOrderNo ?? payload.merchant_order_no ?? null,
    ],
  );
  const guideLocation = await fetchGuideLocation(pool, guideId);
  return ok(res, { data: withDistanceFields(result.rows[0], guideLocation) });
}));

appRouter.post('/orders/one-cent-test', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  let guideId = payload.guideId ?? payload.guide_id;
  let guide;

  if (guideId?.toString().trim()) {
    const guideResult = await pool.query(
      `select * from public.guides where id = $1 limit 1`,
      [guideId],
    );
    guide = guideResult.rows[0];
  } else {
    const guideResult = await pool.query(
      `
        select *
        from public.guides
        where id <> $1
        order by created_at desc nulls last
        limit 1
      `,
      [userId],
    );
    guide = guideResult.rows[0];
    guideId = guide?.id;
  }

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
      values ($1,$2,$3,$4,0,0.01,$5,$6,$7,$8,$9,$10,'alipay','pending',$11,now())
      returning *
    `,
    [
      userId,
      guideId,
      guide.name ?? payload.guideName ?? payload.guide_name ?? '测试地陪',
      guide.avatar ?? payload.guideAvatar ?? payload.guide_avatar ?? '',
      payload.serviceName ?? payload.service_name ?? '0.01元地陪接单支付测试',
      payload.serviceAddress ?? payload.service_address ?? '0.01测试服务地点',
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
    message: '0.01测试订单已创建，等待地陪接单后付款',
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
  await withTransaction(async (client) => {
    await client.query(`update public.orders set status = 3 where id = $1`, [req.params.id]);
    if (order.payment_status === 'paid') {
      await releasePendingBalance(client, order.guide_id, Number(order.amount));
      await recordWalletTransaction(client, {
        userId: order.guide_id,
        orderId: order.id,
        type: 'income_available',
        amount: Number(order.amount),
        actualAmount: Number(order.amount),
        description: `订单完成，收入转为可提现：${order.service_name ?? '地陪服务订单'}`,
      });
    }
  });
  return ok(res, { message: '已完成' });
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
    trtc: credential,
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
  const recent = await pool.query(
    `
      select *
      from public.call_sessions
      where order_id = $1
        and status in ('created', 'ringing', 'answered')
        and created_at > now() - interval '30 minutes'
      order by created_at desc
      limit 1
    `,
    [order.id],
  );
  if (recent.rows[0]) {
    const credential = buildTrtcCredential(userId);
    return ok(res, {
      data: buildCallPayload(recent.rows[0], credential),
      message: '已有进行中的语音通话',
    });
  }

  const roomId = buildTrtcRoomId(`${order.id}:${Date.now()}`);
  const created = await pool.query(
    `
      insert into public.call_sessions (
        order_id, caller_user_id, callee_user_id, room_id, provider, status, started_at, updated_at
      ) values ($1,$2,$3,$4,'trtc','ringing',now(),now())
      returning *
    `,
    [order.id, userId, calleeUserId, roomId],
  );
  const credential = buildTrtcCredential(userId);
  return ok(res, {
    data: buildCallPayload(created.rows[0], credential),
    message: '语音通话已创建',
  });
}));

appRouter.get('/calls/incoming', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const result = await pool.query(
    `
      select *
      from public.call_sessions
      where callee_user_id = $1
        and status = 'ringing'
        and created_at > now() - interval '2 minutes'
      order by created_at desc
      limit 10
    `,
    [userId],
  );
  return ok(res, { data: result.rows });
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
        and (caller_user_id = $2 or callee_user_id = $2)
        and status in ('ringing', 'answered')
      returning *
    `,
    [req.params.id, userId],
  );
  const call = result.rows[0];
  if (!call) return fail(res, 404, '通话不存在或已结束');
  const credential = buildTrtcCredential(userId);
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
  const call = result.rows[0];
  if (!call) return fail(res, 404, '通话不存在或已结束');
  return ok(res, { data: call, message: '语音通话已结束' });
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
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const alipayAccount = payload.alipay_account?.toString().trim() ?? '';
  const alipayUserId = payload.alipay_user_id?.toString().trim() ?? '';
  const realName = payload.real_name?.toString().trim() ?? '';
  if (!realName) return fail(res, 400, '真实姓名不能为空');
  if (!alipayAccount && !alipayUserId) {
    return fail(res, 400, '支付宝账号或支付宝 user_id 至少填写一个');
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
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const amount = Number(req.body?.amount ?? 0);
  if (!(amount > 0)) return fail(res, 400, '提现金额必须大于0');
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
        where id = $1 and status in ('pending','approved')
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
          paid_at = now(),
          updated_at = now()
        where id = $1 and status = 'approved'
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
