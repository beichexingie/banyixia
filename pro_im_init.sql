-- [IM 实时沟通系统初始化]
-- 1. 创建会话表
CREATE TABLE IF NOT EXISTS public.chat_rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    participant_ids UUID[] NOT NULL, -- 参与者ID数组 [user_id, guide_id]
    last_message TEXT,
    last_message_time TIMESTAMPTZ DEFAULT now(),
    order_id UUID REFERENCES public.orders(id), -- 可选：关联订单
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. 创建消息表
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id),
    content TEXT NOT NULL,
    type TEXT DEFAULT 'text', -- text, image, order_card
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. 启用 RLS
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- 4. RLS 策略：仅参与者可访问
CREATE POLICY "Users can view their own chat rooms"
ON public.chat_rooms FOR SELECT
USING (auth.uid() = ANY(participant_ids));

CREATE POLICY "Users can insert chat rooms"
ON public.chat_rooms FOR INSERT
WITH CHECK (auth.uid() = ANY(participant_ids));

CREATE POLICY "Users can view messages in their rooms"
ON public.messages FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.chat_rooms
        WHERE id = messages.room_id
        AND auth.uid() = ANY(participant_ids)
    )
);

CREATE POLICY "Users can insert messages in their rooms"
ON public.messages FOR INSERT
WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
        SELECT 1 FROM public.chat_rooms
        WHERE id = messages.room_id
        AND auth.uid() = ANY(participant_ids)
    )
);

-- 5. 自动更新会话最后消息的触发器
CREATE OR REPLACE FUNCTION update_chat_room_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.chat_rooms
    SET last_message = NEW.content,
        last_message_time = NEW.created_at
    WHERE id = NEW.room_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_new_message
    AFTER INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_room_last_message();

-- 6. 开启 Realtime (重要：需在 Supabase 后台或此处通过 SQL 开启)
-- 注意：如果是在线版本，建议在 dashboard 设置中开启 messages 表的 Realtime 
-- 或者执行：
-- ALTER PUBLICATION supabase_realtime ADD TABLE messages;
