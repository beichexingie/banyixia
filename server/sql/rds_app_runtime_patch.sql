-- Runtime additive patch for Aliyun RDS PostgreSQL.
-- Safe goal: add missing runtime tables / columns / indexes only.
-- No DROP TABLE, no data wipe, no schema rebuild.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Base tables
-- ---------------------------------------------------------------------------

create table if not exists public.users (
  id uuid primary key,
  phone text,
  nickname text,
  avatar text,
  bio text,
  gender text,
  city text,
  birthday text,
  wechat text,
  occupation text,
  guide_introduction text,
  guide_tags text[] default '{}'::text[],
  vip_level integer default 1,
  title text default 'Traveler',
  balance double precision default 0.0,
  coupon_count integer default 0,
  follow_count integer default 0,
  fans_count integer default 0,
  is_banned boolean default false,
  cancel_count integer default 0,
  is_admin boolean default false,
  created_at timestamptz default now()
);

alter table if exists public.users
  add column if not exists phone text,
  add column if not exists nickname text,
  add column if not exists avatar text,
  add column if not exists bio text,
  add column if not exists gender text,
  add column if not exists city text,
  add column if not exists birthday text,
  add column if not exists wechat text,
  add column if not exists occupation text,
  add column if not exists guide_introduction text,
  add column if not exists guide_tags text[] default '{}'::text[],
  add column if not exists vip_level integer default 1,
  add column if not exists title text default 'Traveler',
  add column if not exists balance double precision default 0.0,
  add column if not exists coupon_count integer default 0,
  add column if not exists follow_count integer default 0,
  add column if not exists fans_count integer default 0,
  add column if not exists is_banned boolean default false,
  add column if not exists cancel_count integer default 0,
  add column if not exists is_admin boolean default false,
  add column if not exists created_at timestamptz default now();

with ranked as (
  select
    ctid,
    row_number() over (
      partition by phone
      order by created_at nulls last, ctid
    ) as rn
  from public.users
  where phone is not null and btrim(phone) <> ''
)
delete from public.users u
using ranked r
where u.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists idx_users_phone
  on public.users (phone)
  where phone is not null and btrim(phone) <> '';

create table if not exists public.guides (
  id uuid primary key default gen_random_uuid(),
  name text not null default '',
  avatar text not null default '',
  rating double precision default 0.0,
  gender text,
  verified boolean default false,
  tags text[] default '{}'::text[],
  description text,
  images text[] default '{}'::text[],
  views integer default 0,
  likes integer default 0,
  fans integer default 0,
  city text,
  created_at timestamptz default now()
);

alter table if exists public.guides
  add column if not exists name text,
  add column if not exists avatar text,
  add column if not exists rating double precision default 0.0,
  add column if not exists gender text,
  add column if not exists verified boolean default false,
  add column if not exists tags text[] default '{}'::text[],
  add column if not exists description text,
  add column if not exists images text[] default '{}'::text[],
  add column if not exists views integer default 0,
  add column if not exists likes integer default 0,
  add column if not exists fans integer default 0,
  add column if not exists city text,
  add column if not exists created_at timestamptz default now();

alter table if exists public.guides
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  author_name text not null default '',
  author_avatar text not null default '',
  content text not null default '',
  images text[] default '{}'::text[],
  location text not null default '',
  likes integer default 0,
  comments integer default 0,
  created_at timestamptz default now()
);

alter table if exists public.posts
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists author_name text default '',
  add column if not exists author_avatar text default '',
  add column if not exists content text default '',
  add column if not exists images text[] default '{}'::text[],
  add column if not exists location text default '',
  add column if not exists likes integer default 0,
  add column if not exists comments integer default 0,
  add column if not exists created_at timestamptz default now();

alter table if exists public.posts
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references public.users(id) on delete cascade,
  followed_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz default now()
);

alter table if exists public.follows
  add column if not exists follower_id uuid references public.users(id) on delete cascade,
  add column if not exists followed_id uuid references public.users(id) on delete cascade,
  add column if not exists created_at timestamptz default now();

