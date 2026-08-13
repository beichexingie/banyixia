import express from 'express';

import { pool } from '../db.js';
import { fail, ok } from '../utils/http.js';
import { reviewText } from '../services/moderation.js';

export const guideRouter = express.Router();

function userIdFrom(req) {
  return (
    req.sessionUserId ||
    req.headers['x-user-id']?.toString().trim() ||
    req.authToken ||
    ''
  );
}

async function requireGuide(req, res) {
  const userId = userIdFrom(req);
  if (!userId) {
    fail(res, 401, '未登录');
    return null;
  }
  const result = await pool.query(
    `select exists(select 1 from public.guides where id = $1) as is_guide`,
    [userId],
  );
  if (!result.rows[0]?.is_guide) {
    fail(res, 403, '只有已通过地陪申请的账号才能使用地陪端');
    return null;
  }
  return userId;
}

function route(handler) {
  return async (req, res) => {
    try {
      await handler(req, res);
    } catch (error) {
      console.error(`[guideRouter] ${req.method} ${req.originalUrl}`, error);
      if (!res.headersSent) fail(res, error.statusCode || 500, error.message || '请求失败');
    }
  };
}

function clean(value, fallback = '') {
  return value == null ? fallback : value.toString().trim();
}

function number(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function mapServiceItem(row) {
  return {
    ...row,
    service_type: row.service_type || row.name || '',
    price_per_hour: number(row.price_per_hour),
    price_per_day: 0,
    enabled: true,
  };
}

function dateOffsetFromToday(value) {
  const date = new Date(`${value}T00:00:00`);
  if (Number.isNaN(date.getTime())) return null;
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return Math.floor((date.getTime() - today.getTime()) / 86400000);
}

async function getGuideServiceTypes(guideId) {
  const result = await pool.query(
    `select guide_tags from public.users where id = $1 limit 1`,
    [guideId],
  );
  return Array.isArray(result.rows[0]?.guide_tags)
    ? result.rows[0].guide_tags.map((item) => item?.toString().trim()).filter(Boolean)
    : [];
}

function mapReview(row) {
  return {
    id: row.id,
    order_id: row.order_id,
    rating: row.rating,
    content: row.content,
    is_anonymous: row.is_anonymous,
    customer_name: '匿名客户',
    guide_reply: row.guide_reply,
    replied_at: row.replied_at,
    service_name: row.service_name || '地陪服务',
    service_date: row.service_date,
    created_at: row.created_at,
  };
}

const taskDefinitions = [
  { key: 'profile', title: '完善地陪资料', description: '补充昵称、城市、介绍和服务标签', icon: 'person' },
  { key: 'service_item', title: '上架服务项目', description: '至少有一个已上架且价格有效的服务项目', icon: 'service' },
  { key: 'availability', title: '设置可接单时间', description: '至少添加一个可接单时间段', icon: 'calendar' },
  { key: 'first_order', title: '完成首笔服务', description: '完成一笔真实订单后自动完成', icon: 'order' },
  { key: 'first_review', title: '获得首条评价', description: '客户提交评价后自动完成', icon: 'review' },
];

async function getTaskState(guideId) {
  const result = await pool.query(
    `
      select t.task_key, t.progress, t.completed_at,
        u.nickname, u.city, u.guide_introduction, u.guide_tags,
        exists(select 1 from public.guide_service_items s where s.guide_id = $1 and s.enabled = true and (s.price_per_hour > 0 or s.price_per_day > 0)) as has_service,
         exists(select 1 from public.guide_availability a where a.guide_id = $1 and a.is_available = true and (a.service_date >= current_date or a.date_end >= current_date or a.date_end is null)) as has_schedule,
        exists(select 1 from public.orders o where o.guide_id = $1 and o.status = 3) as has_order,
        exists(select 1 from public.guide_reviews r where r.guide_id = $1) as has_review
      from public.users u
      left join public.guide_task_progress t on t.guide_id = u.id
      where u.id = $1
    `,
    [guideId],
  );
  const row = result.rows[0] || {};
  const profileDone = Boolean(row.nickname && row.city && row.guide_introduction && (row.guide_tags || []).length);
  const computed = {
    profile: profileDone,
    service_item: Boolean(row.has_service),
    availability: Boolean(row.has_schedule),
    first_order: Boolean(row.has_order),
    first_review: Boolean(row.has_review),
  };
  const progressRows = await pool.query(
    `select task_key, progress, completed_at from public.guide_task_progress where guide_id = $1`,
    [guideId],
  );
  const saved = new Map(progressRows.rows.map((item) => [item.task_key, item]));
  return taskDefinitions.map((item) => ({
    ...item,
    done: computed[item.key] || Boolean(saved.get(item.key)?.completed_at),
    progress: computed[item.key] || saved.get(item.key)?.completed_at ? 100 : (saved.get(item.key)?.progress || 0),
  }));
}

guideRouter.get('/console', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const [settings, services, availability, reviews, courses, progress, blocked, insurance, support, tasks, profile, serviceLocations] = await Promise.all([
    pool.query(`select * from public.guide_settings where user_id = $1 limit 1`, [guideId]),
    pool.query(`select * from public.guide_service_items where guide_id = $1 order by updated_at desc`, [guideId]),
    pool.query(`select * from public.guide_availability where guide_id = $1 and (service_date >= current_date - 1 or date_end >= current_date or date_end is null) order by coalesce(date_start, service_date), start_time`, [guideId]),
    pool.query(`select r.*, o.service_name, o.service_date from public.guide_reviews r join public.orders o on o.id = r.order_id where r.guide_id = $1 order by r.created_at desc limit 100`, [guideId]),
    pool.query(`select * from public.guide_training_courses where published = true order by sort_order, id`),
    pool.query(`select course_id, completed_at from public.guide_training_progress where guide_id = $1`, [guideId]),
    pool.query(`select b.*, u.nickname, u.phone from public.guide_blocked_users b join public.users u on u.id = b.blocked_user_id where b.guide_id = $1 order by b.created_at desc`, [guideId]),
    pool.query(`select * from public.guide_insurance_policies where guide_id = $1 limit 1`, [guideId]),
    pool.query(`select * from public.guide_support_requests where guide_id = $1 order by created_at desc limit 50`, [guideId]),
    getTaskState(guideId),
    pool.query(`select guide_tags from public.users where id = $1 limit 1`, [guideId]),
    pool.query(`select * from public.guide_service_locations where guide_id = $1 order by is_selected desc, updated_at desc`, [guideId]),
  ]);
  const completedCourses = new Set(progress.rows.map((item) => item.course_id));
  return ok(res, {
    data: {
      settings: settings.rows[0] || null,
      guide_tags: profile.rows[0]?.guide_tags ?? [],
      service_locations: serviceLocations.rows,
      service_items: services.rows.map(mapServiceItem),
      availability: availability.rows,
      reviews: reviews.rows.map(mapReview),
      training: courses.rows.map((item) => ({ ...item, completed: completedCourses.has(item.id) })),
      tasks,
      blocked_users: blocked.rows.map((item) => ({ ...item, phone: item.phone ? `${item.phone.slice(0, 3)}****${item.phone.slice(-4)}` : '' })),
      insurance: insurance.rows[0] || null,
      support_requests: support.rows,
    },
  });
}));

