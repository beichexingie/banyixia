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
      const { default: PushClient } = await import('@alicloud/push20160801');
      return new PushClient({
        accessKeyId: config.aliyunMobilePushAccessKeyId,
        accessKeySecret: config.aliyunMobilePushAccessKeySecret,
        regionId: config.aliyunMobilePushRegionId,
      });
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

async function sendNotice(client, appKey, deviceIds, notification, data) {
  return client.push({
    appKey,
    target: 'DEVICE',
    targetValue: deviceIds.join(','),
    deviceType: 'ANDROID',
    pushType: 'NOTICE',
    title: notification.title,
    body: notification.body,
    storeOffline: true,
    expireTime: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    androidOpenType: 'APPLICATION',
    androidNotifyType: 'BOTH',
    androidNotificationChannel: 'yidianban_messages',
    androidExtParameters: JSON.stringify(data),
    idempotentToken: crypto.randomUUID(),
  });
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

    const client = await getPushClient();
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
        try {
          await sendNotice(
            client,
            appKey,
            deviceGroup.map((device) => device.token),
            { title, body },
            { route, type, order_id: orderId },
          );
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
          console.error(
            `[push] Aliyun send failed user=${userId} appKey=${appKey}`,
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