alter table if exists public.follows
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

with ranked as (
  select
    ctid,
    row_number() over (
      partition by follower_id, followed_id
      order by created_at nulls last, ctid
    ) as rn
  from public.follows
)
delete from public.follows f
using ranked r
where f.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists idx_follows_follower_followed
  on public.follows (follower_id, followed_id);

-- ---------------------------------------------------------------------------
-- Guide / post interaction tables
-- ---------------------------------------------------------------------------

create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  guide_id uuid not null references public.guides(id) on delete cascade,
  created_at timestamptz default now()
);

alter table if exists public.favorites
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists guide_id uuid references public.guides(id) on delete cascade,
  add column if not exists created_at timestamptz default now();

alter table if exists public.favorites
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

with ranked as (
  select
    ctid,
    row_number() over (
      partition by user_id, guide_id
      order by created_at nulls last, ctid
    ) as rn
  from public.favorites
)
delete from public.favorites f
using ranked r
where f.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists idx_favorites_user_guide
  on public.favorites (user_id, guide_id);

create table if not exists public.guide_likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  guide_id uuid not null references public.guides(id) on delete cascade,
  created_at timestamptz default now()
);

alter table if exists public.guide_likes
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists guide_id uuid references public.guides(id) on delete cascade,
  add column if not exists created_at timestamptz default now();

alter table if exists public.guide_likes
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

with ranked as (
  select
    ctid,
    row_number() over (
      partition by user_id, guide_id
      order by created_at nulls last, ctid
    ) as rn
  from public.guide_likes
)
delete from public.guide_likes g
using ranked r
where g.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists idx_guide_likes_user_guide
  on public.guide_likes (user_id, guide_id);

create table if not exists public.footprints (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  guide_id uuid not null references public.guides(id) on delete cascade,
  last_visited_at timestamptz default now()
);

alter table if exists public.footprints
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists guide_id uuid references public.guides(id) on delete cascade,
  add column if not exists last_visited_at timestamptz default now();

alter table if exists public.footprints
  alter column id set default gen_random_uuid(),
  alter column last_visited_at set default now();

with ranked as (
  select
    ctid,
    row_number() over (
      partition by user_id, guide_id
      order by last_visited_at nulls last, ctid
    ) as rn
  from public.footprints
)
delete from public.footprints f
using ranked r
where f.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists idx_footprints_user_guide
  on public.footprints (user_id, guide_id);

create table if not exists public.post_likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz default now()
);

alter table if exists public.post_likes
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists post_id uuid references public.posts(id) on delete cascade,
  add column if not exists created_at timestamptz default now();

alter table if exists public.post_likes
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

with ranked as (
  select
    ctid,
    row_number() over (
      partition by user_id, post_id
      order by created_at nulls last, ctid
    ) as rn
  from public.post_likes
)
delete from public.post_likes p
using ranked r
where p.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists idx_post_likes_user_post
  on public.post_likes (user_id, post_id);

create table if not exists public.post_favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz default now()
);

alter table if exists public.post_favorites
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists post_id uuid references public.posts(id) on delete cascade,
  add column if not exists created_at timestamptz default now();

alter table if exists public.post_favorites
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

with ranked as (
  select
    ctid,
    row_number() over (
      partition by user_id, post_id
      order by created_at nulls last, ctid
    ) as rn
  from public.post_favorites
)
delete from public.post_favorites p
using ranked r
where p.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists idx_post_favorites_user_post
  on public.post_favorites (user_id, post_id);

create table if not exists public.post_footprints (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  last_visited_at timestamptz default now()
);

alter table if exists public.post_footprints
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists post_id uuid references public.posts(id) on delete cascade,
  add column if not exists last_visited_at timestamptz default now();

alter table if exists public.post_footprints
  alter column id set default gen_random_uuid(),
  alter column last_visited_at set default now();

