-- Customer service runtime patch.
-- This file is intentionally focused so it can be applied without rerunning
-- the full historical database patch.

create extension if not exists pgcrypto;

create table if not exists public.chat_rooms (
  id uuid primary key default gen_random_uuid(),
  participant_ids uuid[] not null,
  last_message text,
  last_message_time timestamptz default now(),
  order_id uuid references public.orders(id) on delete set null,
  created_at timestamptz default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  sender_id uuid references public.users(id) on delete cascade,
  content text not null,
  type text not null default 'text',
  is_read boolean not null default false,
  created_at timestamptz default now()
);

alter table if exists public.messages
  alter column sender_id drop not null;

create index if not exists idx_messages_room_created
  on public.messages (room_id, created_at);

create table if not exists public.customer_service_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  title text not null default '在线客服',
  status text not null default 'open',
  priority text not null default 'normal',
  assigned_to uuid references public.users(id) on delete set null,
  auto_reply_enabled boolean not null default true,
  human_takeover boolean not null default false,
  last_message text,
  last_message_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  constraint customer_service_tickets_status_check
    check (status in ('open', 'pending', 'closed')),
  constraint customer_service_tickets_priority_check
    check (priority in ('low', 'normal', 'high'))
);

alter table if exists public.customer_service_tickets
  add column if not exists auto_reply_enabled boolean not null default true,
  add column if not exists human_takeover boolean not null default false;

create index if not exists idx_customer_service_tickets_user_updated
  on public.customer_service_tickets (user_id, updated_at desc);

create index if not exists idx_customer_service_tickets_status_updated
  on public.customer_service_tickets (status, updated_at desc);

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
