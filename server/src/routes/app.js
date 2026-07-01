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

async function requireSessionUser(req, res) {
  const userId = getSessionUserId(req);
  if (!userId) {
    fail(res, 401, '未登录');
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
  const updated = await upsertUser(pool, {
    id: userId,
    nickname: payload.nickname ?? '新用户',
    avatar: payload.avatar ?? '',
    bio: payload.bio ?? '',
    gender: payload.gender ?? '',
    city: payload.city ?? '',
    birthday: payload.birthday ?? '',
    wechat: payload.wechat ?? '',
    occupation: payload.occupation ?? '',
    guide_introduction: payload.guide_introduction ?? '',
    guide_tags: payload.guide_tags ?? [],
    vip_level: payload.vip_level ?? 1,
    title: payload.title ?? '初级旅行家',
    balance: payload.balance ?? 0,
    coupon_count: payload.coupon_count ?? 0,
    follow_count: payload.follow_count ?? 0,
    fans_count: payload.fans_count ?? 0,
    is_banned: payload.is_banned ?? false,
    cancel_count: payload.cancel_count ?? 0,
    is_admin: payload.is_admin ?? false,
  });
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
  return ok(res, {
    data: {
      favorite_ids: favoriteIds.rows.map((row) => row.guide_id),
      liked_ids: likedIds.rows.map((row) => row.guide_id),
      footprints: footprints.rows,
    },
  });
});

appRouter.get('/users/me/following', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const result = await pool.query(
    `
      select u.*
      from public.follows f
      join public.users u on u.id = f.followed_id
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
  const posts = await listPosts(pool, { query: req.query.q?.toString().trim() || '' });
  return ok(res, { data: posts });
});

appRouter.get('/posts/following', async (req, res) => {
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
        coalesce(p.likes, 0) as likes,
        (
          select count(*)
          from public.post_comments pc
          where pc.post_id = p.id
        )::int as comments,
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
  const posts = await listPostsByUser(pool, req.params.id);
  return ok(res, { data: posts });
});

appRouter.post('/posts', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const created = await createPost(pool, {
    user_id: userId,
    author_name: payload.author_name ?? '我',
    author_avatar: payload.author_avatar ?? '',
    content: `${payload.title ?? ''}\n${payload.content ?? ''}`.trim(),
    images: payload.images ?? [],
    location: payload.tag ?? '',
  });
  return ok(res, { data: created });
});

appRouter.post('/posts/:id/like', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(
    `insert into public.post_likes (user_id, post_id) values ($1, $2) on conflict do nothing`,
    [userId, req.params.id],
  );
  await pool.query(`update public.posts set likes = coalesce(likes, 0) + 1 where id = $1`, [req.params.id]);
  return ok(res, { message: '已点赞' });
});
appRouter.delete('/posts/:id/like', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  await pool.query(`delete from public.post_likes where user_id = $1 and post_id = $2`, [userId, req.params.id]);
  await pool.query(
    `update public.posts set likes = greatest(coalesce(likes, 0) - 1, 0) where id = $1`,
    [req.params.id],
  );
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
        coalesce(p.likes, 0) as likes,
        (
          select count(*)
          from public.post_comments pc
          where pc.post_id = p.id
        )::int as comments,
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
        coalesce(p.likes, 0) as likes,
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
  const result = await pool.query(
    `
      select *
      from public.post_comments
      where post_id = $1
      order by created_at asc
    `,
    [req.params.id],
  );
  return ok(res, { data: result.rows });
});
appRouter.post('/posts/:id/comments', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const content = req.body?.content?.toString().trim() ?? '';
  if (!content) return fail(res, 400, '评论不能为空');
  const result = await pool.query(
    `
      insert into public.post_comments (post_id, user_id, content)
      values ($1, $2, $3)
      returning *
    `,
    [req.params.id, userId, content],
  );
  return ok(res, { data: result.rows[0], message: '评论成功' });
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
        coalesce(p.likes, 0) as likes,
        (
          select count(*)
          from public.post_comments pc
          where pc.post_id = p.id
        )::int as comments,
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

appRouter.get('/demands', async (_req, res) => {
  const result = await pool.query(`select * from public.demands order by created_at desc`);
  return ok(res, { data: result.rows });
});

appRouter.post('/demands', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const payload = req.body ?? {};
  const result = await pool.query(
    `
      insert into public.demands (
        title, content, city, location, service_start_at, service_end_at,
        people_count, gender, budget, status, author_id, author_name,
        author_avatar, tags
      ) values (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14::text[]
      ) returning *
    `,
    [
      payload.title,
      payload.content,
      payload.city,
      payload.location,
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
    ],
  );
  return ok(res, { data: result.rows[0] });
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
  return ok(res, { data: result.rows });
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
        service_name, payment_method, payment_status, merchant_order_no, created_at
      )
      values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10, now())
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
      payload.paymentMethod ?? payload.payment_method ?? 'alipay',
      payload.paymentStatus ?? payload.payment_status ?? 'pending',
      payload.merchantOrderNo ?? payload.merchant_order_no ?? null,
    ],
  );
  return ok(res, { data: result.rows[0] });
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

appRouter.post('/orders/:id/complete', handleRoute(async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const order = await findOrderById(pool, req.params.id);
  if (!order) return fail(res, 404, '订单不存在');
  if (order.user_id !== userId && order.guide_id !== userId) {
    return fail(res, 403, '无权限操作订单');
  }
  await pool.query(`update public.orders set status = 3 where id = $1`, [req.params.id]);
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

appRouter.get('/wallet', async (req, res) => {
  const userId = await requireSessionUser(req, res);
  if (!userId) return;
  const wallet = await pool.query(`select * from public.wallets where user_id = $1 limit 1`, [userId]);
  const tx = await pool.query(`select * from public.transactions where user_id = $1 order by created_at desc`, [userId]);
  return ok(res, { data: { wallet: wallet.rows[0] ?? null, transactions: tx.rows } });
});

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
