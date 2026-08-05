import crypto from 'crypto';

import { config, hasAlipayConfig, hasAlipayTransferConfig } from '../config.js';

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

function buildV3Authorization(method, requestPath, body) {
  const nonce = crypto.randomUUID();
  const timestamp = Date.now().toString();
  let authString = `app_id=${config.alipayAppId}`;
  if (config.alipayAppCertSn) {
    authString += `,app_cert_sn=${config.alipayAppCertSn}`;
  }
  authString += `,nonce=${nonce},timestamp=${timestamp}`;
  const signContent = `${authString}\n${method}\n${requestPath}\n${body}\n`;
  const signature = signWithRsa2(signContent);
  return {
    authorization: `ALIPAY-SHA256withRSA ${authString},sign=${signature}`,
    ...(config.alipayRootCertSn
      ? { 'alipay-root-cert-sn': config.alipayRootCertSn }
      : {}),
    'alipay-request-id': crypto.randomUUID(),
  };
}

async function requestAlipayV3(method, requestPath, body = '') {
  if (!hasAlipayConfig()) {
    throw new Error('支付宝环境变量未配置完整');
  }

  const baseUrl = config.alipayApiBaseUrl.replace(/\/+$/, '');
  const bodyText = body || '';
  let response;
  try {
    response = await fetch(`${baseUrl}${requestPath}`, {
      method,
      headers: {
        ...buildV3Authorization(method, requestPath, bodyText),
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
      body: method === 'GET' ? undefined : bodyText,
      signal: AbortSignal.timeout(15000),
    });
  } catch (error) {
    error.remoteAttempted = true;
    throw error;
  }

  const text = await response.text();
  let payload;
  try {
    payload = JSON.parse(text);
  } catch (error) {
    const parseError = new Error(`支付宝返回非 JSON：${text.slice(0, 200)}`);
    parseError.remoteAttempted = true;
    throw parseError;
  }

  if (!response.ok) {
    const message = payload.sub_msg || payload.msg || text.slice(0, 300);
    const code = payload.sub_code || payload.code || response.status;
    const httpError = new Error(`支付宝 API 错误：${message}${code ? `（${code}）` : ''}`);
    httpError.alipayPayload = payload;
    httpError.remoteAttempted = response.status >= 500;
    throw httpError;
  }

  return payload;
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

export async function queryAlipayTrade({ merchantOrderNo, tradeNo = '' }) {
  if (!hasAlipayConfig()) {
    throw new Error('支付宝环境变量未配置完整');
  }

  const bizContent = {};
  if (tradeNo?.toString().trim()) {
    bizContent.trade_no = tradeNo.toString().trim();
  } else if (merchantOrderNo?.toString().trim()) {
    bizContent.out_trade_no = merchantOrderNo.toString().trim();
  } else {
    throw new Error('缺少支付宝订单号');
  }

  const params = {
    app_id: config.alipayAppId,
    method: 'alipay.trade.query',
    format: 'JSON',
    charset: 'utf-8',
    sign_type: 'RSA2',
    timestamp: formatChinaTimestamp(new Date()),
    version: '1.0',
    biz_content: JSON.stringify(bizContent),
  };
  const sign = signWithRsa2(buildSignContent(params));
  const body = new URLSearchParams({ ...params, sign }).toString();

  let response;
  try {
    response = await fetch(`${config.alipayApiBaseUrl.replace(/\/+$/, '')}/gateway.do`, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
      },
      body,
      signal: AbortSignal.timeout(15000),
    });
  } catch (error) {
    error.remoteAttempted = true;
    throw error;
  }

  const text = await response.text();
  let payload;
  try {
    payload = JSON.parse(text);
  } catch (_error) {
    const parseError = new Error(`支付宝返回非 JSON：${text.slice(0, 200)}`);
    parseError.remoteAttempted = true;
    throw parseError;
  }

  const result = payload.alipay_trade_query_response ?? payload;
  if (!response.ok || result.code !== '10000') {
    const error = new Error(
      `支付宝订单查询失败：${result.sub_msg || result.msg || text.slice(0, 300)}`,
    );
    error.remoteAttempted = true;
    throw error;
  }

  return {
    tradeStatus: result.trade_status || '',
    tradeNo: result.trade_no || tradeNo || '',
    totalAmount: Number(result.total_amount || 0),
    raw: payload,
  };
}

export function buildWithdrawalOutBizNo(withdrawalId) {
  const normalized = withdrawalId
      .toString()
      .replace(/[^0-9A-Za-z]/g, '')
      .slice(0, 54);
  if (!normalized) {
    throw new Error('提现单号无效');
  }
  return `wd${normalized}`;
}

export async function transferToAlipayAccount({
  withdrawalId,
  amount,
  alipayAccount,
  alipayUserId,
  realName,
  remark = '',
}) {
  if (!hasAlipayTransferConfig()) {
    throw new Error('支付宝商家转账未开启或环境变量未配置完整');
  }

  const finalAmount = Number(amount);
  if (!(finalAmount > 0)) {
    throw new Error('转账金额必须大于 0');
  }
  if (config.alipayTransferMaxAmount > 0 && finalAmount > config.alipayTransferMaxAmount) {
    throw new Error(`单笔转账金额超过当前安全上限 ${config.alipayTransferMaxAmount} 元`);
  }

  const identity = (alipayUserId || alipayAccount || '').toString().trim();
  if (!identity) {
    throw new Error('缺少地陪支付宝收款账号或支付宝 user_id');
  }

  const payeeInfo = {
    identity,
    identity_type: alipayUserId ? 'ALIPAY_USER_ID' : 'ALIPAY_LOGON_ID',
  };
  const name = realName?.toString().trim();
  if (name) {
    payeeInfo.name = name;
  }

  const outBizNo = buildWithdrawalOutBizNo(withdrawalId);
  const bizContent = {
    out_biz_no: outBizNo,
    trans_amount: finalAmount.toFixed(2),
    product_code: 'TRANS_ACCOUNT_NO_PWD',
    biz_scene: 'DIRECT_TRANSFER',
    order_title: '一点伴地陪提现',
    remark: remark || '一点伴地陪提现',
    payee_info: payeeInfo,
  };

  const payload = await requestAlipayV3(
    'POST',
    '/v3/alipay/fund/trans/uni/transfer',
    JSON.stringify(bizContent),
  );

  return {
    outBizNo,
    orderId: payload.order_id || '',
    payFundOrderId: payload.pay_fund_order_id || '',
    status: payload.status || 'SUCCESS',
    transDate: payload.trans_date || '',
    raw: payload,
  };
}

export async function queryAlipayTransfer({ withdrawalId }) {
  if (!hasAlipayTransferConfig()) {
    throw new Error('支付宝商家转账未开启或环境变量未配置完整');
  }

  const outBizNo = buildWithdrawalOutBizNo(withdrawalId);
  const query = new URLSearchParams({
    product_code: 'TRANS_ACCOUNT_NO_PWD',
    biz_scene: 'DIRECT_TRANSFER',
    out_biz_no: outBizNo,
  });
  const payload = await requestAlipayV3(
    'GET',
    `/v3/alipay/fund/trans/common/query?${query.toString()}`,
  );

  return {
    outBizNo,
    orderId: payload.order_id || '',
    payFundOrderId: payload.pay_fund_order_id || '',
    status: payload.status || 'DEALING',
    failReason: payload.fail_reason || '',
    transDate: payload.trans_date || '',
    raw: payload,
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
