ALTER TABLE IF EXISTS public.orders
  DROP CONSTRAINT IF EXISTS orders_guide_id_fkey;

ALTER TABLE IF EXISTS public.orders
  ADD CONSTRAINT orders_guide_id_fkey
  FOREIGN KEY (guide_id) REFERENCES public.guides(id) ON DELETE CASCADE;
