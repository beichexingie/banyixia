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

function parseNumber(value, defaultValue = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : defaultValue;
}

function parseList(value) {
  return (value ?? '')
      .split(',')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
}

function parsePhoneCodeMap(value) {
  return (value ?? '')
      .split(',')
      .map((item) => item.trim())
      .filter((item) => item.length > 0)
      .reduce((accumulator, item) => {
        const [phone, code] = item.split(':').map((part) => part?.trim() ?? '');
        if (phone && code) {
          accumulator[phone] = code;
        }
        return accumulator;
      }, {});
}

function parseKeywordList(value) {
  return (value ?? '')
      .split(/[,，\n\r]+/)
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
}

export const config = {
  nodeEnv: process.env.NODE_ENV?.trim() || 'development',
  port: Number(process.env.PORT || 3000),
  databaseUrl: requireEnv('DATABASE_URL'),
  databaseSsl: parseBoolean(process.env.DATABASE_SSL, false),
  amapWebServiceKey: process.env.AMAP_WEB_SERVICE_KEY?.trim() || '',
  alipayAppId: process.env.ALIPAY_APP_ID?.trim() || '',
  alipayPrivateKey: process.env.ALIPAY_PRIVATE_KEY?.trim() || '',
  alipayPublicKey: process.env.ALIPAY_PUBLIC_KEY?.trim() || '',
  alipayAppCertSn: process.env.ALIPAY_APP_CERT_SN?.trim() || '',
  alipayRootCertSn: process.env.ALIPAY_ROOT_CERT_SN?.trim() || '',
  alipayNotifyUrl: process.env.ALIPAY_NOTIFY_URL?.trim() || '',
  alipayApiBaseUrl:
    process.env.ALIPAY_API_BASE_URL?.trim() ||
    'https://openapi.alipay.com',
  wechatPayEnabled: parseBoolean(process.env.WECHAT_PAY_ENABLED, false),
  wechatAppId: process.env.WECHAT_APP_ID?.trim() || '',
  wechatMchId: process.env.WECHAT_MCH_ID?.trim() || '',
  wechatApiV3Key: process.env.WECHAT_API_V3_KEY?.trim() || '',
  wechatCertSerialNo: process.env.WECHAT_CERT_SERIAL_NO?.trim() || '',
  wechatPlatformCertSerialNo:
    process.env.WECHAT_PLATFORM_CERT_SERIAL_NO?.trim() || '',
  wechatPrivateKeyPath: process.env.WECHAT_PRIVATE_KEY_PATH?.trim() || '',
  wechatPlatformCertPath: process.env.WECHAT_PLATFORM_CERT_PATH?.trim() || '',
  wechatNotifyUrl: process.env.WECHAT_NOTIFY_URL?.trim() || '',
  wechatApiBaseUrl:
    process.env.WECHAT_API_BASE_URL?.trim() ||
    'https://api.mch.weixin.qq.com',
  bankCardPaymentEnabled: parseBoolean(
    process.env.BANK_CARD_PAYMENT_ENABLED,
    false,
  ),
  bankCardPaymentProvider:
    process.env.BANK_CARD_PAYMENT_PROVIDER?.trim() || '',
  wechatBankTransferEnabled: parseBoolean(
    process.env.WECHAT_BANK_TRANSFER_ENABLED,
    false,
  ),
  alipayTransferEnabled: parseBoolean(process.env.ALIPAY_TRANSFER_ENABLED, false),
  alipayTransferMinAmount: parseNumber(
    process.env.ALIPAY_TRANSFER_MIN_AMOUNT,
    0.1,
  ),
  alipayTransferMaxAmount: parseNumber(process.env.ALIPAY_TRANSFER_MAX_AMOUNT, 5000),
  alipayTransferSceneName:
    process.env.ALIPAY_TRANSFER_SCENE_NAME?.trim() || '佣金报酬',
  alipayTransferReportInfoType:
    process.env.ALIPAY_TRANSFER_REPORT_INFO_TYPE?.trim() || '佣金报酬说明',
  alipayTransferReportInfoContent:
    process.env.ALIPAY_TRANSFER_REPORT_INFO_CONTENT?.trim() || '地陪服务报酬',
  paymentDebugEnabled: parseBoolean(process.env.PAYMENT_DEBUG_ENABLED, false),
  corsOrigins: parseList(process.env.CORS_ORIGINS),
  aliyunMobilePushEnabled: parseBoolean(
    process.env.ALIYUN_MOBILE_PUSH_ENABLED,
    false,
  ),
  aliyunMobilePushAccessKeyId:
    process.env.ALIYUN_MOBILE_PUSH_ACCESS_KEY_ID?.trim() ||
    process.env.ALIYUN_ACCESS_KEY_ID?.trim() ||
    '',
  aliyunMobilePushAccessKeySecret:
    process.env.ALIYUN_MOBILE_PUSH_ACCESS_KEY_SECRET?.trim() ||
    process.env.ALIYUN_ACCESS_KEY_SECRET?.trim() ||
    '',
  aliyunMobilePushCustomerAppKey:
    process.env.ALIYUN_MOBILE_PUSH_CUSTOMER_APP_KEY?.trim() || '',
  aliyunMobilePushGuideAppKey:
    process.env.ALIYUN_MOBILE_PUSH_GUIDE_APP_KEY?.trim() || '',
  aliyunMobilePushRegionId:
    process.env.ALIYUN_MOBILE_PUSH_REGION_ID?.trim() || 'cn-hangzhou',
  authWhitelistEnabled: parseBoolean(process.env.AUTH_WHITELIST_ENABLED, false),
  authWhitelist: parsePhoneCodeMap(process.env.AUTH_WHITELIST),
  moderationEnabled: parseBoolean(process.env.MODERATION_ENABLED, true),
  moderationForbiddenWords: parseKeywordList(process.env.MODERATION_FORBIDDEN_WORDS),
  aliyunContentSafetyEnabled: parseBoolean(process.env.ALIYUN_CONTENT_SAFETY_ENABLED, false),
  aliyunContentSafetyFailOpen: parseBoolean(process.env.ALIYUN_CONTENT_SAFETY_FAIL_OPEN, true),
  aliyunGreenEndpoint: process.env.ALIYUN_GREEN_ENDPOINT?.trim() || 'green-cip.cn-shanghai.aliyuncs.com',
  aliyunTextModerationService: process.env.ALIYUN_TEXT_MODERATION_SERVICE?.trim() || 'comment_detection',
  aliyunImageModerationService: process.env.ALIYUN_IMAGE_MODERATION_SERVICE?.trim() || 'baselineCheck_global',
  aliyunContentSafetyAccessKeyId:
    process.env.ALIYUN_CONTENT_SAFETY_ACCESS_KEY_ID?.trim() ||
    process.env.ALIYUN_ACCESS_KEY_ID?.trim() ||
    '',
  aliyunContentSafetyAccessKeySecret:
    process.env.ALIYUN_CONTENT_SAFETY_ACCESS_KEY_SECRET?.trim() ||
    process.env.ALIYUN_ACCESS_KEY_SECRET?.trim() ||
    '',
  aliyunAccessKeyId: process.env.ALIYUN_ACCESS_KEY_ID?.trim() || '',
  aliyunAccessKeySecret: process.env.ALIYUN_ACCESS_KEY_SECRET?.trim() || '',
  aliyunDyplsPoolKey: process.env.ALIYUN_DYPLS_POOL_KEY?.trim() || '',
  aliyunDyplsPhoneNoX: process.env.ALIYUN_DYPLS_PHONE_NO_X?.trim() || '',
  aliyunDyplsProduct: process.env.ALIYUN_DYPLS_PRODUCT?.trim() || 'Dyplsapi',
  aliyunDyplsDomain: process.env.ALIYUN_DYPLS_DOMAIN?.trim() || 'dyplsapi.aliyuncs.com',
  aliyunDyplsRegionId: process.env.ALIYUN_DYPLS_REGION_ID?.trim() || 'cn-hangzhou',
  aliyunSmsEnabled: parseBoolean(process.env.ALIYUN_SMS_ENABLED, false),
  aliyunSmsAccessKeyId:
    process.env.ALIYUN_SMS_ACCESS_KEY_ID?.trim() ||
    process.env.ALIYUN_ACCESS_KEY_ID?.trim() ||
    process.env.ALIBABA_CLOUD_ACCESS_KEY_ID?.trim() ||
    '',
  aliyunSmsAccessKeySecret:
    process.env.ALIYUN_SMS_ACCESS_KEY_SECRET?.trim() ||
    process.env.ALIYUN_ACCESS_KEY_SECRET?.trim() ||
    process.env.ALIBABA_CLOUD_ACCESS_KEY_SECRET?.trim() ||
    '',
  aliyunSmsSignName: process.env.ALIYUN_SMS_SIGN_NAME?.trim() || '',
  aliyunSmsTemplateCode: process.env.ALIYUN_SMS_TEMPLATE_CODE?.trim() || '',
  aliyunSmsRegionId: process.env.ALIYUN_SMS_REGION_ID?.trim() || 'cn-hangzhou',
  aliyunSmsDomain: process.env.ALIYUN_SMS_DOMAIN?.trim() || 'dysmsapi.aliyuncs.com',
  virtualNumberEnabled: parseBoolean(process.env.VIRTUAL_NUMBER_ENABLED, false),
  trtcEnabled: parseBoolean(process.env.TRTC_ENABLED, false),
  trtcSdkAppId: Number(process.env.TRTC_SDK_APP_ID || 0),
  trtcSecretKey: process.env.TRTC_SECRET_KEY?.trim() || '',
  trtcUserSigExpireSeconds: Number(process.env.TRTC_USER_SIG_EXPIRE_SECONDS || 86400),
  trtcRingTimeoutSeconds: Math.max(
    20,
    parseNumber(process.env.TRTC_RING_TIMEOUT_SECONDS, 60),
  ),
  trtcHeartbeatTimeoutSeconds: Math.max(
    30,
    parseNumber(process.env.TRTC_HEARTBEAT_TIMEOUT_SECONDS, 45),
  ),
  serviceTravelFeePerKm: Math.max(
    0,
    parseNumber(process.env.SERVICE_TRAVEL_FEE_PER_KM, 1),
  ),
  serviceRoadDistanceMultiplier: Math.max(
    1,
    parseNumber(process.env.SERVICE_ROAD_DISTANCE_MULTIPLIER, 1.15),
  ),
};

export function hasAlipayConfig() {
  return Boolean(
    config.alipayAppId &&
        config.alipayPrivateKey &&
        config.alipayPublicKey &&
        config.alipayNotifyUrl,
  );
}

export function hasAlipayTransferConfig() {
  return Boolean(
    config.alipayTransferEnabled &&
      hasAlipayConfig() &&
      config.alipayAppCertSn &&
      config.alipayRootCertSn,
  );
}

export function hasWechatConfig() {
  return Boolean(
    config.wechatPayEnabled &&
      config.wechatAppId &&
      config.wechatMchId &&
      config.wechatApiV3Key.length === 32 &&
      config.wechatCertSerialNo &&
      config.wechatPlatformCertSerialNo &&
      config.wechatPrivateKeyPath &&
      config.wechatPlatformCertPath &&
      config.wechatNotifyUrl,
  );
}

export function hasTrtcConfig() {
  return Boolean(
    config.trtcEnabled &&
      config.trtcSdkAppId > 0 &&
      config.trtcSecretKey &&
      config.trtcUserSigExpireSeconds > 0,
  );
}
