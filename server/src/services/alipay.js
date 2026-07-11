import crypto from 'crypto';

import { config, hasAlipayConfig } from '../config.js';

export function formatChinaTimestamp(date = new Date()) {
  const formatter = new Intl.DateTimeFormat('zh-CN', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  });

  const parts = formatter.formatToParts(date);
  const values = {};
  for (const part of parts) {
    if (part.type !== 'literal') {
      values[part.type] = part.value;
    }
  }

  return `${values.year}-${values.month}-${values.day} ${values.hour}:${values.minute}:${values.second}`;
}

function normalizePrivateKey(value) {
  return value.replace(/\\n/g, '\n').trim();
}

function wrapPemBlock(label, body) {
  const normalizedBody = body.replace(/\s+/g, '');
  const wrapped = normalizedBody.match(/.{1,64}/g)?.join('\n') ?? normalizedBody;
  return `-----BEGIN ${label}-----\n${wrapped}\n-----END ${label}-----`;
}

function normalizePrivateKeyCandidates(value) {
  const trimmed = normalizePrivateKey(value);
  if (!trimmed) {
    return [];
  }

  if (trimmed.includes('BEGIN PRIVATE KEY') || trimmed.includes('BEGIN RSA PRIVATE KEY')) {
    return [trimmed];
  }

  return [
    wrapPemBlock('PRIVATE KEY', trimmed),
    wrapPemBlock('RSA PRIVATE KEY', trimmed),
  ];
}

function normalizePublicKey(value) {
  const trimmed = value.replace(/\\n/g, '\n').trim();
  if (trimmed.includes('BEGIN PUBLIC KEY')) {
    return trimmed;
  }

  const body = trimmed.replace(/\s+/g, '');
  const wrapped = body.match(/.{1,64}/g)?.join('\n') ?? body;
  return `-----BEGIN PUBLIC KEY-----\n${wrapped}\n-----END PUBLIC KEY-----`;
}

export function buildMerchantOrderNo(rawOrderNo, fallbackOrderId) {
  const source = (rawOrderNo || fallbackOrderId || '')
      .replace(/[^0-9A-Za-z_]/g, '')
      .slice(0, 64);

  if (!source) {
    throw new Error('商户订单号无效');
  }
  return source;
}

function buildSignContent(params) {
  return Object.keys(params)
      .filter((key) => key !== 'sign' && params[key] !== '')
      .sort()
      .map((key) => `${key}=${params[key]}`)
      .join('&');
}

function signWithRsa2(message) {
  const candidates = normalizePrivateKeyCandidates(config.alipayPrivateKey);
  const errors = [];

  for (const candidate of candidates) {
    try {
      const signer = crypto.createSign('RSA-SHA256');
      signer.update(message, 'utf8');
      signer.end();
      return signer.sign(candidate, 'base64');
    } catch (error) {
      errors.push(error.message);
    }
  }

  throw new Error(
    `ALIPAY_PRIVATE_KEY format is invalid or unsupported: ${errors.join(' | ') || 'empty key'}`,
  );
}

export function buildOrderString({ orderId, merchantOrderNo, amount, subject }) {
  if (!hasAlipayConfig()) {
    throw new Error('支付宝环境变量未配置完整');
  }

  const finalMerchantOrderNo = buildMerchantOrderNo(merchantOrderNo, orderId);
  const bizContent = {
    subject,
    out_trade_no: finalMerchantOrderNo,
    total_amount: Number(amount).toFixed(2),
    timeout_express: '30m',
    product_code: 'QUICK_MSECURITY_PAY',
  };

  const params = {
    app_id: config.alipayAppId,
    method: 'alipay.trade.app.pay',
    format: 'JSON',
    charset: 'utf-8',
    sign_type: 'RSA2',
    timestamp: formatChinaTimestamp(new Date()),
    version: '1.0',
    notify_url: config.alipayNotifyUrl,
    biz_content: JSON.stringify(bizContent),
  };

  const signingString = buildSignContent(params);
  const signature = signWithRsa2(signingString);
  const query = Object.keys(params)
      .sort()
      .map((key) => `${key}=${encodeURIComponent(params[key])}`)
      .join('&');

  return {
    merchantOrderNo: finalMerchantOrderNo,
    orderString: `${query}&sign=${encodeURIComponent(signature)}`,
    debugMeta: {
      app_id: config.alipayAppId,
      merchant_order_no: finalMerchantOrderNo,
      notify_url: config.alipayNotifyUrl,
      timestamp: params.timestamp,
      sandbox: false,
    },
  };
}

export function verifyAlipaySignature(params) {
  const sign = params.sign?.trim();
  if (!sign) {
    return false;
  }

  const verifier = crypto.createVerify('RSA-SHA256');
  verifier.update(buildSignContent(params), 'utf8');
  verifier.end();
  return verifier.verify(normalizePublicKey(config.alipayPublicKey), sign, 'base64');
}
