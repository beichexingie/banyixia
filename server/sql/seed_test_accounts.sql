-- Test accounts for local/staging verification.
-- This script is safe to run repeatedly. Existing users are matched by phone.

with seed_users as (
  select *
  from (
    values
      (
        '13800138000',
        '测试客户A',
        'https://picsum.photos/seed/ydb-customer-a/160/160',
        '用于客户端下单、发帖、呼叫地陪的测试客户。',
        'female',
        '苏州',
        1,
        '测试客户',
        3,
        0
      ),
      (
        '18860900310',
        '测试客户B',
        'https://picsum.photos/seed/ydb-customer-b/160/160',
        '用于客户端和地陪端交叉测试的第二个客户。',
        'male',
        '杭州',
        1,
        '测试客户',
        2,
        0
      ),
      (
        '13900010001',
        '测试地陪A',
        'https://picsum.photos/seed/ydb-guide-a/160/160',
        '熟悉苏州园林、博物馆和城市漫步路线。',
        'female',
        '苏州',
        2,
        '认证地陪',
        0,
        8
      ),
      (
        '13900010002',
        '测试地陪B',
        'https://picsum.photos/seed/ydb-guide-b/160/160',
        '熟悉杭州西湖、滨江夜游和轻徒步路线。',
        'male',
        '杭州',
        2,
        '认证地陪',
        0,
        12
      ),
      (
        '13900010003',
        '测试地陪C',
        'https://picsum.photos/seed/ydb-guide-c/160/160',
        '适合商务随行、会展接待和短途城市陪同。',
        'female',
        '上海',
        3,
        '金牌地陪',
        0,
        21
      )
  ) as item(
    phone,
    nickname,
    avatar,
    bio,
    gender,
    city,
    vip_level,
    title,
    coupon_count,
    fans_count
  )
)
insert into public.users (
  id,
  phone,
  nickname,
  avatar,
  bio,
  gender,
  city,
  vip_level,
  title,
  balance,
  coupon_count,
  follow_count,
  fans_count,
  is_banned,
  cancel_count,
  is_admin
)
select
  coalesce(existing.id, gen_random_uuid()),
  seed_users.phone,
  seed_users.nickname,
  seed_users.avatar,
  seed_users.bio,
  seed_users.gender,
  seed_users.city,
  seed_users.vip_level,
  seed_users.title,
  0,
  seed_users.coupon_count,
  0,
  seed_users.fans_count,
  false,
  0,
  false
from seed_users
left join public.users existing on existing.phone = seed_users.phone
on conflict (phone) where phone is not null and btrim(phone) <> '' do update set
  nickname = excluded.nickname,
  avatar = excluded.avatar,
  bio = excluded.bio,
  gender = excluded.gender,
  city = excluded.city,
  vip_level = excluded.vip_level,
  title = excluded.title,
  balance = excluded.balance,
  coupon_count = excluded.coupon_count,
  follow_count = excluded.follow_count,
  fans_count = excluded.fans_count,
  is_banned = excluded.is_banned,
  cancel_count = excluded.cancel_count,
  is_admin = excluded.is_admin;

