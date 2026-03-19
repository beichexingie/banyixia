-- [修复 Supabase Realtime 同步问题]
-- 必须在 Supabase 的 SQL Editor 中执行以下语句：

-- 1. 把 messages 表和 chat_rooms 表公开加入实时发布
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_rooms;

-- 2. 设置表的复制身份为 FULL，这能保证包含过滤条件（如 room_id）的实时变更能被正确广播
ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.chat_rooms REPLICA IDENTITY FULL;

-- 执行完以上语句后，请彻底退出并重启 App 即可。
