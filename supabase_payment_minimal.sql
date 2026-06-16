alter table if exists public.orders
  add column if not exists payment_method text,
  add column if not exists payment_status text default 'pending',
  add column if not exists payment_request_id text,
  add column if not exists merchant_order_no text,
  add column if not exists provider_trade_no text,
  add column if not exists paid_at timestamptz;

create unique index if not exists idx_orders_merchant_order_no
  on public.orders (merchant_order_no)
  where merchant_order_no is not null;
