export async function findUserById(client, userId) {
  const result = await client.query(
    `
      select *
      from public.users
      where id = $1
      limit 1
    `,
    [userId],
  );
  return result.rows[0] ?? null;
}

export async function findUserByPhone(client, phone) {
  const normalizedPhone = phone?.toString().trim() ?? '';
  if (!normalizedPhone) return null;

  const result = await client.query(
    `
      select *
      from public.users
      where phone = $1 or nickname = $1
      order by case when phone = $1 then 0 else 1 end, created_at asc nulls last
      limit 1
    `,
    [normalizedPhone],
  );
  return result.rows[0] ?? null;
}

export async function upsertUser(client, payload) {
  const fields = [
    'id',
    'phone',
    'nickname',
    'avatar',
    'bio',
    'gender',
    'city',
    'birthday',
    'wechat',
    'occupation',
    'ethnicity',
    'education',
    'height_cm',
    'weight_kg',
    'guide_introduction',
    'guide_tags',
    'service_description',
    'extra_fee_description',
    'vip_level',
    'title',
    'balance',
    'coupon_count',
    'follow_count',
    'fans_count',
    'is_banned',
    'cancel_count',
    'is_admin',
  ];

  const values = fields.map((field) => payload[field] ?? null);
  const placeholders = fields.map((_, index) => `$${index + 1}`).join(', ');

  const sql = `
    insert into public.users (${fields.join(', ')})
    values (${placeholders})
    on conflict (id) do update set
      phone = coalesce(excluded.phone, public.users.phone),
      nickname = excluded.nickname,
      avatar = excluded.avatar,
      bio = excluded.bio,
      gender = excluded.gender,
      city = excluded.city,
      birthday = excluded.birthday,
      wechat = excluded.wechat,
      occupation = excluded.occupation,
      ethnicity = excluded.ethnicity,
      education = excluded.education,
      height_cm = excluded.height_cm,
      weight_kg = excluded.weight_kg,
      guide_introduction = excluded.guide_introduction,
      guide_tags = excluded.guide_tags,
      service_description = excluded.service_description,
      extra_fee_description = excluded.extra_fee_description,
      vip_level = excluded.vip_level,
      title = excluded.title,
      balance = excluded.balance,
      coupon_count = excluded.coupon_count,
      follow_count = excluded.follow_count,
      fans_count = excluded.fans_count,
      is_banned = excluded.is_banned,
      cancel_count = excluded.cancel_count,
      is_admin = excluded.is_admin
    returning *
  `;

  const result = await client.query(sql, values);
  return result.rows[0] ?? null;
}

export async function listUsersByIds(client, ids) {
  if (!ids.length) return [];
  const result = await client.query(
    `
      select *
      from public.users
      where id = any($1::uuid[])
    `,
    [ids],
  );
  return result.rows;
}