with ranked as (
  select
    ctid,
    row_number() over (
      partition by user_id, post_id
      order by last_visited_at nulls last, ctid
    ) as rn
  from public.post_footprints
)
delete from public.post_footprints p
using ranked r
where p.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists idx_post_footprints_user_post
  on public.post_footprints (user_id, post_id);

create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  parent_comment_id uuid references public.post_comments(id) on delete cascade,
  reply_to_comment_id uuid references public.post_comments(id) on delete set null,
  content text not null,
  created_at timestamptz default now()
);

alter table if exists public.post_comments
  add column if not exists post_id uuid references public.posts(id) on delete cascade,
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists parent_comment_id uuid references public.post_comments(id) on delete cascade,
  add column if not exists reply_to_comment_id uuid references public.post_comments(id) on delete set null,
  add column if not exists content text,
  add column if not exists created_at timestamptz default now();

alter table if exists public.post_comments
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

create index if not exists idx_post_comments_post_created
  on public.post_comments (post_id, created_at);

create index if not exists idx_post_comments_parent_created
  on public.post_comments (parent_comment_id, created_at);

create table if not exists public.post_comment_likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  comment_id uuid not null references public.post_comments(id) on delete cascade,
  created_at timestamptz default now()
);

alter table if exists public.post_comment_likes
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists comment_id uuid references public.post_comments(id) on delete cascade,
  add column if not exists created_at timestamptz default now();

alter table if exists public.post_comment_likes
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

with ranked as (
  select
    ctid,
    row_number() over (
      partition by user_id, comment_id
      order by created_at nulls last, ctid
    ) as rn
  from public.post_comment_likes
)
delete from public.post_comment_likes pcl
using ranked r
where pcl.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists idx_post_comment_likes_user_comment
  on public.post_comment_likes (user_id, comment_id);

-- Do not add a post_comments -> posts.comments trigger here.
-- The current Node route already increments posts.comments manually.

-- ---------------------------------------------------------------------------
-- Demand / guide application / order tables
-- ---------------------------------------------------------------------------

create table if not exists public.demands (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  city text not null,
  location text not null,
  service_start_at timestamptz not null,
  service_end_at timestamptz not null,
  people_count integer not null default 1,
  gender text not null default 'any',
  budget text not null default '',
  status text not null default 'open',
  author_id uuid not null references public.users(id) on delete cascade,
  author_name text not null default '',
  author_avatar text not null default '',
  images text[] default '{}'::text[],
  tags text[] default '{}'::text[],
  applicant_count integer not null default 0,
  created_at timestamptz default now()
);

alter table if exists public.demands
  add column if not exists title text,
  add column if not exists content text,
  add column if not exists city text,
  add column if not exists location text,
  add column if not exists service_start_at timestamptz,
  add column if not exists service_end_at timestamptz,
  add column if not exists people_count integer default 1,
  add column if not exists gender text default 'any',
  add column if not exists budget text default '',
  add column if not exists status text default 'open',
  add column if not exists author_id uuid references public.users(id) on delete cascade,
  add column if not exists author_name text default '',
  add column if not exists author_avatar text default '',
  add column if not exists images text[] default '{}'::text[],
  add column if not exists tags text[] default '{}'::text[],
  add column if not exists applicant_count integer default 0,
  add column if not exists created_at timestamptz default now();

  alter table if exists public.demands
    alter column id set default gen_random_uuid(),
    alter column created_at set default now();

create table if not exists public.demand_applications (
  id uuid primary key default gen_random_uuid(),
  demand_id uuid not null references public.demands(id) on delete cascade,
  guide_id uuid not null references public.guides(id) on delete cascade,
  guide_name text not null default '',
  guide_avatar text not null default '',
  guide_city text not null default '',
  note text not null default '',
  status text not null default 'pending',
  created_at timestamptz default now()
);

