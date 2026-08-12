import crypto from 'crypto';
import https from 'https';

import { config } from '../config.js';

function percentEncode(value) {
  return encodeURIComponent(value)
    .replace(/\+/g, '%20')
    .replace(/\*/g, '%2A')
    .replace(/%7E/g, '~');
}

function canonicalQuery(params) {
  return Object.keys(params)
    .sort()
    .map((key) => `${percentEncode(key)}=${percentEncode(params[key])}`)
    .join('&');
}

function signRpcRequest(params) {
  const query = canonicalQuery(params);
  return crypto
    .createHmac('sha1', `${config.aliyunSmsAccessKeySecret}&`)
    .update(`GET&%2F&${percentEncode(query)}`)
    .digest('base64');
}

function callAliyunRpc(apiParams) {
  return new Promise((resolve, reject) => {
    const params = {
      Action: 'SendSms',
      Format: 'JSON',
      Version: '2017-05-25',
      AccessKeyId: config.aliyunSmsAccessKeyId,
      SignatureMethod: 'HMAC-SHA1',
      SignatureVersion: '1.0',
      SignatureNonce: crypto.randomUUID(),
      Timestamp: new Date().toISOString(),
      RegionId: config.aliyunSmsRegionId,
      ...apiParams,
    };
    params.Signature = signRpcRequest(params);
    const request = https.get(
      {
        hostname: config.aliyunSmsDomain,
        path: `/?${canonicalQuery(params)}`,
        method: 'GET',
      },
      (response) => {
        let body = '';
        response.setEncoding('utf8');
        response.on('data', (chunk) => (body += chunk));
        response.on('end', () => {
          let data;
          try {
            data = JSON.parse(body);
          } catch (_) {
            const error = new Error('阿里云短信返回非 JSON');
            error.statusCode = 502;
            reject(error);
            return;
          }
          if (response.statusCode < 200 || response.statusCode >= 300 || data.Code !== 'OK') {
            const error = new Error(data.Message || data.Code || '阿里云短信发送失败');
            error.statusCode = 502;
            error.raw = data;
            reject(error);
            return;
          }
          resolve(data);
        });
      },
    );
    request.setTimeout(15000, () => request.destroy(new Error('阿里云短信请求超时')));
    request.on('error', (error) => {
      error.statusCode = 502;
      reject(error);
    });
  });
}

export function hasSmsConfig() {
  return Boolean(
    config.aliyunSmsEnabled &&
      config.aliyunSmsAccessKeyId &&
      config.aliyunSmsAccessKeySecret &&
      config.aliyunSmsSignName &&
      config.aliyunSmsTemplateCode,
  );
}

export async function sendSmsCode(phone, code) {
  if (!hasSmsConfig()) {
    const error = new Error('阿里云短信环境变量未配置完整');
    error.statusCode = 503;
    throw error;
  }
  return callAliyunRpc({
    PhoneNumbers: phone,
    SignName: config.aliyunSmsSignName,
    TemplateCode: config.aliyunSmsTemplateCode,
    TemplateParam: JSON.stringify({ code }),
  });
}
