-- 创建帖子评论表
CREATE TABLE IF NOT EXISTS public.post_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 设置安全策略 (RLS)
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Comments are viewable by everyone." ON public.post_comments;
CREATE POLICY "Comments are viewable by everyone." ON public.post_comments 
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own comments." ON public.post_comments;
CREATE POLICY "Users can insert their own comments." ON public.post_comments 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own comments." ON public.post_comments;
CREATE POLICY "Users can delete their own comments." ON public.post_comments 
  FOR DELETE USING (auth.uid() = user_id);

-- 更新帖子表以支持评论数统计
-- 自动触发器：当有新评论或评论被删除时，自动更新 posts 表的 comments 计数
CREATE OR REPLACE FUNCTION public.handle_post_comment_count() 
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE public.posts SET comments = comments + 1 WHERE id = NEW.post_id;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE public.posts SET comments = comments - 1 WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_post_comment_added ON public.post_comments;
CREATE TRIGGER on_post_comment_added
  AFTER INSERT OR DELETE ON public.post_comments
  FOR EACH ROW EXECUTE FUNCTION public.handle_post_comment_count();
