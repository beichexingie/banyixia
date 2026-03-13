-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.
-- Table order and constraints may not be valid for execution.

DROP TABLE IF EXISTS public.post_favorites CASCADE;
DROP TABLE IF EXISTS public.favorites CASCADE;
CREATE TABLE public.favorites (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  guide_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT favorites_pkey PRIMARY KEY (id),
  CONSTRAINT favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT favorites_guide_id_fkey FOREIGN KEY (guide_id) REFERENCES public.guides(id)
);

DROP TABLE IF EXISTS public.footprints CASCADE;
CREATE TABLE public.footprints (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  guide_id uuid NOT NULL,
  last_visited_at timestamp with time zone DEFAULT now(),
  CONSTRAINT footprints_pkey PRIMARY KEY (id),
  CONSTRAINT footprints_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT footprints_guide_id_fkey FOREIGN KEY (guide_id) REFERENCES public.guides(id)
);

DROP TABLE IF EXISTS public.guide_likes CASCADE;
CREATE TABLE public.guide_likes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  guide_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT guide_likes_pkey PRIMARY KEY (id),
  CONSTRAINT guide_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT guide_likes_guide_id_fkey FOREIGN KEY (guide_id) REFERENCES public.guides(id)
);

DROP TABLE IF EXISTS public.guides CASCADE;
CREATE TABLE public.guides (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  avatar text NOT NULL,
  rating double precision DEFAULT 0.0,
  gender text,
  verified boolean DEFAULT false,
  tags text[] DEFAULT '{}'::text[],
  description text,
  images text[] DEFAULT '{}'::text[],
  views integer DEFAULT 0,
  likes integer DEFAULT 0,
  fans integer DEFAULT 0,
  city text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT guides_pkey PRIMARY KEY (id)
);

DROP TABLE IF EXISTS public.posts CASCADE;
CREATE TABLE public.posts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  author_name text NOT NULL,
  author_avatar text NOT NULL,
  content text NOT NULL,
  images text[] DEFAULT '{}'::text[],
  location text NOT NULL,
  likes integer DEFAULT 0,
  comments integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT posts_pkey PRIMARY KEY (id),
  CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

DROP TABLE IF EXISTS public.users CASCADE;
CREATE TABLE public.users (
  id uuid NOT NULL,
  nickname text,
  avatar text,
  vip_level integer DEFAULT 1,
  title text DEFAULT '初级旅行家'::text,
  balance double precision DEFAULT 0.0,
  coupon_count integer DEFAULT 0,
  follow_count integer DEFAULT 0,
  fans_count integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);

-- DROP TABLE IF EXISTS public.post_favorites CASCADE; is already at the top to avoid relation constraint failures
CREATE TABLE public.post_favorites (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  post_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT post_favorites_pkey PRIMARY KEY (id),
  CONSTRAINT post_favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT post_favorites_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE,
  UNIQUE(user_id, post_id)
);