function mapServiceLocation(row) {
  return {
    ...row,
    latitude: number(row.latitude),
    longitude: number(row.longitude),
    is_selected: Boolean(row.is_selected),
  };
}

async function syncSelectedGuideLocation(client, guideId, locationId) {
  const selected = await client.query(
    `select * from public.guide_service_locations where id = $1 and guide_id = $2 limit 1`,
    [locationId, guideId],
  );
  if (!selected.rows[0]) return null;
  await client.query(
    `update public.guide_service_locations set is_selected = false, updated_at = now() where guide_id = $1`,
    [guideId],
  );
  const result = await client.query(
    `update public.guide_service_locations set is_selected = true, updated_at = now() where id = $1 and guide_id = $2 returning *`,
    [locationId, guideId],
  );
  const row = result.rows[0];
  await client.query(
    `update public.guides
     set current_lat = $2, current_lng = $3, current_location_text = $4, city = coalesce(nullif($5, ''), city), location_updated_at = now()
     where id = $1`,
    [guideId, row.latitude, row.longitude, row.address, row.city || ''],
  );
  return mapServiceLocation(row);
}

guideRouter.get('/service-locations', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const result = await pool.query(
    `select * from public.guide_service_locations where guide_id = $1 order by is_selected desc, updated_at desc`,
    [guideId],
  );
  return ok(res, { data: result.rows.map(mapServiceLocation) });
}));

