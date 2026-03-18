-- 创建地陪申请表
CREATE TABLE IF NOT EXISTS public.guide_applications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  full_name TEXT NOT NULL,
  id_card_num TEXT, -- 实际开发中需加密存储
  gender TEXT,
  city TEXT,
  avatar TEXT,
  bio TEXT,
  service_tags TEXT[], -- 技能标签
  images TEXT[], -- 资质照片
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reject_reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 开启 RLS
ALTER TABLE public.guide_applications ENABLE ROW LEVEL SECURITY;

-- 策略：用户可以查看和创建自己的申请
DROP POLICY IF EXISTS "Users can view own applications" ON public.guide_applications;
CREATE POLICY "Users can view own applications" ON public.guide_applications
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own applications" ON public.guide_applications;
CREATE POLICY "Users can create own applications" ON public.guide_applications
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 策略：管理员可以查看所有和评价（这里先简单模拟，后续可加管理员角色判断）
DROP POLICY IF EXISTS "Admins can view all applications" ON public.guide_applications;
CREATE POLICY "Admins can view all applications" ON public.guide_applications
  FOR ALL USING (true); -- 演示环境下暂开，生产环境需 auth.uid() 角色判断
