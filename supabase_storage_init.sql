-- 1. 创建名为 "post_images" 和 "avatars" 的存储桶
INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('post_images', 'post_images', true),
  ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 2. 设置 post_images 存储桶的安全策略 (RLS)
CREATE POLICY "Post Images Public Access" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'post_images');

CREATE POLICY "Post Images Auth Upload" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'post_images' AND auth.uid() IS NOT NULL);

-- 3. 设置 avatars 存储桶的安全策略 (RLS)
CREATE POLICY "Avatars Public Access" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'avatars');

CREATE POLICY "Avatars Auth Upload" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'avatars' AND auth.uid() IS NOT NULL);

CREATE POLICY "Avatars Auth Update" 
ON storage.objects FOR UPDATE 
WITH CHECK (bucket_id = 'avatars' AND auth.uid() IS NOT NULL);
