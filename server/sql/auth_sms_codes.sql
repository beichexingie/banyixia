create table if not exists public.auth_sms_codes (
  id bigserial primary key,
  phone text not null,
  purpose text not null default 'login',
  code_hash text not null,
  expires_at timestamptz not null,
  attempts integer not null default 0,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_auth_sms_codes_lookup
  on public.auth_sms_codes (phone, purpose, created_at desc);

create index if not exists idx_auth_sms_codes_cleanup
  on public.auth_sms_codes (expires_at);
