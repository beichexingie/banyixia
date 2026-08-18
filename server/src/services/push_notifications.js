import crypto from 'crypto';

import { config } from '../config.js';

let clientPromise;

function appKeyForVariant(appVariant) {
  if (appVariant === 'guide') {
    return config.aliyunMobilePushGuideAppKey;
  }
  return config.aliyunMobilePushCustomerAppKey;
}

function parseAppKey(value) {
  const appKey = Number(value);
  return Number.isSafeInteger(appKey) && appKey > 0 ? appKey : 0;
}

function hasMobilePushConfig() {
  return Boolean(
    config.aliyunMobilePushEnabled &&
      config.aliyunMobilePushAccessKeyId &&
      config.aliyunMobilePushAccessKeySecret,
  );
}

async function getPushClient() {
  if (!clientPromise) {
    clientPromise = (async () => {
      const pushModule = await import('@alicloud/push20160801');
      // The Alibaba SDK is CommonJS-generated. With dynamic import its client
      // constructor is nested under default.default in Node's ESM bridge.
      const PushClient =
        pushModule.default?.default ??
        pushModule.default ??
        pushModule.PushClient;
      const PushRequest =
        pushModule.PushRequest ?? pushModule.default?.PushRequest;
      if (typeof PushClient !== 'function') {
        throw new TypeError('Alibaba Cloud Mobile Push client is unavailable');
      }
      if (typeof PushRequest !== 'function') {
        throw new TypeError('Alibaba Cloud Mobile Push request model is unavailable');
      }
      return {
        client: new PushClient({
          accessKeyId: config.aliyunMobilePushAccessKeyId,
          accessKeySecret: config.aliyunMobilePushAccessKeySecret,
          regionId: config.aliyunMobilePushRegionId,
        }),
        PushRequest,
      };
    })();
  }
  return clientPromise;
}

function chunk(items, size) {
  const result = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
}

function pushExpireTime() {
  // Mobile Push accepts UTC timestamps to seconds, not JavaScript milliseconds.
  return new Date(Date.now() + 24 * 60 * 60 * 1000)
    .toISOString()
    .replace(/\.\d{3}Z$/, 'Z');
}

async function sendNotice(push, appKey, deviceIds, notification, data) {
  return push.client.push(new push.PushRequest({
    appKey,
    target: 'DEVICE',
    targetValue: deviceIds.join(','),
    deviceType: 'ANDROID',
    pushType: 'NOTICE',
    title: notification.title,
    body: notification.body,
    storeOffline: true,
    expireTime: pushExpireTime(),
    androidOpenType: 'APPLICATION',
    androidNotifyType: 'BOTH',
    androidNotificationChannel: 'yidianban_messages',
    androidExtParameters: JSON.stringify(data),
    idempotentToken: crypto.randomUUID(),
  }));
}

function responseValue(response, ...keys) {
  const sources = [response?.body, response?.data, response];
  for (const source of sources) {
    if (!source || typeof source !== 'object') continue;
    for (const key of keys) {
      const value = source[key];
      if (value != null && String(value).trim() !== '') return String(value);
    }
  }
  return '';
}

function errorDetails(error) {
  const data = error?.data ?? error?.body ?? {};
  return {
    code: String(error?.code ?? data?.Code ?? '').trim(),
    message: String(
      error?.message ?? data?.Message ?? error?.detail ?? error?.description ?? '',
    ).trim(),
    requestId:
      responseValue(error, 'requestId', 'RequestId') ||
      responseValue(data, 'requestId', 'RequestId'),
  };
}

