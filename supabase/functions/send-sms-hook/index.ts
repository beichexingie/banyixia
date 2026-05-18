type SendSmsHookEvent = {
  user?: {
    phone?: string | null;
  };
  sms?: {
    otp?: string | null;
  };
  phone?: string | null;
  otp?: string | null;
  code?: string | null;
};

type AliyunSmsResponse = {
  Code?: string;
  Message?: string;
  RequestId?: string;
  BizId?: string;
};

const requiredEnv = [
  'ALIYUN_ACCESS_KEY_ID',
  'ALIYUN_ACCESS_KEY_SECRET',
  'ALIYUN_SMS_SIGN_NAME',
  'ALIYUN_SMS_TEMPLATE_CODE',
];

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}

function normalizePhone(phone: string): string {
  return phone.replace(/^\+86/, '').replace(/[^\d]/g, '');
}

function percentEncode(value: string): string {
  return encodeURIComponent(value)
    .replace(/\*/g, '%2A')
    .replace(/%7E/g, '~')
    .replace(/\+/g, '%20');
}

function toUtf8Bytes(value: string): Uint8Array {
  return new TextEncoder().encode(value);
}

function toBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

async function signHmacSha1(message: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    toUtf8Bytes(`${secret}&`),
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    toUtf8Bytes(message),
  );

  return toBase64(new Uint8Array(signature));
}

function buildCanonicalizedQuery(params: Record<string, string>): string {
  return Object.keys(params)
    .sort()
    .map((key) => `${percentEncode(key)}=${percentEncode(params[key])}`)
    .join('&');
}

function buildTimestamp(): string {
  return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function extractPhone(event: SendSmsHookEvent | null): string {
  return (
    event?.user?.phone?.trim() ||
    event?.phone?.trim() ||
    ''
  );
}

function extractOtp(event: SendSmsHookEvent | null): string {
  return (
    event?.sms?.otp?.trim() ||
    event?.otp?.trim() ||
    event?.code?.trim() ||
    ''
  );
}

async function sendAliyunSms(phone: string, otp: string): Promise<AliyunSmsResponse> {
  const accessKeyId = Deno.env.get('ALIYUN_ACCESS_KEY_ID')!.trim();
  const accessKeySecret = Deno.env.get('ALIYUN_ACCESS_KEY_SECRET')!.trim();
  const signName = Deno.env.get('ALIYUN_SMS_SIGN_NAME')!.trim();
  const templateCode = Deno.env.get('ALIYUN_SMS_TEMPLATE_CODE')!.trim();
  const regionId = Deno.env.get('ALIYUN_SMS_REGION_ID')?.trim() || 'cn-hangzhou';

  const params: Record<string, string> = {
    AccessKeyId: accessKeyId,
    Action: 'SendSms',
    Format: 'JSON',
    PhoneNumbers: phone,
    RegionId: regionId,
    SignName: signName,
    SignatureMethod: 'HMAC-SHA1',
    SignatureNonce: crypto.randomUUID(),
    SignatureVersion: '1.0',
    TemplateCode: templateCode,
    TemplateParam: JSON.stringify({ code: otp }),
    Timestamp: buildTimestamp(),
    Version: '2017-05-25',
  };

  const canonicalizedQueryString = buildCanonicalizedQuery(params);
  const stringToSign = `GET&${percentEncode('/')}&${percentEncode(canonicalizedQueryString)}`;
  const signature = await signHmacSha1(stringToSign, accessKeySecret);

  const requestUrl = `https://dysmsapi.aliyuncs.com/?${canonicalizedQueryString}&Signature=${percentEncode(signature)}`;
  const response = await fetch(requestUrl, { method: 'GET' });
  const data = (await response.json().catch(() => null)) as AliyunSmsResponse | null;

  if (!response.ok || !data || data.Code !== 'OK') {
    const message = data?.Message || `Aliyun SMS request failed with ${response.status}`;
    throw new Error(message);
  }

  return data;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ success: false, message: 'Method not allowed' }, 405);
  }

  const missing = requiredEnv.filter((name) => !Deno.env.get(name));
  if (missing.length > 0) {
    return json(
      {
        success: false,
        message: '阿里云短信环境变量未配置',
        missing,
      },
      500,
    );
  }

  const event = (await req.json().catch(() => null)) as SendSmsHookEvent | null;
  const phone = extractPhone(event);
  const otp = extractOtp(event);

  if (!phone || !otp) {
    return json(
      {
        success: false,
        message: '缺少手机号或验证码',
      },
      400,
    );
  }

  try {
    const normalizedPhone = normalizePhone(phone);
    const result = await sendAliyunSms(normalizedPhone, otp);

    return json({
      success: true,
      message: '短信已发送',
      request_id: result.RequestId,
      biz_id: result.BizId,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json(
      {
        success: false,
        message: `短信发送失败: ${message}`,
      },
      500,
    );
  }
});