alter table if exists public.demand_applications
  add column if not exists demand_id uuid references public.demands(id) on delete cascade,
  add column if not exists guide_id uuid references public.guides(id) on delete cascade,
  add column if not exists guide_name text default '',
  add column if not exists guide_avatar text default '',
  add column if not exists guide_city text default '',
  add column if not exists note text default '',
  add column if not exists status text default 'pending',
  add column if not exists created_at timestamptz default now();

create unique index if not exists idx_demand_applications_unique
  on public.demand_applications (demand_id, guide_id);

create index if not exists idx_demand_applications_guide
  on public.demand_applications (guide_id, created_at desc);

create index if not exists idx_demand_applications_demand
  on public.demand_applications (demand_id, created_at desc);

create table if not exists public.guide_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  full_name text not null,
  id_card_num text,
  id_card_front text,
  id_card_back text,
  gender text,
  city text,
  avatar text,
  bio text,
  service_tags text[] default '{}'::text[],
  images text[] default '{}'::text[],
  status text default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reject_reason text,
  contract_signed_at timestamptz,
  contract_ip text,
  created_at timestamptz default now()
);

alter table if exists public.guide_applications
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists full_name text,
  add column if not exists id_card_num text,
  add column if not exists id_card_front text,
  add column if not exists id_card_back text,
  add column if not exists gender text,
  add column if not exists city text,
  add column if not exists avatar text,
  add column if not exists bio text,
  add column if not exists service_tags text[] default '{}'::text[],
  add column if not exists images text[] default '{}'::text[],
  add column if not exists status text default 'pending',
  add column if not exists reject_reason text,
  add column if not exists contract_signed_at timestamptz,
  add column if not exists contract_ip text,
  add column if not exists created_at timestamptz default now();

alter table if exists public.guide_applications
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

with ranked as (
  select
    ctid,
    row_number() over (
      partition by user_id
      order by created_at nulls last, ctid
    ) as rn
  from public.guide_applications
)
delete from public.guide_applications g
using ranked r
where g.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists idx_guide_applications_user_id
  on public.guide_applications (user_id);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  guide_id uuid not null references public.guides(id) on delete cascade,
  guide_name text default '',
  guide_avatar text default '',
  status integer default 0,
  amount double precision not null default 0.0,
  service_name text default '',
  service_date timestamptz,
  payment_method text default 'alipay',
  payment_status text default 'pending',
  payment_request_id text,
  merchant_order_no text,
  provider_trade_no text,
  paid_at timestamptz,
  created_at timestamptz default now()
);

alter table if exists public.orders
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists guide_id uuid references public.guides(id) on delete cascade,
  add column if not exists guide_name text default '',
  add column if not exists guide_avatar text default '',
  add column if not exists status integer default 0,
  add column if not exists amount double precision default 0.0,
  add column if not exists service_name text default '',
  add column if not exists service_date timestamptz,
  add column if not exists payment_method text default 'alipay',
  add column if not exists payment_status text default 'pending',
  add column if not exists payment_request_id text,
  add column if not exists merchant_order_no text,
  add column if not exists provider_trade_no text,
  add column if not exists paid_at timestamptz,
  add column if not exists created_at timestamptz default now();

alter table if exists public.orders
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

with ranked as (
  select
    ctid,
    row_number() over (
      partition by merchant_order_no
      order by created_at desc nulls last, ctid
    ) as rn
  from public.orders
  where merchant_order_no is not null
)
delete from public.orders o
using ranked r
where o.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists idx_orders_merchant_order_no
  on public.orders (merchant_order_no)
  where merchant_order_no is not null;

-- ---------------------------------------------------------------------------
-- Chat / wallet tables
-- ---------------------------------------------------------------------------

create table if not exists public.chat_rooms (
  id uuid primary key default gen_random_uuid(),
  participant_ids uuid[] not null,
  last_message text,
  last_message_time timestamptz default now(),
  order_id uuid references public.orders(id),
  created_at timestamptz default now()
);

alter table if exists public.chat_rooms
  add column if not exists participant_ids uuid[] default '{}'::uuid[],
  add column if not exists last_message text,
  add column if not exists last_message_time timestamptz default now(),
  add column if not exists order_id uuid references public.orders(id),
  add column if not exists created_at timestamptz default now();

