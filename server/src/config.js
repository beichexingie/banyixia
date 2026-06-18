import dotenv from 'dotenv';

dotenv.config();

function requireEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function parseBoolean(value, defaultValue = false) {
  if (value == null || value === '') {
    return defaultValue;
  }
  return ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase());
}

function parseList(value) {
  return (value ?? '')
      .split(',')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
}

export const config = {
  nodeEnv: process.env.NODE_ENV?.trim() || 'development',
  port: Number(process.env.PORT || 3000),
  databaseUrl: requireEnv('DATABASE_URL'),
  databaseSsl: parseBoolean(process.env.DATABASE_SSL, false),
  alipayAppId: process.env.ALIPAY_APP_ID?.trim() || '',
  alipayPrivateKey: process.env.ALIPAY_PRIVATE_KEY?.trim() || '',
  alipayPublicKey: process.env.ALIPAY_PUBLIC_KEY?.trim() || '',
  alipayNotifyUrl: process.env.ALIPAY_NOTIFY_URL?.trim() || '',
  paymentDebugEnabled: parseBoolean(process.env.PAYMENT_DEBUG_ENABLED, false),
  corsOrigins: parseList(process.env.CORS_ORIGINS),
};

export function hasAlipayConfig() {
  return Boolean(
    config.alipayAppId &&
        config.alipayPrivateKey &&
        config.alipayPublicKey &&
        config.alipayNotifyUrl,
  );
}
