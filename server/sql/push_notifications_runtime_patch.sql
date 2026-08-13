-- Device token storage for business-triggered Firebase push notifications.

create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  token text not null,
  platform text not null default 'android',
  app_variant text not null default 'customer',
  enabled boolean not null default true,
  last_seen_at timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index if not exists idx_device_push_tokens_token
  on public.device_push_tokens (token);

create index if not exists idx_device_push_tokens_user
  on public.device_push_tokens (user_id, enabled);
