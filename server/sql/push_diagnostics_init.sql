-- Push delivery diagnostics. Device tokens are not stored in full here.

create table if not exists public.push_delivery_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  device_prefixes text[] not null default '{}',
  app_variant text not null default 'customer',
  app_key bigint not null default 0,
  notification_type text not null default 'general',
  status text not null default 'accepted',
  message_id text,
  request_id text,
  error_code text,
  error_message text,
  response_json jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_push_delivery_logs_created
  on public.push_delivery_logs (created_at desc);

create index if not exists idx_push_delivery_logs_user
  on public.push_delivery_logs (user_id, created_at desc);
