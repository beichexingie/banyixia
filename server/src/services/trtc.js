import crypto from 'crypto';
import zlib from 'zlib';

import { config, hasTrtcConfig } from '../config.js';

function base64UrlEncode(buffer) {
  return Buffer.from(buffer)
    .toString('base64')
    .replace(/\+/g, '*')
    .replace(/\//g, '-')
    .replace(/=/g, '_');
}

export function buildTrtcRoomId(orderId) {
  const hash = crypto.createHash('sha1').update(orderId).digest();
  return hash.readUInt32BE(0) & 0x7fffffff;
}

export function buildTrtcUserId(userId) {
  return `u_${userId.replace(/[^0-9A-Za-z_-]/g, '')}`;
}

export function generateUserSig(userId, nowSeconds = Math.floor(Date.now() / 1000)) {
  if (!hasTrtcConfig()) {
    const error = new Error('TRTC is not configured');
    error.statusCode = 503;
    throw error;
  }

  const expire = config.trtcUserSigExpireSeconds;
  const signContent = [
    `TLS.identifier:${userId}`,
    `TLS.sdkappid:${config.trtcSdkAppId}`,
    `TLS.time:${nowSeconds}`,
    `TLS.expire:${expire}`,
    '',
  ].join('\n');
  const signature = crypto
    .createHmac('sha256', config.trtcSecretKey)
    .update(signContent)
    .digest('base64');
  const payload = {
    'TLS.ver': '2.0',
    'TLS.identifier': userId,
    'TLS.sdkappid': config.trtcSdkAppId,
    'TLS.expire': expire,
    'TLS.time': nowSeconds,
    'TLS.sig': signature,
  };
  const compressed = zlib.deflateSync(Buffer.from(JSON.stringify(payload)));
  return base64UrlEncode(compressed);
}

export function buildTrtcCredential(userId) {
  const trtcUserId = buildTrtcUserId(userId);
  return {
    sdk_app_id: config.trtcSdkAppId,
    user_id: trtcUserId,
    user_sig: generateUserSig(trtcUserId),
    expires_in: config.trtcUserSigExpireSeconds,
  };
}