async function writeDeliveryLog(pool, values) {
  try {
    await pool.query(
      `
        insert into public.push_delivery_logs
          (
            user_id, device_prefixes, app_variant, app_key,
            notification_type, status, message_id, request_id,
            error_code, error_message, response_json
          )
        values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb)
      `,
      [
        values.userId || null,
        values.devicePrefixes ?? [],
        values.appVariant || 'customer',
        values.appKey || 0,
        values.type || 'general',
        values.status || 'accepted',
        values.messageId || null,
        values.requestId || null,
        values.errorCode || null,
        values.errorMessage || null,
        JSON.stringify(values.response ?? {}),
      ],
    );
  } catch (error) {
    console.error('[push] diagnostic log insert failed', error);
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
  if (!hasMobilePushConfig()) {
    console.warn(
      `[push] skipped user=${userId}: Alibaba Cloud Mobile Push is not configured`,
    );
    return { sent: 0, failed: 0, reason: 'not_configured' };
  }

  try {
    const devices = await pool.query(
      `
        select id, token, app_variant
        from public.device_push_tokens
        where user_id = $1
          and enabled = true
          and platform = 'aliyun_android'
      `,
      [userId],
    );
    if (devices.rows.length === 0) {
      console.warn(`[push] skipped user=${userId}: no Aliyun Push device`);
      return { sent: 0, failed: 0, reason: 'device_missing' };
    }

    const push = await getPushClient();
    const variants = new Map();
    for (const device of devices.rows) {
      const appKey = parseAppKey(appKeyForVariant(device.app_variant));
      if (!appKey) {
        console.warn(
          `[push] skipped device=${device.id}: missing AppKey for ${device.app_variant}`,
        );
        continue;
      }
      const key = `${device.app_variant}:${appKey}`;
      const group = variants.get(key) ?? { appKey, devices: [] };
      group.devices.push(device);
      variants.set(key, group);
    }

    let sent = 0;
    let failed = 0;
    for (const { appKey, devices: variantDevices } of variants.values()) {
      for (const deviceGroup of chunk(variantDevices, 1000)) {
        const deviceIds = deviceGroup.map((device) => device.token);
        const devicePrefixes = deviceIds.map((token) => token.slice(0, 12));
        try {
          const response = await sendNotice(
            push,
            appKey,
            deviceIds,
            { title, body },
            { route, type, order_id: orderId },
          );
          const messageId = responseValue(response, 'messageId', 'MessageId');
          const requestId = responseValue(response, 'requestId', 'RequestId');
          console.log(
            `[push] accepted user=${userId} type=${type} ` +
              `appVariant=${deviceGroup[0].app_variant} devices=${devicePrefixes.join(',')} ` +
              `messageId=${messageId || '-'} requestId=${requestId || '-'}`,
          );
          await writeDeliveryLog(pool, {
            userId,
            deviceIds,
            devicePrefixes,
            appVariant: deviceGroup[0].app_variant,
            appKey,
            type,
            status: 'accepted',
            messageId,
            requestId,
            response,
          });
          await pool.query(
            `
              update public.device_push_tokens
              set last_seen_at = now(), updated_at = now()
              where id = any($1::uuid[])
            `,
            [deviceGroup.map((device) => device.id)],
          );
          sent += deviceGroup.length;
        } catch (error) {
          failed += deviceGroup.length;
          const details = errorDetails(error);
          await writeDeliveryLog(pool, {
            userId,
            deviceIds,
            devicePrefixes,
            appVariant: deviceGroup[0].app_variant,
            appKey,
            type,
            status: 'failed',
            requestId: details.requestId,
            errorCode: details.code,
            errorMessage: details.message,
            response: error?.data ?? {},
          });
          console.error(
            `[push] Aliyun send failed user=${userId} appKey=${appKey} ` +
              `type=${type} devices=${devicePrefixes.join(',')} ` +
              `code=${details.code || '-'} requestId=${details.requestId || '-'}`,
            error,
          );
        }
      }
    }

    console.log(`[push] user=${userId} sent=${sent} failed=${failed} type=${type}`);
    return { sent, failed, reason: failed > 0 ? 'send_failed' : 'sent' };
  } catch (error) {
    // Push delivery is best-effort and must never fail orders or payments.
    console.error(`[push] notify user=${userId} failed`, error);
    return { sent: 0, failed: 1, reason: 'exception' };
  }
}