guideRouter.post('/service-locations', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const label = clean(req.body?.label, '服务地址');
  const city = clean(req.body?.city);
  const address = clean(req.body?.address);
  const latitude = number(req.body?.latitude, NaN);
  const longitude = number(req.body?.longitude, NaN);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || !address) {
    return fail(res, 400, 'service_location_coordinates_required');
  }
  const client = await pool.connect();
  try {
    await client.query('begin');
    const existing = await client.query(
      `select id from public.guide_service_locations where guide_id = $1 limit 1`,
      [guideId],
    );
    const select = req.body?.select !== false || existing.rows.length === 0;
    if (select) {
      await client.query(
        `update public.guide_service_locations set is_selected = false, updated_at = now() where guide_id = $1`,
        [guideId],
      );
    }
    const result = await client.query(
      `insert into public.guide_service_locations (guide_id, label, city, address, latitude, longitude, is_selected)
       values ($1,$2,$3,$4,$5,$6,$7) returning *`,
      [guideId, label, city, address, latitude, longitude, select],
    );
    let row = result.rows[0];
    if (select) row = await syncSelectedGuideLocation(client, guideId, row.id);
    await client.query('commit');
    return ok(res, { data: mapServiceLocation(row) });
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally {
    client.release();
  }
}));

guideRouter.put('/service-locations/:id', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const latitude = number(req.body?.latitude, NaN);
  const longitude = number(req.body?.longitude, NaN);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || !clean(req.body?.address)) {
    return fail(res, 400, 'service_location_coordinates_required');
  }
  const result = await pool.query(
    `update public.guide_service_locations
     set label = $3, city = $4, address = $5, latitude = $6, longitude = $7, updated_at = now()
     where id = $1 and guide_id = $2 returning *`,
    [req.params.id, guideId, clean(req.body?.label, '服务地址'), clean(req.body?.city), clean(req.body?.address), latitude, longitude],
  );
  if (!result.rows[0]) return fail(res, 404, 'service_location_not_found');
  if (result.rows[0].is_selected) {
    await pool.query(
      `update public.guides set current_lat=$2, current_lng=$3, current_location_text=$4, city=coalesce(nullif($5,''), city), location_updated_at=now() where id=$1`,
      [guideId, latitude, longitude, clean(req.body?.address), clean(req.body?.city)],
    );
  }
  return ok(res, { data: mapServiceLocation(result.rows[0]) });
}));

guideRouter.post('/service-locations/:id/select', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const client = await pool.connect();
  try {
    await client.query('begin');
    await client.query('select pg_advisory_xact_lock(hashtext($1))', [guideId]);
    const selected = await syncSelectedGuideLocation(client, guideId, req.params.id);
    if (!selected) {
      await client.query('rollback');
      return fail(res, 404, 'service_location_not_found');
    }
    const all = await client.query(
      `select * from public.guide_service_locations where guide_id=$1 order by is_selected desc, updated_at desc`,
      [guideId],
    );
    await client.query('commit');
    return ok(res, { data: all.rows.map(mapServiceLocation) });
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally {
    client.release();
  }
}));

guideRouter.delete('/service-locations/:id', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const result = await pool.query(
    `delete from public.guide_service_locations where id=$1 and guide_id=$2 returning is_selected`,
    [req.params.id, guideId],
  );
  if (!result.rows[0]) return fail(res, 404, 'service_location_not_found');
  if (result.rows[0].is_selected) {
    const next = await pool.query(
      `select id from public.guide_service_locations where guide_id=$1 order by updated_at desc limit 1`,
      [guideId],
    );
    if (next.rows[0]) {
      const client = await pool.connect();
      try {
        await client.query('begin');
        await syncSelectedGuideLocation(client, guideId, next.rows[0].id);
        await client.query('commit');
      } catch (error) {
        await client.query('rollback');
        throw error;
      } finally {
        client.release();
      }
    } else {
      await pool.query(`update public.guides set current_lat=null, current_lng=null, current_location_text=null, location_updated_at=now() where id=$1`, [guideId]);
    }
  }
  const remaining = await pool.query(
    `select * from public.guide_service_locations where guide_id=$1 order by is_selected desc, updated_at desc`,
    [guideId],
  );
  return ok(res, {
    message: 'service_location_deleted',
    data: remaining.rows.map(mapServiceLocation),
  });
}));

guideRouter.put('/settings', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const payload = req.body || {};
  const auxiliary = payload.auxiliary && typeof payload.auxiliary === 'object' ? payload.auxiliary : {};
  const result = await pool.query(
    `insert into public.guide_settings (user_id, online, duty_mode, city, nearby_only, auxiliary, updated_at)
     values ($1,$2,$3,$4,$5,$6::jsonb,now())
     on conflict (user_id) do update set online=excluded.online, duty_mode=excluded.duty_mode, city=excluded.city, nearby_only=excluded.nearby_only, auxiliary=excluded.auxiliary, updated_at=now()
     returning *`,
    [guideId, Boolean(payload.online), clean(payload.duty_mode, 'nearby'), clean(payload.city), payload.nearby_only !== false, JSON.stringify(auxiliary)],
  );
  return ok(res, { data: result.rows[0] });
}));

