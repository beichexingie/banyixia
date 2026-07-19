import crypto from 'crypto';
import https from 'https';

import { config } from '../config.js';

function isConfigured() {
  return Boolean(
    config.virtualNumberEnabled &&
      config.aliyunAccessKeyId &&
      config.aliyunAccessKeySecret &&
      config.aliyunDyplsPoolKey &&
      config.aliyunDyplsPhoneNoX,
  );
}

function percentEncode(value) {
  return encodeURIComponent(value)
      .replace(/\+/g, '%20')
      .replace(/\*/g, '%2A')
      .replace(/%7E/g, '~');
}

function buildCanonicalizedQuery(params) {
  return Object.keys(params)
      .sort()
      .map((key) => `${percentEncode(key)}=${percentEncode(params[key])}`)
      .join('&');
}

function signRpcRequest(params) {
  const canonicalizedQuery = buildCanonicalizedQuery(params);
  const stringToSign = `GET&%2F&${percentEncode(canonicalizedQuery)}`;
  return crypto
      .createHmac('sha1', `${config.aliyunAccessKeySecret}&`)
      .update(stringToSign)
      .digest('base64');
}

function callAliyunRpc(action, apiParams) {
  return new Promise((resolve, reject) => {
    const params = {
      Action: action,
      Format: 'JSON',
      Version: '2017-05-25',
      AccessKeyId: config.aliyunAccessKeyId,
      SignatureMethod: 'HMAC-SHA1',
      Timestamp: new Date().toISOString(),
      SignatureVersion: '1.0',
      SignatureNonce: crypto.randomUUID(),
      RegionId: config.aliyunDyplsRegionId,
      ...apiParams,
    };
    params.Signature = signRpcRequest(params);
    const query = buildCanonicalizedQuery(params);
    const request = https.get(
      {
        hostname: config.aliyunDyplsDomain,
        path: `/?${query}`,
        method: 'GET',
      },
      (response) => {
        let body = '';
        response.setEncoding('utf8');
        response.on('data', (chunk) => {
          body += chunk;
        });
        response.on('end', () => {
          try {
            const data = JSON.parse(body);
            if (response.statusCode < 200 || response.statusCode >= 300) {
              const error = new Error(data.Message || '阿里云号码隐私保护请求失败');
              error.statusCode = 502;
              error.raw = data;
              reject(error);
              return;
            }
            resolve(data);
          } catch (error) {
            error.statusCode = 502;
            reject(error);
          }
        });
      },
    );
    request.on('error', (error) => {
      error.statusCode = 502;
      reject(error);
    });
  });
}

export async function bindAxbVirtualNumber({
  phoneNoA,
  phoneNoB,
  outId,
  expirationSeconds = 3600,
}) {
  if (!isConfigured()) {
    const error = new Error('虚拟号未配置，请先开通阿里云号码隐私保护并填写环境变量');
    error.statusCode = 503;
    throw error;
  }

  const expiration = new Date(
    Date.now() + expirationSeconds * 1000,
  ).toISOString().replace(/\.\d{3}Z$/, 'Z');
  const response = await callAliyunRpc('BindAxb', {
    PoolKey: config.aliyunDyplsPoolKey,
    PhoneNoA: phoneNoA,
    PhoneNoB: phoneNoB,
    PhoneNoX: config.aliyunDyplsPhoneNoX,
    Expiration: expiration,
    OutId: outId,
  });

  if (response.Code && response.Code !== 'OK') {
    const error = new Error(response.Message || '虚拟号绑定失败');
    error.statusCode = 502;
    error.raw = response;
    throw error;
  }

  return {
    bindId: response.SecretBindDTO?.SecretNo || response.SecretBindDTO?.SubsId || '',
    phoneNoX: response.SecretBindDTO?.PhoneNoX || config.aliyunDyplsPhoneNoX,
    raw: response,
  };
}