with guide_seed as (
  select
    u.id,
    u.phone,
    u.nickname as name,
    u.avatar,
    u.bio,
    u.gender,
    u.city,
    case u.phone
      when '13900010001' then 4.9
      when '13900010002' then 4.8
      else 5.0
    end as rating,
    case u.phone
      when '13900010001' then array['城市漫步','拍照打卡','苏州园林']
      when '13900010002' then array['西湖路线','夜游','轻徒步']
      else array['商务随行','会展接待','机场高铁']
    end as tags,
    case u.phone
      when '13900010001' then array[
        'https://picsum.photos/seed/ydb-guide-a-1/800/600',
        'https://picsum.photos/seed/ydb-guide-a-2/800/600'
      ]
      when '13900010002' then array[
        'https://picsum.photos/seed/ydb-guide-b-1/800/600',
        'https://picsum.photos/seed/ydb-guide-b-2/800/600'
      ]
      else array[
        'https://picsum.photos/seed/ydb-guide-c-1/800/600',
        'https://picsum.photos/seed/ydb-guide-c-2/800/600'
      ]
    end as images,
    case u.phone
      when '13900010001' then 128
      when '13900010002' then 166
      else 210
    end as views,
    case u.phone
      when '13900010001' then 36
      when '13900010002' then 42
      else 58
    end as likes,
    case u.phone
      when '13900010001' then 8
      when '13900010002' then 12
      else 21
    end as fans,
    case u.phone
      when '13900010001' then 31.2990
      when '13900010002' then 30.2460
      else 31.2304
    end as current_lat,
    case u.phone
      when '13900010001' then 120.5853
      when '13900010002' then 120.1551
      else 121.4737
    end as current_lng,
    case u.phone
      when '13900010001' then '苏州市姑苏区'
      when '13900010002' then '杭州市西湖区'
      else '上海市黄浦区'
    end as current_location_text
  from public.users u
  where u.phone in ('13900010001', '13900010002', '13900010003')
)
insert into public.guides (
  id,
  name,
  avatar,
  rating,
  gender,
  verified,
  tags,
  description,
  images,
  views,
  likes,
  fans,
  city,
  current_lat,
  current_lng,
  current_location_text,
  location_updated_at
)
select
  id,
  name,
  avatar,
  rating,
  gender,
  true,
  tags,
  bio,
  images,
  views,
  likes,
  fans,
  city,
  current_lat,
  current_lng,
  current_location_text,
  now()
from guide_seed
on conflict (id) do update set
  name = excluded.name,
  avatar = excluded.avatar,
  rating = excluded.rating,
  gender = excluded.gender,
  verified = excluded.verified,
  tags = excluded.tags,
  description = excluded.description,
  images = excluded.images,
  views = excluded.views,
  likes = excluded.likes,
  fans = excluded.fans,
  city = excluded.city,
  current_lat = excluded.current_lat,
  current_lng = excluded.current_lng,
  current_location_text = excluded.current_location_text,
  location_updated_at = excluded.location_updated_at;

with guide_seed as (
  select
    u.id,
    u.phone,
    u.nickname,
    u.avatar,
    u.bio,
    u.gender,
    u.city,
    case u.phone
      when '13900010001' then array['城市漫步','拍照打卡','苏州园林']
      when '13900010002' then array['西湖路线','夜游','轻徒步']
      else array['商务随行','会展接待','机场高铁']
    end as service_tags,
    case u.phone
      when '13900010001' then array['https://picsum.photos/seed/ydb-guide-a-1/800/600']
      when '13900010002' then array['https://picsum.photos/seed/ydb-guide-b-1/800/600']
      else array['https://picsum.photos/seed/ydb-guide-c-1/800/600']
    end as images
  from public.users u
  where u.phone in ('13900010001', '13900010002', '13900010003')
)
insert into public.guide_applications (
  user_id,
  full_name,
  gender,
  city,
  avatar,
  bio,
  service_tags,
  images,
  status,
  contract_signed_at,
  contract_ip
)
select
  id,
  nickname,
  gender,
  city,
  avatar,
  bio,
  service_tags,
  images,
  'approved',
  now(),
  '127.0.0.1'
from guide_seed
on conflict (user_id) do update set
  full_name = excluded.full_name,
  gender = excluded.gender,
  city = excluded.city,
  avatar = excluded.avatar,
  bio = excluded.bio,
  service_tags = excluded.service_tags,
  images = excluded.images,
  status = excluded.status,
  contract_signed_at = excluded.contract_signed_at,
  contract_ip = excluded.contract_ip;