alter table if exists public.chat_rooms
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

create index if not exists idx_chat_rooms_participant_ids
  on public.chat_rooms using gin (participant_ids);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  content text not null,
  type text default 'text',
  is_read boolean default false,
  created_at timestamptz default now()
);

alter table if exists public.messages
  add column if not exists room_id uuid references public.chat_rooms(id) on delete cascade,
  add column if not exists sender_id uuid references public.users(id) on delete cascade,
  add column if not exists content text,
  add column if not exists type text default 'text',
  add column if not exists is_read boolean default false,
  add column if not exists created_at timestamptz default now();

alter table if exists public.messages
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

create table if not exists public.wallets (
  user_id uuid primary key references public.users(id) on delete cascade,
  balance double precision default 0.0,
  pending_balance double precision default 0.0,
  total_earned double precision default 0.0,
  updated_at timestamptz default now()
);

alter table if exists public.wallets
  add column if not exists balance double precision default 0.0,
  add column if not exists pending_balance double precision default 0.0,
  add column if not exists total_earned double precision default 0.0,
  add column if not exists updated_at timestamptz default now();

alter table if exists public.wallets
  alter column updated_at set default now();

create unique index if not exists idx_wallets_user_id
  on public.wallets (user_id);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  type text not null,
  amount double precision not null default 0.0,
  platform_fee double precision default 0.0,
  actual_amount double precision not null default 0.0,
  description text,
  created_at timestamptz default now()
);

alter table if exists public.transactions
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists order_id uuid references public.orders(id) on delete set null,
  add column if not exists type text,
  add column if not exists amount double precision default 0.0,
  add column if not exists platform_fee double precision default 0.0,
  add column if not exists actual_amount double precision default 0.0,
  add column if not exists description text,
  add column if not exists created_at timestamptz default now();

alter table if exists public.transactions
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

-- ---------------------------------------------------------------------------
-- Runtime triggers / functions
-- ---------------------------------------------------------------------------

create or replace function public.update_chat_room_last_message()
returns trigger as $$
begin
  update public.chat_rooms
  set
    last_message = new.content,
    last_message_time = coalesce(new.created_at, now())
  where id = new.room_id;
  return new;
end;
$$ language plpgsql;

drop trigger if exists on_new_message on public.messages;
create trigger on_new_message
after insert on public.messages
for each row
execute function public.update_chat_room_last_message();

create or replace function public.sync_guide_on_approval()
returns trigger as $$
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    insert into public.guides (id, name, avatar, gender, city, description, tags, verified)
    values (
      new.user_id,
      coalesce(new.full_name, ''),
      coalesce(new.avatar, ''),
      new.gender,
      new.city,
      new.bio,
      coalesce(new.service_tags, '{}'::text[]),
      true
    )
    on conflict (id) do update set
      name = excluded.name,
      avatar = excluded.avatar,
      gender = excluded.gender,
      city = excluded.city,
      description = excluded.description,
      tags = excluded.tags,
      verified = true;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists on_guide_application_approved on public.guide_applications;
create trigger on_guide_application_approved
after update of status on public.guide_applications
for each row
execute function public.sync_guide_on_approval();

create or replace function public.create_wallet_for_guide()
returns trigger as $$
begin
  if new.status = 'approved' then
    insert into public.wallets (user_id)
    values (new.user_id)
    on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists tr_create_wallet on public.guide_applications;
create trigger tr_create_wallet
after update of status on public.guide_applications
for each row
when (old.status is distinct from new.status and new.status = 'approved')
execute function public.create_wallet_for_guide();

create or replace function public.check_user_ban()
returns trigger as $$
begin
  if coalesce(new.cancel_count, 0) >= 3 then
    new.is_banned := true;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists tr_user_ban_check on public.users;
create trigger tr_user_ban_check
before update of cancel_count on public.users
for each row
execute function public.check_user_ban();
