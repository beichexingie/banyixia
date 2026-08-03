import express from 'express';

import { pool } from '../db.js';
import { ok, fail } from '../utils/http.js';
import { assertPayloadAllowed } from '../services/moderation.js';

export const adminRouter = express.Router();

const ROLE_PERMISSIONS = {
  admin: [
    'stats',
    'users',
    'orders',
    'review',
    'chat',
    'activity',
    'coupon',
    'staff',
    'logs',
    'system',
  ],
  support: ['chat', 'review', 'activity', 'coupon'],
  operator: ['review', 'activity', 'coupon', 'chat'],
  reviewer: ['review', 'chat'],
};

function handleRoute(handler) {
  return async (req, res, next) => {
    try {
      await handler(req, res, next);
    } catch (error) {
      console.error(`[adminRouter] ${req.method} ${req.originalUrl}`, error);
      if (res.headersSent) return;
      if (error.statusCode) {
        return fail(res, error.statusCode, error.message || '请求失败');
      }
      return fail(res, 500, error.message || '后台服务异常');
    }
  };
}

function getActorId(req) {
  return (
    req.sessionUserId ||
    req.headers['x-user-id']?.toString().trim() ||
    req.authToken ||
    ''
  );
}

function normalizeLimit(value, fallback = 30, max = 100) {
  const parsed = Number.parseInt(value?.toString() ?? '', 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(parsed, max);
}

function normalizeOffset(value) {
  const parsed = Number.parseInt(value?.toString() ?? '', 10);
  if (!Number.isFinite(parsed) || parsed < 0) return 0;
  return parsed;
}

function normalizeStatus(value, fallback) {
  const status = value?.toString().trim();
  return status || fallback;
}

function tableForContentType(type) {
  switch (type) {
    case 'post':
    case 'posts':
      return { table: 'public.posts', label: 'post' };
    case 'comment':
    case 'comments':
      return { table: 'public.post_comments', label: 'comment' };
    case 'demand':
    case 'demands':
      return { table: 'public.demands', label: 'demand' };
    case 'guide-application':
    case 'guide_application':
    case 'guide_applications':
      return { table: 'public.guide_applications', label: 'guide_application' };
    default:
      return null;
  }
}

async function writeOperationLog(req, action, targetType, targetId, detail = {}) {
  const actorId = getActorId(req) || null;
  await pool.query(
    `
      insert into public.admin_operation_logs (
        actor_user_id, action, target_type, target_id, detail, ip
      ) values ($1,$2,$3,$4,$5::jsonb,$6)
    `,
    [
      actorId,
      action,
      targetType,
      targetId?.toString() ?? null,
      JSON.stringify(detail),
      req.ip ?? '',
    ],
  );
}

async function resolveAdminUser(userId) {
  if (!userId) return null;
  const result = await pool.query(
    `
      select
        u.id,
        u.phone,
        u.nickname,
        u.avatar,
        u.is_admin,
        s.role as staff_role,
        s.permissions,
        s.display_name,
        s.is_active
      from public.users u
      left join public.admin_staff s on s.user_id = u.id
      where u.id = $1
      limit 1
    `,
    [userId],
  );
  const user = result.rows[0];
  if (!user) return null;
  const role = user.is_admin ? 'admin' : user.staff_role;
  if (!role || (user.is_admin !== true && user.is_active === false)) return null;
  const basePermissions = ROLE_PERMISSIONS[role] ?? [];
  const extraPermissions = Array.isArray(user.permissions) ? user.permissions : [];
  return {
    id: user.id,
    phone: user.phone,
    nickname: user.nickname,
    avatar: user.avatar,
    display_name: user.display_name || user.nickname || user.phone || '后台用户',
    role,
    permissions: Array.from(new Set([...basePermissions, ...extraPermissions])),
  };
}

function requirePermission(permission) {
  return handleRoute(async (req, res, next) => {
    const actorId = getActorId(req);
    const adminUser = await resolveAdminUser(actorId);
    if (!adminUser) {
      return fail(res, 401, '请先使用管理员或客服账号进入后台');
    }
    if (!adminUser.permissions.includes(permission)) {
      return fail(res, 403, '当前账号没有该后台权限');
    }
    req.adminUser = adminUser;
    return next();
  });
}

function requireAdminOnly(req, res, next) {
  if (req.adminUser?.role !== 'admin') {
    return fail(res, 403, '仅管理员可操作');
  }
  return next();
}

adminRouter.get('/me', handleRoute(async (req, res) => {
  const adminUser = await resolveAdminUser(getActorId(req));
  if (!adminUser) {
    return fail(res, 401, '请先使用管理员或客服账号进入后台');
  }
  return ok(res, { data: adminUser });
}));

adminRouter.get('/stats', requirePermission('stats'), handleRoute(async (_req, res) => {
  const result = await pool.query(`
    select
      (select count(*)::int from public.users) as total_users,
      (select count(*)::int from public.guides) as total_guides,
      (select count(*)::int from public.orders) as total_orders,
      (select count(*)::int from public.orders where created_at >= date_trunc('day', now())) as today_orders,
      (select coalesce(sum(amount), 0)::float from public.orders where payment_status = 'paid') as paid_gmv,
      (select coalesce(sum(amount), 0)::float from public.orders where payment_status = 'paid' and paid_at >= date_trunc('day', now())) as today_gmv,
      (select count(*)::int from public.users where created_at >= date_trunc('day', now())) as today_new_users,
      (select count(*)::int from public.guide_applications where status = 'pending') as pending_guides,
      (select count(*)::int from public.posts where coalesce(review_status, 'approved') = 'pending') +
      (select count(*)::int from public.post_comments where coalesce(review_status, 'approved') = 'pending') +
      (select count(*)::int from public.demands where coalesce(review_status, 'approved') = 'pending') as pending_content,
      (select count(*)::int from public.chat_rooms) as chat_rooms,
      (select count(*)::int from public.messages where created_at >= now() - interval '1 day') as messages_24h
  `);
  const daily = await pool.query(`
    with days as (
      select generate_series(
        date_trunc('day', now()) - interval '13 days',
        date_trunc('day', now()),
        interval '1 day'
      ) as day
    ),
    user_days as (
      select date_trunc('day', created_at) as day, count(*)::int as new_users
      from public.users
      where created_at >= date_trunc('day', now()) - interval '13 days'
      group by date_trunc('day', created_at)
    ),
    order_days as (
      select
        date_trunc('day', created_at) as day,
        count(*)::int as orders,
        coalesce(sum(case when payment_status = 'paid' then amount else 0 end), 0)::float as gmv
      from public.orders
      where created_at >= date_trunc('day', now()) - interval '13 days'
      group by date_trunc('day', created_at)
    )
    select
      to_char(days.day, 'MM-DD') as label,
      coalesce(user_days.new_users, 0)::int as new_users,
      coalesce(order_days.orders, 0)::int as orders,
      coalesce(order_days.gmv, 0)::float as gmv
    from days
    left join user_days on user_days.day = days.day
    left join order_days on order_days.day = days.day
    order by days.day
  `);
  const city = await pool.query(`
    select coalesce(nullif(city, ''), '未知') as city, count(*)::int as value
    from public.users
    group by coalesce(nullif(city, ''), '未知')
    order by value desc
    limit 8
  `);
  return ok(res, {
    data: {
      summary: result.rows[0],
      daily: daily.rows,
      city: city.rows,
    },
  });
}));

adminRouter.get('/users', requirePermission('users'), handleRoute(async (req, res) => {
  const limit = normalizeLimit(req.query.limit);
  const offset = normalizeOffset(req.query.offset);
  const keyword = req.query.q?.toString().trim() ?? '';
  const result = await pool.query(
    `
      select
        u.id,
        u.phone,
        u.nickname,
        u.avatar,
        u.city,
        u.is_banned,
        u.is_admin,
        u.created_at,
        exists(select 1 from public.guides g where g.id = u.id) as is_guide,
        coalesce((select count(*) from public.orders o where o.user_id = u.id), 0)::int as order_count
      from public.users u
      where $1 = ''
        or u.phone ilike '%' || $1 || '%'
        or u.nickname ilike '%' || $1 || '%'
        or u.city ilike '%' || $1 || '%'
      order by u.created_at desc nulls last
      limit $2 offset $3
    `,
    [keyword, limit, offset],
  );
  return ok(res, { data: result.rows });
}));

adminRouter.post('/users/:id/ban', requirePermission('users'), requireAdminOnly, handleRoute(async (req, res) => {
  const isBanned = req.body?.is_banned !== false;
  const result = await pool.query(
    `update public.users set is_banned = $2 where id = $1 returning id, phone, nickname, is_banned`,
    [req.params.id, isBanned],
  );
  if (!result.rows[0]) return fail(res, 404, '用户不存在');
  await writeOperationLog(req, isBanned ? 'ban_user' : 'unban_user', 'user', req.params.id);
  return ok(res, { data: result.rows[0] });
}));

adminRouter.get('/orders', requirePermission('orders'), handleRoute(async (req, res) => {
  const limit = normalizeLimit(req.query.limit);
  const offset = normalizeOffset(req.query.offset);
  const keyword = req.query.q?.toString().trim() ?? '';
  const result = await pool.query(
    `
      select
        o.*,
        customer.phone as customer_phone,
        customer.nickname as customer_name,
        guide_user.phone as guide_phone
      from public.orders o
      left join public.users customer on customer.id = o.user_id
      left join public.users guide_user on guide_user.id = o.guide_id
      where $1 = ''
        or o.id::text ilike '%' || $1 || '%'
        or o.merchant_order_no ilike '%' || $1 || '%'
        or customer.phone ilike '%' || $1 || '%'
        or guide_user.phone ilike '%' || $1 || '%'
        or o.service_name ilike '%' || $1 || '%'
      order by o.created_at desc
      limit $2 offset $3
    `,
    [keyword, limit, offset],
  );
  return ok(res, { data: result.rows });
}));

adminRouter.get('/review/items', requirePermission('review'), handleRoute(async (req, res) => {
  const status = normalizeStatus(req.query.status, 'pending');
  const limit = normalizeLimit(req.query.limit, 50);
  const posts = await pool.query(
    `
      select
        'post' as type,
        p.id,
        p.user_id as author_id,
        coalesce(u.nickname, p.author_name, u.phone, '') as author_name,
        p.content,
        p.location as extra,
        p.review_status,
        p.reject_reason,
        p.created_at
      from public.posts p
      left join public.users u on u.id = p.user_id
      where coalesce(p.review_status, 'approved') = $1
      order by p.created_at desc
      limit $2
    `,
    [status, limit],
  );
  const comments = await pool.query(
    `
      select
        'comment' as type,
        pc.id,
        pc.user_id as author_id,
        coalesce(u.nickname, u.phone, '') as author_name,
        pc.content,
        pc.post_id::text as extra,
        pc.review_status,
        pc.reject_reason,
        pc.created_at
      from public.post_comments pc
      left join public.users u on u.id = pc.user_id
      where coalesce(pc.review_status, 'approved') = $1
      order by pc.created_at desc
      limit $2
    `,
    [status, limit],
  );
  const demands = await pool.query(
    `
      select
        'demand' as type,
        d.id,
        d.author_id,
        coalesce(u.nickname, d.author_name, u.phone, '') as author_name,
        concat(d.title, E'\n', d.content) as content,
        concat(d.city, ' ', d.location) as extra,
        d.review_status,
        d.reject_reason,
        d.created_at
      from public.demands d
      left join public.users u on u.id = d.author_id
      where coalesce(d.review_status, 'approved') = $1
      order by d.created_at desc
      limit $2
    `,
    [status, limit],
  );
  const guideApplications = await pool.query(
    `
      select
        'guide_application' as type,
        ga.id,
        ga.user_id as author_id,
        coalesce(ga.full_name, u.nickname, u.phone, '') as author_name,
        concat(coalesce(ga.full_name, ''), E'\n', coalesce(ga.bio, '')) as content,
        coalesce(ga.city, '') as extra,
        ga.status as review_status,
        ga.reject_reason,
        ga.created_at
      from public.guide_applications ga
      left join public.users u on u.id = ga.user_id
      where ga.status = $1
      order by ga.created_at desc
      limit $2
    `,
    [status === 'approved' ? 'approved' : status === 'rejected' ? 'rejected' : 'pending', limit],
  );
  const data = [
    ...posts.rows,
    ...comments.rows,
    ...demands.rows,
    ...guideApplications.rows,
  ].sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  return ok(res, { data: data.slice(0, limit) });
}));

async function updateContentReview(req, res, status) {
  const mapped = tableForContentType(req.params.type);
  if (!mapped) return fail(res, 400, '未知内容类型');
  const reason = req.body?.reject_reason?.toString().trim() || null;
  let result;
  if (mapped.label === 'guide_application') {
    result = await pool.query(
      `
        update public.guide_applications
        set status = $2, reject_reason = $3
        where id = $1
        returning *
      `,
      [req.params.id, status === 'approved' ? 'approved' : 'rejected', reason],
    );
    if (status === 'approved' && result.rows[0]) {
      await pool.query(
        `
          insert into public.guides (
            id, name, avatar, rating, gender, verified, tags, description, images, views, likes, fans, city, created_at
          )
          select
            ga.user_id,
            coalesce(nullif(ga.full_name, ''), u.nickname, '认证地陪'),
            coalesce(nullif(ga.avatar, ''), u.avatar, ''),
            5.0,
            coalesce(ga.gender, u.gender, ''),
            true,
            coalesce(ga.service_tags, u.guide_tags, array[]::text[]),
            coalesce(nullif(ga.bio, ''), u.guide_introduction, u.bio, ''),
            coalesce(ga.images, array[]::text[]),
            0,
            0,
            0,
            coalesce(nullif(ga.city, ''), u.city, ''),
            now()
          from public.guide_applications ga
          join public.users u on u.id = ga.user_id
          where ga.id = $1
          on conflict (id) do update set
            name = excluded.name,
            avatar = excluded.avatar,
            gender = excluded.gender,
            verified = true,
            tags = excluded.tags,
            description = excluded.description,
            images = excluded.images,
            city = excluded.city
        `,
        [req.params.id],
      );
      await pool.query(
        `insert into public.wallets (user_id) values ($1) on conflict (user_id) do nothing`,
        [result.rows[0].user_id],
      );
    }
  } else {
    result = await pool.query(
      `
        update ${mapped.table}
        set review_status = $2, reviewed_by = $3, reviewed_at = now(), reject_reason = $4
        where id = $1
        returning *
      `,
      [req.params.id, status, req.adminUser.id, reason],
    );
  }
  if (!result.rows[0]) return fail(res, 404, '待审核内容不存在');
  await writeOperationLog(req, `review_${status}`, mapped.label, req.params.id, { reason });
  return ok(res, { data: result.rows[0], message: status === 'approved' ? '已通过' : '已拒绝' });
}

adminRouter.post('/review/:type/:id/approve', requirePermission('review'), handleRoute(async (req, res) => {
  return updateContentReview(req, res, 'approved');
}));

adminRouter.post('/review/:type/:id/reject', requirePermission('review'), handleRoute(async (req, res) => {
  return updateContentReview(req, res, 'rejected');
}));

adminRouter.get('/chat/rooms', requirePermission('chat'), handleRoute(async (_req, res) => {
  const result = await pool.query(`
    select
      cr.*,
      array(
        select jsonb_build_object(
          'id', u.id,
          'phone', u.phone,
          'nickname', u.nickname,
          'avatar', u.avatar
        )
        from public.users u
        where u.id = any(cr.participant_ids)
      ) as participants,
      coalesce((
        select count(*)
        from public.messages m
        where m.room_id = cr.id and m.is_read = false
      ), 0)::int as unread_count
    from public.chat_rooms cr
    order by cr.last_message_time desc nulls last, cr.created_at desc
    limit 80
  `);
  return ok(res, { data: result.rows });
}));

adminRouter.get('/chat/rooms/:id', requirePermission('chat'), handleRoute(async (req, res) => {
  const room = await pool.query(
    `select * from public.chat_rooms where id = $1 limit 1`,
    [req.params.id],
  );
  if (!room.rows[0]) return fail(res, 404, '会话不存在');
  const messages = await pool.query(
    `
      select
        m.*,
        coalesce(u.nickname, u.phone, '用户') as sender_name,
        u.avatar as sender_avatar
      from public.messages m
      left join public.users u on u.id = m.sender_id
      where m.room_id = $1
      order by m.created_at asc
    `,
    [req.params.id],
  );
  return ok(res, { data: { ...room.rows[0], messages: messages.rows } });
}));

adminRouter.post('/chat/rooms/:id/messages', requirePermission('chat'), handleRoute(async (req, res) => {
  const content = req.body?.content?.toString().trim() ?? '';
  if (!content) return fail(res, 400, '消息内容不能为空');
  await assertPayloadAllowed({ content }, [{ key: 'content', label: '客服消息' }]);
  const result = await pool.query(
    `
      insert into public.messages (room_id, sender_id, content, type)
      values ($1, $2, $3, 'support')
      returning *
    `,
    [req.params.id, req.adminUser.id, content],
  );
  await writeOperationLog(req, 'send_support_message', 'chat_room', req.params.id);
  return ok(res, { data: result.rows[0] });
}));

adminRouter.get('/activities', requirePermission('activity'), handleRoute(async (_req, res) => {
  const result = await pool.query(`
    select *
    from public.admin_activities
    order by created_at desc
    limit 80
  `);
  return ok(res, { data: result.rows });
}));

adminRouter.post('/activities', requirePermission('activity'), handleRoute(async (req, res) => {
  const payload = req.body ?? {};
  await assertPayloadAllowed(payload, [
    { key: 'title', label: '活动标题' },
    { key: 'summary', label: '活动摘要' },
    { key: 'content', label: '活动内容' },
  ]);
  const result = await pool.query(
    `
      insert into public.admin_activities (
        title, summary, content, banner_image, status, starts_at, ends_at, created_by
      ) values ($1,$2,$3,$4,$5,$6,$7,$8)
      returning *
    `,
    [
      payload.title?.toString().trim() || '未命名活动',
      payload.summary?.toString().trim() || '',
      payload.content?.toString().trim() || '',
      payload.banner_image?.toString().trim() || '',
      payload.status?.toString().trim() || 'draft',
      payload.starts_at || null,
      payload.ends_at || null,
      req.adminUser.id,
    ],
  );
  await writeOperationLog(req, 'create_activity', 'activity', result.rows[0].id);
  return ok(res, { data: result.rows[0] });
}));

adminRouter.get('/coupons', requirePermission('coupon'), handleRoute(async (_req, res) => {
  const result = await pool.query(`
    select *
    from public.coupons
    order by created_at desc
    limit 80
  `);
  return ok(res, { data: result.rows });
}));

adminRouter.post('/coupons', requirePermission('coupon'), handleRoute(async (req, res) => {
  const payload = req.body ?? {};
  await assertPayloadAllowed(payload, [
    { key: 'title', label: '优惠券名称' },
    { key: 'code', label: '优惠码' },
  ]);
  const result = await pool.query(
    `
      insert into public.coupons (
        title, code, amount, min_spend, total_count, status, starts_at, ends_at, created_by
      ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9)
      returning *
    `,
    [
      payload.title?.toString().trim() || '未命名优惠券',
      payload.code?.toString().trim() || null,
      Number.parseFloat(payload.amount) || 0,
      Number.parseFloat(payload.min_spend) || 0,
      Number.parseInt(payload.total_count, 10) || 0,
      payload.status?.toString().trim() || 'draft',
      payload.starts_at || null,
      payload.ends_at || null,
      req.adminUser.id,
    ],
  );
  await writeOperationLog(req, 'create_coupon', 'coupon', result.rows[0].id);
  return ok(res, { data: result.rows[0] });
}));

adminRouter.get('/staff', requirePermission('staff'), requireAdminOnly, handleRoute(async (_req, res) => {
  const result = await pool.query(`
    select
      s.*,
      u.phone,
      u.nickname,
      u.avatar,
      u.is_admin
    from public.admin_staff s
    join public.users u on u.id = s.user_id
    order by s.created_at desc
  `);
  return ok(res, { data: result.rows });
}));

adminRouter.post('/staff', requirePermission('staff'), requireAdminOnly, handleRoute(async (req, res) => {
  const payload = req.body ?? {};
  const userId = payload.user_id?.toString().trim() ?? '';
  if (!userId) return fail(res, 400, '缺少 user_id');
  const role = payload.role?.toString().trim() || 'support';
  if (!ROLE_PERMISSIONS[role]) return fail(res, 400, '无效角色');
  const permissions = Array.isArray(payload.permissions) ? payload.permissions : [];
  const result = await pool.query(
    `
      insert into public.admin_staff (user_id, role, permissions, display_name, is_active, updated_at)
      values ($1,$2,$3::text[],$4,$5,now())
      on conflict (user_id) do update set
        role = excluded.role,
        permissions = excluded.permissions,
        display_name = excluded.display_name,
        is_active = excluded.is_active,
        updated_at = now()
      returning *
    `,
    [
      userId,
      role,
      permissions,
      payload.display_name?.toString().trim() || null,
      payload.is_active !== false,
    ],
  );
  await writeOperationLog(req, 'upsert_admin_staff', 'user', userId, { role });
  return ok(res, { data: result.rows[0] });
}));

adminRouter.get('/logs', requirePermission('logs'), requireAdminOnly, handleRoute(async (_req, res) => {
  const result = await pool.query(`
    select
      l.*,
      coalesce(u.nickname, u.phone, '') as actor_name
    from public.admin_operation_logs l
    left join public.users u on u.id = l.actor_user_id
    order by l.created_at desc
    limit 100
  `);
  return ok(res, { data: result.rows });
}));
