create extension if not exists pgcrypto;

create table if not exists public.guide_bank_payout_accounts (
  user_id uuid primary key references public.users(id) on delete cascade,
  provider text not null default 'wechat_bank_card',
  provider_account_token text not null,
  bank_name text not null default '',
  account_last4 char(4) not null,
  real_name text not null default '',
  status text not null default 'pending',
  reject_reason text,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_guide_bank_payout_accounts_status
  on public.guide_bank_payout_accounts (status, updated_at desc);

create index if not exists idx_withdrawal_requests_provider_status
  on public.withdrawal_requests (provider, status, created_at desc);

comment on table public.guide_bank_payout_accounts is
  'Only stores the payout provider token and last four digits; never store a raw bank-card number.';

comment on column public.withdrawal_requests.provider is
  'alipay=支付宝转账, wechat_bank_card=微信商家转账到银行卡, manual=人工线下打款';
