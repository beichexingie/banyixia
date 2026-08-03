create extension if not exists pgcrypto;

create table if not exists public.wallets (
  user_id uuid primary key references public.users(id) on delete cascade,
  balance numeric(12, 2) not null default 0.00,
  pending_balance numeric(12, 2) not null default 0.00,
  total_earned numeric(12, 2) not null default 0.00,
  updated_at timestamptz not null default now()
);

alter table if exists public.wallets
  add column if not exists balance numeric(12, 2) not null default 0.00,
  add column if not exists pending_balance numeric(12, 2) not null default 0.00,
  add column if not exists total_earned numeric(12, 2) not null default 0.00,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  order_id uuid references public.orders(id),
  type text not null,
  amount numeric(12, 2) not null,
  platform_fee numeric(12, 2) not null default 0.00,
  actual_amount numeric(12, 2) not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.guide_payout_accounts (
  user_id uuid primary key references public.users(id) on delete cascade,
  alipay_account text,
  alipay_user_id text,
  real_name text not null default '',
  status text not null default 'pending',
  reject_reason text,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.guide_payout_accounts
  add column if not exists alipay_account text,
  add column if not exists alipay_user_id text,
  add column if not exists real_name text not null default '',
  add column if not exists status text not null default 'pending',
  add column if not exists reject_reason text,
  add column if not exists verified_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  amount numeric(12, 2) not null,
  status text not null default 'pending',
  payout_account_snapshot jsonb not null default '{}'::jsonb,
  provider text not null default 'alipay',
  provider_order_no text,
  reject_reason text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  paid_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table if exists public.withdrawal_requests
  add column if not exists payout_account_snapshot jsonb not null default '{}'::jsonb,
  add column if not exists provider text not null default 'alipay',
  add column if not exists provider_order_no text,
  add column if not exists reject_reason text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists reviewed_at timestamptz,
  add column if not exists paid_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists idx_transactions_user_created
  on public.transactions (user_id, created_at desc);

create index if not exists idx_withdrawal_requests_user_created
  on public.withdrawal_requests (user_id, created_at desc);

create index if not exists idx_withdrawal_requests_status_created
  on public.withdrawal_requests (status, created_at desc);
