-- 最小必要补丁
-- 1. 你现在代码里会直接用到，但截图里没有看到的 demands 表
-- 2. 订单、消息、申请、结算相关的最小 RLS
-- 3. 保持现有表不动，只补缺口

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

CREATE TABLE IF NOT EXISTS public.demands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  city TEXT NOT NULL,
  location TEXT NOT NULL,
  service_start_at TIMESTAMPTZ NOT NULL,
  service_end_at TIMESTAMPTZ NOT NULL,
  people_count INTEGER NOT NULL DEFAULT 1,
  gender TEXT NOT NULL DEFAULT '不限',
  budget TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'open',
  author_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  author_name TEXT NOT NULL,
  author_avatar TEXT NOT NULL DEFAULT '',
  images TEXT[] DEFAULT '{}'::TEXT[],
  tags TEXT[] DEFAULT '{}'::TEXT[],
  applicant_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.demands ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Demands are viewable by everyone" ON public.demands;
CREATE POLICY "Demands are viewable by everyone"
ON public.demands FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Users can create own demands" ON public.demands;
CREATE POLICY "Users can create own demands"
ON public.demands FOR INSERT
WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "Users can update own demands" ON public.demands;
CREATE POLICY "Users can update own demands"
ON public.demands FOR UPDATE
USING (auth.uid() = author_id)
WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "Users can delete own demands" ON public.demands;
CREATE POLICY "Users can delete own demands"
ON public.demands FOR DELETE
USING (auth.uid() = author_id);

DROP POLICY IF EXISTS "Guide can view own applications" ON public.guide_applications;
CREATE POLICY "Guide can view own applications"
ON public.guide_applications FOR SELECT
USING (auth.uid() = user_id OR EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id = auth.uid() AND COALESCE(u.is_admin, false)
));

DROP POLICY IF EXISTS "Guide can create own applications" ON public.guide_applications;
CREATE POLICY "Guide can create own applications"
ON public.guide_applications FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin can manage applications" ON public.guide_applications;
CREATE POLICY "Admin can manage applications"
ON public.guide_applications FOR UPDATE
USING (EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id = auth.uid() AND COALESCE(u.is_admin, false)
))
WITH CHECK (EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id = auth.uid() AND COALESCE(u.is_admin, false)
));

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Orders are viewable by participants" ON public.orders;
CREATE POLICY "Orders are viewable by participants"
ON public.orders FOR SELECT
USING (auth.uid() = user_id OR auth.uid() = guide_id);

DROP POLICY IF EXISTS "Users can create own orders" ON public.orders;
CREATE POLICY "Users can create own orders"
ON public.orders FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Participants can update orders" ON public.orders;
CREATE POLICY "Participants can update orders"
ON public.orders FOR UPDATE
USING (auth.uid() = user_id OR auth.uid() = guide_id)
WITH CHECK (auth.uid() = user_id OR auth.uid() = guide_id);

ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own chat rooms" ON public.chat_rooms;
CREATE POLICY "Users can view their own chat rooms"
ON public.chat_rooms FOR SELECT
USING (auth.uid() = ANY(participant_ids));

DROP POLICY IF EXISTS "Users can insert chat rooms" ON public.chat_rooms;
CREATE POLICY "Users can insert chat rooms"
ON public.chat_rooms FOR INSERT
WITH CHECK (auth.uid() = ANY(participant_ids));

DROP POLICY IF EXISTS "Users can view messages in their rooms" ON public.messages;
CREATE POLICY "Users can view messages in their rooms"
ON public.messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.chat_rooms r
    WHERE r.id = messages.room_id
      AND auth.uid() = ANY(r.participant_ids)
  )
);

DROP POLICY IF EXISTS "Users can insert messages in their rooms" ON public.messages;
CREATE POLICY "Users can insert messages in their rooms"
ON public.messages FOR INSERT
WITH CHECK (
  auth.uid() = sender_id AND
  EXISTS (
    SELECT 1 FROM public.chat_rooms r
    WHERE r.id = messages.room_id
      AND auth.uid() = ANY(r.participant_ids)
  )
);

DROP POLICY IF EXISTS "Users can update messages in their rooms" ON public.messages;
CREATE POLICY "Users can update messages in their rooms"
ON public.messages FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.chat_rooms r
    WHERE r.id = messages.room_id
      AND auth.uid() = ANY(r.participant_ids)
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.chat_rooms r
    WHERE r.id = messages.room_id
      AND auth.uid() = ANY(r.participant_ids)
  )
);

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
CREATE POLICY "Users can view own transactions"
ON public.transactions FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own transactions" ON public.transactions;
CREATE POLICY "Users can insert own transactions"
ON public.transactions FOR INSERT
WITH CHECK (auth.uid() = user_id);
