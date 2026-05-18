type CreateOrderBody = {
  order_id?: string;
  merchant_order_no?: string;
  amount?: number;
  subject?: string;
  payment_method?: string;
  sandbox?: boolean;
};

const requiredEnv = [
  'ALIPAY_APP_ID',
  'ALIPAY_PRIVATE_KEY',
  'ALIPAY_NOTIFY_URL',
];

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function formatChinaTimestamp(date: Date): string {
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
  const values: Record<string, string> = {};
  for (const part of parts) {
    if (part.type != 'literal') {
      values[part.type] = part.value;
    }
  }

  return `${values.year}-${values.month}-${values.day} ${values.hour}:${values.minute}:${values.second}`;
}

function encodeBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

async function signWithRsa2(message: string, privateKeyPem: string): Promise<string> {
  const pem = privateKeyPem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');

  const binaryDer = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(message),
  );

  return encodeBase64(new Uint8Array(signature));
}

async function buildOrderString(
  params: Record<string, string>,
  privateKeyPem: string,
): Promise<string> {
  const sortedKeys = Object.keys(params).sort();
  const signingString = sortedKeys
    .map((key) => `${key}=${params[key]}`)
    .join('&');

  const signature = await signWithRsa2(signingString, privateKeyPem);

  const query = sortedKeys
    .map((key) => `${key}=${encodeURIComponent(params[key])}`)
    .join('&');

  return `${query}&sign=${encodeURIComponent(signature)}`;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ success: false, message: 'Method not allowed' }, 405);
  }

  const missing = requiredEnv.filter((name) => !Deno.env.get(name));
  if (missing.length > 0) {
    return json({
      success: false,
      message: '支付宝环境变量未配置',
      missing,
    }, 500);
  }

  const body = (await req.json().catch(() => null)) as CreateOrderBody | null;
  if (!body?.order_id || !body.amount || !body.subject) {
    return json({ success: false, message: '缺少订单参数' }, 400);
  }

  try {
    const appId = Deno.env.get('ALIPAY_APP_ID')!.trim();
    const privateKey = Deno.env.get('ALIPAY_PRIVATE_KEY')!.trim();
    const notifyUrl = Deno.env.get('ALIPAY_NOTIFY_URL')!.trim();

    const merchantOrderNo = (body.merchant_order_no ?? body.order_id)
      .replace(/[^0-9A-Za-z_]/g, '')
      .slice(0, 64);

    if (!merchantOrderNo) {
      return json({ success: false, message: '商户订单号无效' }, 400);
    }

    const bizContent = {
      subject: body.subject,
      out_trade_no: merchantOrderNo,
      total_amount: Number(body.amount).toFixed(2),
      timeout_express: '30m',
      product_code: 'QUICK_MSECURITY_PAY',
    };

    const params: Record<string, string> = {
      app_id: appId,
      method: 'alipay.trade.app.pay',
      format: 'JSON',
      charset: 'utf-8',
      sign_type: 'RSA2',
      timestamp: formatChinaTimestamp(new Date()),
      version: '1.0',
      notify_url: notifyUrl,
      biz_content: JSON.stringify(bizContent),
    };

    const orderString = await buildOrderString(params, privateKey);

    return json({
      success: true,
      message: '支付宝订单参数已生成',
      payment_request_id: body.order_id,
      order_string: orderString,
      debug_meta: {
        app_id: appId,
        merchant_order_no: merchantOrderNo,
        notify_url: notifyUrl,
        timestamp: params.timestamp,
        sandbox: body.sandbox ?? false,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({
      success: false,
      message: `生成支付宝订单失败: ${message}`,
    }, 500);
  }
});
