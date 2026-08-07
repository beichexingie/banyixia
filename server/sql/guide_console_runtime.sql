-- Persistent data for the separate guide-side application.
-- This is an additive migration: it does not delete or rebuild existing tables.

create table if not exists public.guide_settings (
  user_id uuid primary key references public.users(id) on delete cascade,
  online boolean not null default false,
  duty_mode text not null default 'nearby',
  city text not null default '',
  nearby_only boolean not null default true,
  auxiliary jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.guide_service_items (
  id uuid primary key default gen_random_uuid(),
  guide_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  description text not null default '',
  price_per_hour numeric(12,2) not null default 0,
  price_per_day numeric(12,2) not null default 0,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_guide_service_items_guide
  on public.guide_service_items (guide_id, enabled, updated_at desc);

create table if not exists public.guide_availability (
  id uuid primary key default gen_random_uuid(),
  guide_id uuid not null references public.users(id) on delete cascade,
  service_date date not null,
  start_time time not null,
  end_time time not null,
  note text not null default '',
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint guide_availability_time_check check (end_time > start_time)
);
create index if not exists idx_guide_availability_guide_date
  on public.guide_availability (guide_id, service_date, start_time);

create table if not exists public.guide_reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  guide_id uuid not null references public.users(id) on delete cascade,
  customer_id uuid not null references public.users(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  content text not null default '',
  is_anonymous boolean not null default true,
  guide_reply text,
  replied_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_guide_reviews_guide_created
  on public.guide_reviews (guide_id, created_at desc);

create table if not exists public.guide_task_progress (
  guide_id uuid not null references public.users(id) on delete cascade,
  task_key text not null,
  progress integer not null default 0,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (guide_id, task_key)
);

create table if not exists public.guide_training_courses (
  id text primary key,
  title text not null,
  summary text not null default '',
  content text not null default '',
  required boolean not null default false,
  sort_order integer not null default 0,
  published boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.guide_training_progress (
  guide_id uuid not null references public.users(id) on delete cascade,
  course_id text not null references public.guide_training_courses(id) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (guide_id, course_id)
);

insert into public.guide_training_courses (id, title, summary, content, required, sort_order)
values
  ('service-standard', '服务标准与边界', '确认服务范围、价格和取消规则', '接单前必须通过聊天确认服务时间、地点、人数、价格和包含内容。服务中不得擅自增加收费，不得索取与履约无关的隐私信息。', true, 1),
  ('order-flow', '订单全流程', '从接单、付款到完单的操作说明', '只有在确认需求后接单；用户付款后再开始服务；到达后通过订单标记到达；服务结束由双方确认，平台再按规则结算。', true, 2),
  ('safety-response', '安全与投诉处理', '突发情况和纠纷的处理方式', '遇到人身安全、医疗或财产风险时先联系紧急联系人和当地急救服务，再在订单内联系平台客服并保留证据。', true, 3),
  ('content-compliance', '内容与沟通规范', '消息、图片和个人资料的合规要求', '不得发布违法、骚扰、歧视、虚假营销或引导线下绕过平台交易的内容。疑似违规内容会进入人工审核。', false, 4)
on conflict (id) do update set
  title = excluded.title,
  summary = excluded.summary,
  content = excluded.content,
  required = excluded.required,
  sort_order = excluded.sort_order,
  published = excluded.published,
  updated_at = now();

create table if not exists public.guide_blocked_users (
  guide_id uuid not null references public.users(id) on delete cascade,
  blocked_user_id uuid not null references public.users(id) on delete cascade,
  reason text not null default '',
  created_at timestamptz not null default now(),
  primary key (guide_id, blocked_user_id),
  constraint guide_blocked_self_check check (guide_id <> blocked_user_id)
);

create table if not exists public.guide_insurance_policies (
  guide_id uuid primary key references public.users(id) on delete cascade,
  provider text not null default '',
  policy_no text not null default '',
  expires_at date,
  document_url text not null default '',
  status text not null default 'unsubmitted',
  reject_reason text,
  updated_at timestamptz not null default now()
);

create table if not exists public.guide_support_requests (
  id uuid primary key default gen_random_uuid(),
  guide_id uuid not null references public.users(id) on delete cascade,
  category text not null default '运营咨询',
  content text not null,
  status text not null default 'open',
  reply text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_guide_support_requests_guide
  on public.guide_support_requests (guide_id, created_at desc);

-- The client-side feedback entry point writes to this table through the API.
-- The guide side only receives anonymised customer information.
