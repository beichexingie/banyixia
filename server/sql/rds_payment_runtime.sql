create extension if not exists pgcrypto;

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

create table if not exists public.wallets (
  user_id uuid primary key references public.users(id) on delete cascade,
  balance numeric(12, 2) default 0.00,
  pending_balance numeric(12, 2) default 0.00,
  total_earned numeric(12, 2) default 0.00,
  updated_at timestamptz default now()
);

create table if not exists public.transactions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  order_id uuid references public.orders(id),
  type text not null,
  amount numeric(12, 2) not null,
  platform_fee numeric(12, 2) default 0.00,
  actual_amount numeric(12, 2) not null,
  description text,
  created_at timestamptz default now()
);

alter table if exists public.chat_rooms
  add column if not exists last_message text,
  add column if not exists last_message_time timestamptz default now();

create or replace function public.update_chat_room_last_message()
returns trigger as $$
begin
  update public.chat_rooms
  set
    last_message = new.content,
    last_message_time = new.created_at
  where id = new.room_id;
  return new;
end;
$$ language plpgsql;

drop trigger if exists on_new_message on public.messages;
create trigger on_new_message
after insert on public.messages
for each row
execute function public.update_chat_room_last_message();
