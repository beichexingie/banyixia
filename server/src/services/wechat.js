import crypto from 'crypto';
import fs from 'fs';

import { config, hasWechatConfig } from '../config.js';

function readPemFile(filePath, label) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch (error) {
    throw new Error(`读取微信${label}失败：${error.message}`);
  }
}

function merchantPrivateKey() {
  return readPemFile(config.wechatPrivateKeyPath, '商户私钥');
}

function platformPublicKey() {
  const certificate = readPemFile(config.wechatPlatformCertPath, '支付平台证书');
  return new crypto.X509Certificate(certificate).publicKey;
}

function assertWechatConfig() {
  if (!hasWechatConfig()) {
    throw new Error('微信支付环境变量或证书路径未配置完整');
  }
}

function sign(message) {
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(message, 'utf8');
  signer.end();
  return signer.sign(merchantPrivateKey(), 'base64');
}

function buildAuthorization(method, requestPath, body = '') {
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const nonce = crypto.randomBytes(16).toString('hex');
  const message = `${method}\n${requestPath}\n${timestamp}\n${nonce}\n${body}\n`;
  const signature = sign(message);
  return {
    timestamp,
    nonce,
    authorization:
      `WECHATPAY2-SHA256-RSA2048 mchid="${config.wechatMchId}",` +
      `nonce_str="${nonce}",signature="${signature}",timestamp="${timestamp}",` +
      `serial_no="${config.wechatCertSerialNo}"`,
  };
}

async function requestWechatApi(method, requestPath, body = '') {
  assertWechatConfig();
  const authorization = buildAuthorization(method, requestPath, body);
  const response = await fetch(
    `${config.wechatApiBaseUrl.replace(/\/+$/, '')}${requestPath}`,
    {
      method,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        Authorization: authorization.authorization,
        'User-Agent': 'yidianban-server/1.0',
      },
      body: method === 'GET' ? undefined : body,
      signal: AbortSignal.timeout(15000),
    },
  );

  const text = await response.text();
  let payload = {};
  if (text.trim()) {
    try {
      payload = JSON.parse(text);
    } catch (_error) {
      throw new Error(`微信支付返回非 JSON：${text.slice(0, 300)}`);
    }
  }
  if (!response.ok) {
    const message = payload.message || text.slice(0, 300) || response.status;
    throw new Error(`微信支付 API 错误：${message}`);
  }
  return payload;
}

export function buildWechatMerchantOrderNo(rawOrderNo, fallbackOrderId) {
  const source = (rawOrderNo || fallbackOrderId || '')
    .toString()
    .replace(/[^0-9A-Za-z_]/g, '')
    .slice(0, 32);
  if (!source) {
    throw new Error('微信商户订单号无效');
  }
  return source;
}

function amountToFen(amount) {
  const fen = Math.round(Number(amount) * 100);
  if (!Number.isSafeInteger(fen) || fen <= 0) {
    throw new Error('微信订单金额无效');
  }
  return fen;
}

export async function createWechatAppOrder({
  merchantOrderNo,
  fallbackOrderId,
  amount,
  description,
}) {
  assertWechatConfig();
  const outTradeNo = buildWechatMerchantOrderNo(
    merchantOrderNo,
    fallbackOrderId,
  );
  const requestBody = JSON.stringify({
    appid: config.wechatAppId,
    mchid: config.wechatMchId,
    description: String(description || '地陪服务订单').slice(0, 127),
    out_trade_no: outTradeNo,
    // WeChat expects RFC3339 local time with an explicit China timezone.
    time_expire: new Date(Date.now() + 30 * 60 * 1000 + 8 * 60 * 60 * 1000)
      .toISOString()
      .replace(/\.\d{3}Z$/, '+08:00'),
    notify_url: config.wechatNotifyUrl,
    amount: {
      total: amountToFen(amount),
      currency: 'CNY',
    },
  });

  const payload = await requestWechatApi(
    'POST',
    '/v3/pay/transactions/app',
    requestBody,
  );
  if (!payload.prepay_id) {
    throw new Error('微信支付未返回 prepay_id');
  }

  const timestamp = Math.floor(Date.now() / 1000).toString();
  const nonceStr = crypto.randomBytes(16).toString('hex');
  const paySign = sign(
    `${config.wechatAppId}\n${timestamp}\n${nonceStr}\n${payload.prepay_id}\n`,
  );

  return {
    merchantOrderNo: outTradeNo,
    prepayId: payload.prepay_id,
    payParams: {
      app_id: config.wechatAppId,
      partner_id: config.wechatMchId,
      prepay_id: payload.prepay_id,
      package_value: 'Sign=WXPay',
      nonce_str: nonceStr,
      timestamp,
      sign: paySign,
    },
  };
}

export async function queryWechatTransaction({ merchantOrderNo }) {
  assertWechatConfig();
  const outTradeNo = buildWechatMerchantOrderNo(merchantOrderNo);
  const payload = await requestWechatApi(
    'GET',
    `/v3/pay/transactions/out-trade-no/${encodeURIComponent(outTradeNo)}` +
      `?mchid=${encodeURIComponent(config.wechatMchId)}`,
  );
  return {
    tradeState: payload.trade_state || '',
    tradeNo: payload.transaction_id || '',
    totalAmountFen: Number(payload.amount?.total || 0),
    raw: payload,
  };
}

export function verifyWechatNotification({
  body,
  timestamp,
  nonce,
  signature,
  serial,
}) {
  assertWechatConfig();
  if (!body || !timestamp || !nonce || !signature || !serial) {
    return false;
  }
  if (serial !== config.wechatPlatformCertSerialNo) {
    return false;
  }
  const verifier = crypto.createVerify('RSA-SHA256');
  verifier.update(`${timestamp}\n${nonce}\n${body}\n`, 'utf8');
  verifier.end();
  return verifier.verify(platformPublicKey(), signature, 'base64');
}

export function decryptWechatNotification(resource) {
  assertWechatConfig();
  if (resource?.algorithm !== 'AEAD_AES_256_GCM') {
    throw new Error('微信回调使用了不支持的加密算法');
  }
  const key = Buffer.from(config.wechatApiV3Key, 'utf8');
  const nonce = Buffer.from(resource.nonce, 'utf8');
  const encrypted = Buffer.from(resource.ciphertext, 'base64');
  const authTag = encrypted.subarray(encrypted.length - 16);
  const ciphertext = encrypted.subarray(0, encrypted.length - 16);
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, nonce);
  decipher.setAuthTag(authTag);
  if (resource.associated_data) {
    decipher.setAAD(Buffer.from(resource.associated_data, 'utf8'));
  }
  const plaintext = Buffer.concat([
    decipher.update(ciphertext),
    decipher.final(),
  ]).toString('utf8');
  return JSON.parse(plaintext);
}
