create extension if not exists pgcrypto;

create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  body text not null default '',
  route text not null default '',
  notification_type text not null default 'general',
  order_id uuid references public.orders(id) on delete set null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_app_notifications_user_created
  on public.app_notifications (user_id, created_at desc);
