import crypto from 'crypto';
import fs from 'fs/promises';

import { config } from '../config.js';

let serviceAccountPromise;
let accessTokenCache;

function base64Url(value) {
  return Buffer.from(value)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

async function loadServiceAccount() {
  if (!serviceAccountPromise) {
    serviceAccountPromise = (async () => {
      if (config.firebaseServiceAccountFile) {
        const content = await fs.readFile(
          config.firebaseServiceAccountFile,
          'utf8',
        );
        return JSON.parse(content);
      }
      if (config.firebaseServiceAccountJson) {
        return JSON.parse(config.firebaseServiceAccountJson);
      }
      return null;
    })();
  }
  return serviceAccountPromise;
}

async function getAccessToken(account) {
  const now = Math.floor(Date.now() / 1000);
  if (accessTokenCache && accessTokenCache.expiresAt > now + 60) {
    return accessTokenCache.token;
  }

  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64Url(
    JSON.stringify({
      iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${claim}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(unsigned);
  signer.end();
  const signature = base64Url(signer.sign(account.private_key));
  const assertion = `${unsigned}.${signature}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const payload = await response.json();
  if (!response.ok || !payload.access_token) {
    throw new Error(
      `Firebase access token failed: ${payload.error_description || payload.error || response.status}`,
    );
  }

  accessTokenCache = {
    token: payload.access_token,
    expiresAt: now + Number(payload.expires_in || 3600),
  };
  return accessTokenCache.token;
}

async function sendToToken(account, token, notification, data) {
  const accessToken = await getAccessToken(account);
  const projectId = account.project_id || config.firebaseProjectId;
  if (!projectId) throw new Error('Firebase project_id is missing');

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification,
          data: Object.fromEntries(
            Object.entries(data || {}).map(([key, value]) => [
              key,
              value?.toString() ?? '',
            ]),
          ),
          android: {
            priority: 'high',
            notification: {
              channel_id: 'yidianban_messages',
              sound: 'default',
            },
          },
        },
      }),
    },
  );

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const errorCode = payload.error?.details?.find(
      (item) => item['@type']?.includes('FcmError'),
    )?.errorCode;
    const error = new Error(
      `Firebase push failed: ${errorCode || payload.error?.message || response.status}`,
    );
    error.fcmCode = errorCode;
    throw error;
  }
}

export async function notifyUser(
  pool,
  userId,
  { title, body, route, type = 'general', orderId = '' },
) {
  if (!userId) {
    return { sent: 0, failed: 0, reason: 'missing_user' };
  }
  if (!config.firebasePushEnabled) {
    console.warn(`[push] skipped user=${userId}: FIREBASE_PUSH_ENABLED is false`);
    return { sent: 0, failed: 0, reason: 'disabled' };
  }
  try {
    const account = await loadServiceAccount();
    if (!account) {
      console.warn(`[push] skipped user=${userId}: Firebase service account is not configured`);
      return { sent: 0, failed: 0, reason: 'service_account_missing' };
    }

    const result = await pool.query(
      `
        select id, token
        from public.device_push_tokens
        where user_id = $1 and enabled = true
      `,
      [userId],
    );

    if (result.rows.length === 0) {
      console.warn(`[push] skipped user=${userId}: no enabled device token`);
      return { sent: 0, failed: 0, reason: 'device_token_missing' };
    }

    const outcomes = await Promise.all(
      result.rows.map(async (device) => {
        try {
          await sendToToken(
            account,
            device.token,
            { title, body },
            { route, type, order_id: orderId },
          );
          await pool.query(
            `update public.device_push_tokens set last_seen_at = now() where id = $1`,
            [device.id],
          );
          return true;
        } catch (error) {
          if (
            error.fcmCode === 'UNREGISTERED' ||
            error.fcmCode === 'INVALID_ARGUMENT'
          ) {
            await pool.query(
              `update public.device_push_tokens set enabled = false where id = $1`,
              [device.id],
            );
          }
          console.error(`[push] user=${userId} token=${device.id}`, error);
          return false;
        }
      }),
    );
    const sent = outcomes.filter(Boolean).length;
    const failed = outcomes.length - sent;
    console.log(`[push] user=${userId} sent=${sent} failed=${failed} type=${type}`);
    return { sent, failed, reason: failed > 0 ? 'send_failed' : 'sent' };
  } catch (error) {
    // Push is best-effort and must not fail orders, payments, or chat.
    console.error(`[push] notify user=${userId} failed`, error);
    return { sent: 0, failed: 1, reason: 'exception' };
  }
}
