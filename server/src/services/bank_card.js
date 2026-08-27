import { config, hasAlipayConfig, hasWechatConfig } from '../config.js';

let bankPayoutSchemaPromise;

export function ensureBankPayoutSchema(pool) {
  if (!bankPayoutSchemaPromise) {
    bankPayoutSchemaPromise = pool.query(`
      create extension if not exists pgcrypto;
      create table if not exists public.guide_bank_payout_accounts (
        user_id uuid primary key references public.users(id) on delete cascade,
        provider text not null default 'wechat_bank_card',
        provider_account_token text not null,
        bank_name text not null default '',
        account_last4 char(4) not null,
        real_name text not null default '',
        status text not null default 'pending',
        reject_reason text,
        verified_at timestamptz,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now()
      );
      create index if not exists idx_guide_bank_payout_accounts_status
        on public.guide_bank_payout_accounts (status, updated_at desc);
    `).catch((error) => {
      bankPayoutSchemaPromise = null;
      throw error;
    });
  }
  return bankPayoutSchemaPromise;
}

export function bankPaymentCapabilities() {
  return {
    alipay: hasAlipayConfig(),
    wechat: hasWechatConfig(),
    bank_card: {
      enabled: config.bankCardPaymentEnabled,
      provider: config.bankCardPaymentProvider || null,
      message: config.bankCardPaymentEnabled
        ? '银行卡收单机构已配置，等待对应适配器接入'
        : '银行卡支付需要先接入银联、网联或持牌收单机构',
    },
    wechat_bank_transfer: {
      enabled: config.wechatBankTransferEnabled,
      message: config.wechatBankTransferEnabled
        ? '微信商家转账到银行卡已配置'
        : '微信商家转账到银行卡尚未开通',
    },
  };
}

export function createBankCardPaymentOrder() {
  const error = new Error(
    config.bankCardPaymentEnabled
      ? '银行卡收单适配器尚未配置，请先确定银联/网联服务商'
      : '银行卡支付尚未开通，请先接入银联、网联或持牌收单机构',
  );
  error.statusCode = 501;
  throw error;
}

export function assertWechatBankTransferEnabled() {
  if (!config.wechatBankTransferEnabled) {
    const error = new Error('微信商家转账到银行卡尚未开通');
    error.statusCode = 501;
    throw error;
  }
}

export function submitWechatBankTransfer() {
  const error = new Error(
    '微信银行卡代付适配器尚未接入。请先开通微信商家转账到银行卡并提供对应 API 规格',
  );
  error.statusCode = 501;
  throw error;
}