guideRouter.post('/service-items', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const name = clean(req.body?.service_type ?? req.body?.name);
  const description = clean(req.body?.description);
  const hour = number(req.body?.price_per_hour);
  const types = await getGuideServiceTypes(guideId);
  if (!types.includes(name)) return fail(res, 400, 'service_type_must_be_selected_in_profile');
  if (hour <= 0) return fail(res, 400, 'hourly_price_must_be_positive');
  if (!name || (hour <= 0 && day <= 0)) return fail(res, 400, '服务名称和至少一个有效价格不能为空');
  const result = await pool.query(
    `insert into public.guide_service_items (guide_id,name,service_type,description,price_per_hour,price_per_day,enabled,updated_at) values ($1,$2,$2,$3,$4,0,true,now()) returning *`,
    [guideId, name, description, hour],
  );
  return ok(res, { data: mapServiceItem(result.rows[0]) });
}));

guideRouter.put('/service-items/:id', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const requestedName = req.body?.service_type ?? req.body?.name;
  const types = await getGuideServiceTypes(guideId);
  if (requestedName != null && !types.includes(clean(requestedName))) return fail(res, 400, 'service_type_must_be_selected_in_profile');
  const requestedHour = req.body?.price_per_hour == null ? null : number(req.body.price_per_hour);
  if (requestedHour != null && requestedHour <= 0) return fail(res, 400, 'hourly_price_must_be_positive');
  const result = await pool.query(
    `update public.guide_service_items set name=coalesce($3,name), service_type=coalesce($3,service_type,name), description=coalesce($4,description), price_per_hour=coalesce($5,price_per_hour), price_per_day=0, enabled=true, updated_at=now() where id=$1 and guide_id=$2 returning *`,
    [req.params.id, guideId, requestedName == null ? null : clean(requestedName), req.body?.description == null ? null : clean(req.body.description), requestedHour],
  );
  if (!result.rows[0]) return fail(res, 404, '服务项目不存在');
  return ok(res, { data: mapServiceItem(result.rows[0]) });
}));

guideRouter.delete('/service-items/:id', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  await pool.query(`delete from public.guide_service_items where id=$1 and guide_id=$2`, [req.params.id, guideId]);
  return ok(res, { message: '服务项目已删除' });
}));

guideRouter.post('/availability', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const date = clean(req.body?.service_date);
  const recurrenceType = clean(req.body?.recurrence_type, 'exact');
  const weekdays = Array.isArray(req.body?.weekdays)
    ? req.body.weekdays.map((item) => Number(item)).filter((item) => item >= 1 && item <= 7)
    : [];
  const dateStart = clean(req.body?.date_start || date);
  const dateEnd = clean(req.body?.date_end || dateStart);
  const start = clean(req.body?.start_time);
  const end = clean(req.body?.end_time);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !/^\d{2}:\d{2}$/.test(start) || !/^\d{2}:\d{2}$/.test(end)) return fail(res, 400, '日期和时间格式不正确');
  const dateOffset = dateOffsetFromToday(date);
  if (dateOffset == null || dateOffset < 0 || dateOffset > 6) return fail(res, 400, '接单时间只能设置未来7天');
  if (dateStart !== date || dateEnd !== date) return fail(res, 400, '接单时间必须使用具体日期');
  if (recurrenceType !== 'exact') return fail(res, 400, '接单时间必须使用具体日期');
  if (!['exact', 'daily', 'weekly'].includes(recurrenceType) || !/^\d{4}-\d{2}-\d{2}$/.test(dateStart) || !/^\d{4}-\d{2}-\d{2}$/.test(dateEnd)) return fail(res, 400, 'invalid availability rule');
  if (recurrenceType === 'weekly' && weekdays.length === 0) return fail(res, 400, 'weekdays required');
  const result = await pool.query(
    `insert into public.guide_availability (guide_id,service_date,start_time,end_time,note,is_available,recurrence_type,weekdays,date_start,date_end,updated_at) values ($1,$2,$3,$4,$5,$6,$7,$8::int[],$9,$10,now()) returning *`,
    [guideId, dateStart, start, end, clean(req.body?.note), req.body?.is_available !== false, recurrenceType, weekdays, dateStart, dateEnd],
  );
  return ok(res, { data: result.rows[0] });
}));

guideRouter.delete('/availability/:id', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  await pool.query(`delete from public.guide_availability where id=$1 and guide_id=$2`, [req.params.id, guideId]);
  return ok(res, { message: '时间段已删除' });
}));