with ids as (
  select
    (select id from public.users where phone = '13800138000') as customer_a_id,
    (select id from public.users where phone = '18860900310') as customer_b_id,
    (select id from public.users where phone = '13900010001') as guide_a_id,
    (select id from public.users where phone = '13900010002') as guide_b_id,
    (select id from public.users where phone = '13900010003') as guide_c_id
),
order_seed as (
  select
    gen_random_uuid() as id,
    customer_a_id as user_id,
    guide_a_id as guide_id,
    '测试地陪A' as guide_name,
    'https://picsum.photos/seed/ydb-guide-a/160/160' as guide_avatar,
    1 as status,
    199.00::double precision as amount,
    '苏州半日城市漫步测试' as service_name,
    '苏州市姑苏区平江路' as service_address,
    '苏州' as service_city,
    31.3165::double precision as service_lat,
    120.6317::double precision as service_lng,
    1800 as distance_meters,
    2200 as route_distance_meters,
    1800 as route_duration_seconds,
    now() + interval '1 day' as service_date,
    'alipay' as payment_method,
    'accepted' as payment_status,
    'TEST-CALL-ORDER-001' as merchant_order_no,
    now() - interval '2 hours' as created_at
  from ids
  union all
  select
    gen_random_uuid(),
    customer_b_id,
    guide_b_id,
    '测试地陪B',
    'https://picsum.photos/seed/ydb-guide-b/160/160',
    1,
    299.00::double precision,
    '杭州西湖夜游测试',
    '杭州市西湖区断桥残雪',
    '杭州',
    30.2590::double precision,
    120.1485::double precision,
    2600,
    3200,
    2400,
    now() + interval '2 days',
    'alipay',
    'accepted',
    'TEST-CALL-ORDER-002',
    now() - interval '1 hour'
  from ids
  union all
  select
    gen_random_uuid(),
    customer_a_id,
    guide_c_id,
    '测试地陪C',
    'https://picsum.photos/seed/ydb-guide-c/160/160',
    0,
    399.00::double precision,
    '上海商务随行测试',
    '上海市黄浦区人民广场',
    '上海',
    31.2304::double precision,
    121.4737::double precision,
    1500,
    1800,
    1200,
    now() + interval '3 days',
    'alipay',
    'pending',
    'TEST-CALL-ORDER-003',
    now() - interval '30 minutes'
  from ids
)
insert into public.orders (
  id,
  user_id,
  guide_id,
  guide_name,
  guide_avatar,
  status,
  amount,
  service_name,
  service_address,
  service_city,
  service_lat,
  service_lng,
  distance_meters,
  route_distance_meters,
  route_duration_seconds,
  service_date,
  payment_method,
  payment_status,
  merchant_order_no,
  created_at
)
select
  coalesce(existing.id, order_seed.id),
  order_seed.user_id,
  order_seed.guide_id,
  order_seed.guide_name,
  order_seed.guide_avatar,
  order_seed.status,
  order_seed.amount,
  order_seed.service_name,
  order_seed.service_address,
  order_seed.service_city,
  order_seed.service_lat,
  order_seed.service_lng,
  order_seed.distance_meters,
  order_seed.route_distance_meters,
  order_seed.route_duration_seconds,
  order_seed.service_date,
  order_seed.payment_method,
  order_seed.payment_status,
  order_seed.merchant_order_no,
  coalesce(existing.created_at, order_seed.created_at)
from order_seed
left join public.orders existing
  on existing.merchant_order_no = order_seed.merchant_order_no
where order_seed.user_id is not null
  and order_seed.guide_id is not null
on conflict (merchant_order_no) where merchant_order_no is not null do update set
  user_id = excluded.user_id,
  guide_id = excluded.guide_id,
  guide_name = excluded.guide_name,
  guide_avatar = excluded.guide_avatar,
  status = excluded.status,
  amount = excluded.amount,
  service_name = excluded.service_name,
  service_address = excluded.service_address,
  service_city = excluded.service_city,
  service_lat = excluded.service_lat,
  service_lng = excluded.service_lng,
  distance_meters = excluded.distance_meters,
  route_distance_meters = excluded.route_distance_meters,
  route_duration_seconds = excluded.route_duration_seconds,
  service_date = excluded.service_date,
  payment_method = excluded.payment_method,
  payment_status = excluded.payment_status;
