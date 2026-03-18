-- 1. 增强地陪申请表 (增加合规字段)
ALTER TABLE public.guide_applications 
ADD COLUMN IF NOT EXISTS id_card_front TEXT,
ADD COLUMN IF NOT EXISTS id_card_back TEXT,
ADD COLUMN IF NOT EXISTS contract_signed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS contract_ip TEXT;

-- 2. 钱包系统
CREATE TABLE IF NOT EXISTS public.wallets (
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE PRIMARY KEY,
  balance DECIMAL(12, 2) DEFAULT 0.00,
  pending_balance DECIMAL(12, 2) DEFAULT 0.00, -- 托管中
  total_earned DECIMAL(12, 2) DEFAULT 0.00,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 为每个新通过的导游自动创建钱包
CREATE OR REPLACE FUNCTION public.create_wallet_for_guide()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'approved' THEN
    INSERT INTO public.wallets (user_id) 
    VALUES (NEW.user_id)
    ON CONFLICT (user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_create_wallet ON public.guide_applications;
CREATE TRIGGER tr_create_wallet
  AFTER UPDATE OF status ON public.guide_applications
  FOR EACH ROW WHEN (OLD.status <> 'approved' AND NEW.status = 'approved')
  EXECUTE FUNCTION public.create_wallet_for_guide();

-- 3. 收支明细表
CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  order_id UUID REFERENCES public.orders(id),
  type TEXT NOT NULL, -- 'income', 'withdrawal', 'refund'
  amount DECIMAL(12, 2) NOT NULL,
  platform_fee DECIMAL(12, 2) DEFAULT 0.00,
  actual_amount DECIMAL(12, 2) NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. 开启 RLS
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;
CREATE POLICY "Users can view own wallet" ON public.wallets FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
CREATE POLICY "Users can view own transactions" ON public.transactions FOR SELECT USING (auth.uid() = user_id);
-- 增加冻结余额
CREATE OR REPLACE FUNCTION public.increment_pending_balance(target_user_id UUID, amount DECIMAL)
RETURNS VOID AS $$
BEGIN
  UPDATE public.wallets 
  SET pending_balance = pending_balance + amount, updated_at = NOW()
  WHERE user_id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 解冻并转入可用余额
CREATE OR REPLACE FUNCTION public.unfreeze_and_credit_balance(target_user_id UUID, escrow_amount DECIMAL, credit_amount DECIMAL)
RETURNS VOID AS $$
BEGIN
  UPDATE public.wallets 
  SET 
    pending_balance = pending_balance - escrow_amount,
    balance = balance + credit_amount,
    total_earned = total_earned + credit_amount,
    updated_at = NOW()
  WHERE user_id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