guideRouter.post('/reviews/:id/reply', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const reply = clean(req.body?.reply);
  if (!reply) return fail(res, 400, '回复内容不能为空');
  const moderation = await reviewText(reply, { field: '评价回复' });
  if (!moderation.passed || moderation.reviewStatus === 'pending') return fail(res, 400, '回复内容需要审核后才能提交');
  const result = await pool.query(`update public.guide_reviews set guide_reply=$3,replied_at=now() where id=$1 and guide_id=$2 returning *`, [req.params.id, guideId, reply]);
  if (!result.rows[0]) return fail(res, 404, '评价不存在');
  return ok(res, { data: result.rows[0], message: '回复已提交' });
}));

guideRouter.post('/tasks/:key/complete', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const task = taskDefinitions.find((item) => item.key === req.params.key);
  if (!task) return fail(res, 404, '任务不存在');
  const state = await getTaskState(guideId);
  const current = state.find((item) => item.key === task.key);
  if (!current?.done) return fail(res, 400, `完成条件未满足：${task.description}`);
  const result = await pool.query(`insert into public.guide_task_progress (guide_id,task_key,progress,completed_at,updated_at) values ($1,$2,100,now(),now()) on conflict (guide_id,task_key) do update set progress=100,completed_at=coalesce(guide_task_progress.completed_at,now()),updated_at=now() returning *`, [guideId, task.key]);
  return ok(res, { data: result.rows[0], message: '任务已完成' });
}));

guideRouter.post('/training/:courseId/complete', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const course = await pool.query(`select id from public.guide_training_courses where id=$1 and published=true`, [req.params.courseId]);
  if (!course.rows[0]) return fail(res, 404, '培训课程不存在');
  const result = await pool.query(`insert into public.guide_training_progress (guide_id,course_id,completed_at) values ($1,$2,now()) on conflict (guide_id,course_id) do update set completed_at=now() returning *`, [guideId, req.params.courseId]);
  return ok(res, { data: result.rows[0], message: '课程已完成' });
}));

guideRouter.post('/blocked-users', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const phone = clean(req.body?.phone);
  const targetId = clean(req.body?.user_id);
  const target = targetId ? await pool.query(`select id from public.users where id=$1 limit 1`, [targetId]) : await pool.query(`select id from public.users where phone=$1 limit 1`, [phone]);
  if (!target.rows[0]) return fail(res, 404, '找不到这个用户');
  if (target.rows[0].id === guideId) return fail(res, 400, '不能屏蔽自己');
  const result = await pool.query(`insert into public.guide_blocked_users (guide_id,blocked_user_id,reason) values ($1,$2,$3) on conflict (guide_id,blocked_user_id) do update set reason=excluded.reason returning *`, [guideId, target.rows[0].id, clean(req.body?.reason)]);
  return ok(res, { data: result.rows[0], message: '已加入屏蔽名单' });
}));

guideRouter.delete('/blocked-users/:id', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  await pool.query(`delete from public.guide_blocked_users where guide_id=$1 and blocked_user_id=$2`, [guideId, req.params.id]);
  return ok(res, { message: '已移出屏蔽名单' });
}));

guideRouter.put('/insurance', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const provider = clean(req.body?.provider);
  const policyNo = clean(req.body?.policy_no);
  if (!provider || !policyNo) return fail(res, 400, '保险公司和保单号不能为空');
  const result = await pool.query(`insert into public.guide_insurance_policies (guide_id,provider,policy_no,expires_at,document_url,status,reject_reason,updated_at) values ($1,$2,$3,$4,$5,'pending',null,now()) on conflict (guide_id) do update set provider=excluded.provider,policy_no=excluded.policy_no,expires_at=excluded.expires_at,document_url=excluded.document_url,status='pending',reject_reason=null,updated_at=now() returning *`, [guideId, provider, policyNo, clean(req.body?.expires_at) || null, clean(req.body?.document_url)]);
  return ok(res, { data: result.rows[0], message: '保险资料已提交，等待审核' });
}));

guideRouter.post('/support-requests', route(async (req, res) => {
  const guideId = await requireGuide(req, res);
  if (!guideId) return;
  const content = clean(req.body?.content);
  if (!content) return fail(res, 400, '请填写咨询内容');
  const moderation = await reviewText(content, { field: '运营咨询' });
  if (!moderation.passed) return fail(res, 400, '咨询内容未通过审核');
  const result = await pool.query(`insert into public.guide_support_requests (guide_id,category,content) values ($1,$2,$3) returning *`, [guideId, clean(req.body?.category, '运营咨询'), content]);
  return ok(res, { data: result.rows[0], message: '已提交给专属运营' });
}));

