-- 1. 创建订单表 (如果不存在)
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  guide_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL, -- 关联到用户表的导游ID
  guide_name TEXT,
  guide_avatar TEXT,
  status INTEGER DEFAULT 0, -- 对应 OrderStatus 枚举
  amount DECIMAL(12, 2) NOT NULL,
  service_name TEXT,
  service_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 增强用户表 (增加风险管理字段)
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS cancel_count INTEGER DEFAULT 0;

-- 3. 开启 RLS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
CREATE POLICY "Users can view own orders" ON public.orders 
FOR SELECT USING (auth.uid() = user_id OR auth.uid() = guide_id);

DROP POLICY IF EXISTS "Users can insert orders" ON public.orders;
CREATE POLICY "Users can insert orders" ON public.orders 
FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 4. 自动封禁触发器 (如果取消次数 >= 3)
CREATE OR REPLACE FUNCTION public.check_user_ban()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.cancel_count >= 3 THEN
    NEW.is_banned := true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_user_ban_check ON public.users;
CREATE TRIGGER tr_user_ban_check
  BEFORE UPDATE OF cancel_count ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.check_user_ban();
