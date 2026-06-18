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

export async function upsertUser(client, payload) {
  const fields = [
    'id',
    'nickname',
    'avatar',
    'bio',
    'gender',
    'city',
    'birthday',
    'wechat',
    'occupation',
    'guide_introduction',
    'guide_tags',
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
      nickname = excluded.nickname,
      avatar = excluded.avatar,
      bio = excluded.bio,
      gender = excluded.gender,
      city = excluded.city,
      birthday = excluded.birthday,
      wechat = excluded.wechat,
      occupation = excluded.occupation,
      guide_introduction = excluded.guide_introduction,
      guide_tags = excluded.guide_tags,
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

