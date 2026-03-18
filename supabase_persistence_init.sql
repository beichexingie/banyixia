-- 1. 创建地陪向导表
CREATE TABLE IF NOT EXISTS public.guides (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  avatar TEXT NOT NULL,
  rating FLOAT DEFAULT 0.0,
  gender TEXT,
  verified BOOLEAN DEFAULT false,
  tags TEXT[] DEFAULT '{}',
  description TEXT,
  images TEXT[] DEFAULT '{}',
  views INTEGER DEFAULT 0,
  likes INTEGER DEFAULT 0,
  fans INTEGER DEFAULT 0,
  city TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 创建收藏表 (Favorites)
CREATE TABLE IF NOT EXISTS public.favorites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  guide_id UUID REFERENCES public.guides(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, guide_id)
);

-- 3. 创建地陪点赞表 (Guide Likes)
CREATE TABLE IF NOT EXISTS public.guide_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  guide_id UUID REFERENCES public.guides(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, guide_id)
);

-- 4. 创建足迹表 (Footprints)
CREATE TABLE IF NOT EXISTS public.footprints (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  guide_id UUID REFERENCES public.guides(id) ON DELETE CASCADE NOT NULL,
  last_visited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, guide_id)
);

-- 设置安全策略 (RLS)
ALTER TABLE public.guides ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Guides are viewable by everyone." ON public.guides;
CREATE POLICY "Guides are viewable by everyone." ON public.guides FOR SELECT USING (true);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own favorites." ON public.favorites;
CREATE POLICY "Users can manage their own favorites." ON public.favorites FOR ALL USING (auth.uid() = user_id);

ALTER TABLE public.guide_likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own guide likes." ON public.guide_likes;
CREATE POLICY "Users can manage their own guide likes." ON public.guide_likes FOR ALL USING (auth.uid() = user_id);

ALTER TABLE public.footprints ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own footprints." ON public.footprints;
CREATE POLICY "Users can view their own footprints." ON public.footprints FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update their own footprints." ON public.footprints;
CREATE POLICY "Users can update their own footprints." ON public.footprints FOR ALL USING (auth.uid() = user_id);

-- 插入初始地陪数据 (可选)
INSERT INTO public.guides (name, avatar, rating, gender, verified, tags, description, images, views, likes, fans, city)
VALUES 
('小树', 'https://picsum.photos/seed/guide1/100/100', 4.9, '男', true, ARRAY['今天来过'], '本人02年在京工作，偏i但e性格细腻温柔，共情能力强，可以跟我吐槽您的烦恼哦~', ARRAY['https://picsum.photos/seed/g1img1/200/200'], 902, 1123, 652, '北京'),
('Allysa艾丽莎', 'https://picsum.photos/seed/guide2/100/100', 4.8, '女', true, ARRAY['今天来过'], '帮助提前规划路线，专车接送，安排拍照打卡，帮忙排队，讲解景点详情，各色建筑…', ARRAY['https://picsum.photos/seed/g2img1/200/200'], 1022, 1523, 863, '苏州'),
('小王', 'https://picsum.photos/seed/guide3/100/100', 4.7, '男', false, ARRAY['今天来过'], '北京本地通，带你走遍大街小巷。', ARRAY[]::TEXT[], 500, 800, 300, '北京');

-- ============================================
-- 5. 帖子点赞表 (Post Likes) - 记录每个用户的点赞状态
-- ============================================
CREATE TABLE IF NOT EXISTS public.post_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, post_id)
);

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own post likes." ON public.post_likes;
CREATE POLICY "Users can manage their own post likes." ON public.post_likes FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- 6. 帖子收藏表 RLS 策略 (post_favorites 表已存在于 supabase_init.sql)
-- ============================================
ALTER TABLE public.post_favorites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own post favorites." ON public.post_favorites;
CREATE POLICY "Users can manage their own post favorites." ON public.post_favorites FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- 7. 帖子足迹表 (Post Footprints) - 记录浏览历史
-- ============================================
CREATE TABLE IF NOT EXISTS public.post_footprints (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  last_visited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, post_id)
);

ALTER TABLE public.post_footprints ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own post footprints." ON public.post_footprints;
CREATE POLICY "Users can manage their own post footprints." ON public.post_footprints FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- 8. 地陪申请表 (Guide Applications)
-- ============================================
CREATE TABLE IF NOT EXISTS public.guide_applications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  full_name TEXT NOT NULL,
  gender TEXT,
  city TEXT,
  bio TEXT,
  service_tags TEXT[] DEFAULT '{}',
  avatar TEXT,
  status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
  reject_reason TEXT,
  contract_signed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id)
);

ALTER TABLE public.guide_applications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own applications." ON public.guide_applications;
CREATE POLICY "Users can manage their own applications." ON public.guide_applications FOR ALL USING (auth.uid() = user_id);

-- 自动同步审核通过的数据到 guides 表
CREATE OR REPLACE FUNCTION public.sync_guide_on_approval() 
RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved')) THEN
    INSERT INTO public.guides (id, name, avatar, gender, city, description, tags, verified)
    VALUES (NEW.user_id, NEW.full_name, NEW.avatar, NEW.gender, NEW.city, NEW.bio, NEW.service_tags, true)
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      avatar = EXCLUDED.avatar,
      gender = EXCLUDED.gender,
      city = EXCLUDED.city,
      description = EXCLUDED.description,
      tags = EXCLUDED.tags,
      verified = true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_guide_application_approved ON public.guide_applications;
CREATE TRIGGER on_guide_application_approved
  AFTER UPDATE ON public.guide_applications
  FOR EACH ROW
  EXECUTE FUNCTION sync_guide_on_approval();
-- ============================================
-- 9. 关注表 (Follows)
-- ============================================
CREATE TABLE IF NOT EXISTS public.follows (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  follower_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  followed_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(follower_id, followed_id)
);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own follows." ON public.follows;
CREATE POLICY "Users can manage their own follows." ON public.follows FOR ALL USING (auth.uid() = follower_id);

-- 允许查看他人的被关注情况（用于统计粉丝数等）
DROP POLICY IF EXISTS "Follows are viewable by everyone." ON public.follows;
CREATE POLICY "Follows are viewable by everyone." ON public.follows FOR SELECT USING (true);

-- ============================================
-- 10. 用户表 (Users) RLS 策略补全
-- ============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 允许所有人查看基本资料（用于显示帖子作者名等）
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.users;
CREATE POLICY "Public profiles are viewable by everyone." ON public.users FOR SELECT USING (true);

-- 允许用户更新自己的资料
DROP POLICY IF EXISTS "Users can update own profile." ON public.users;
CREATE POLICY "Users can update own profile." ON public.users FOR UPDATE USING (auth.uid() = id);
