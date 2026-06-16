type OrderRow = {
  id: string;
  guide_id: string;
  amount: number;
  status: number;
  payment_status: string | null;
  payment_request_id: string | null;
  merchant_order_no: string | null;
  provider_trade_no: string | null;
};

const requiredEnv = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'ALIPAY_APP_ID',
  'ALIPAY_PUBLIC_KEY',
];

function text(body: string, status = 200) {
  return new Response(body, {
    status,
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}

function normalizePemPublicKey(value: string): string {
  const trimmed = value.trim();
  if (trimmed.includes('BEGIN PUBLIC KEY')) {
    return trimmed;
  }

  const body = trimmed.replace(/\s+/g, '');
  const wrapped = body.match(/.{1,64}/g)?.join('\n') ?? body;
  return `-----BEGIN PUBLIC KEY-----\n${wrapped}\n-----END PUBLIC KEY-----`;
}

function parseQueryLike(raw: string): URLSearchParams {
  const source = raw.trim();
  if (!source) {
    return new URLSearchParams();
  }
  return new URLSearchParams(source.startsWith('?') ? source.slice(1) : source);
}

async function parseRequestParams(req: Request): Promise<Record<string, string>> {
  const contentType = req.headers.get('content-type') ?? '';

  if (contentType.includes('application/x-www-form-urlencoded')) {
    const form = await req.formData();
    const result: Record<string, string> = {};
    for (const [key, value] of form.entries()) {
      result[key] = String(value);
    }
    return result;
  }

  if (contentType.includes('application/json')) {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== 'object') {
      return {};
    }
    return Object.fromEntries(
      Object.entries(body as Record<string, unknown>).map(([key, value]) => [
        key,
        value == null ? '' : String(value),
      ]),
    );
  }

  const raw = await req.text().catch(() => '');
  const params = parseQueryLike(raw);
  return Object.fromEntries(params.entries());
}

async function importAlipayPublicKey(publicKeyPem: string): Promise<CryptoKey> {
  const pem = normalizePemPublicKey(publicKeyPem)
    .replace(/-----BEGIN PUBLIC KEY-----/g, '')
    .replace(/-----END PUBLIC KEY-----/g, '')
    .replace(/\s+/g, '');

  const binaryDer = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'spki',
    binaryDer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['verify'],
  );
}

function buildSignContent(params: Record<string, string>): string {
  return Object.keys(params)
    .filter((key) => key !== 'sign' && key !== 'sign_type' && params[key] !== '')
    .sort()
    .map((key) => `${key}=${params[key]}`)
    .join('&');
}

async function verifyAlipaySignature(
  params: Record<string, string>,
  alipayPublicKey: string,
): Promise<boolean> {
  const sign = params.sign?.trim();
  if (!sign) {
    return false;
  }

  const key = await importAlipayPublicKey(alipayPublicKey);
  const signContent = buildSignContent(params);
  const signature = Uint8Array.from(atob(sign), (c) => c.charCodeAt(0));

  return crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    signature,
    new TextEncoder().encode(signContent),
  );
}

async function supabaseRequest(
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!.trim().replace(/\/$/, '');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!.trim();

  const headers = new Headers(init.headers);
  headers.set('apikey', serviceRoleKey);
  headers.set('Authorization', `Bearer ${serviceRoleKey}`);

  if (!headers.has('Content-Type') && init.body) {
    headers.set('Content-Type', 'application/json');
  }

  return fetch(`${supabaseUrl}${path}`, {
    ...init,
    headers,
  });
}

async function loadOrderByMerchantOrderNo(
  merchantOrderNo: string,
): Promise<OrderRow | null> {
  const response = await supabaseRequest(
    `/rest/v1/orders?merchant_order_no=eq.${encodeURIComponent(
      merchantOrderNo,
    )}&select=id,guide_id,amount,status,payment_status,payment_request_id,merchant_order_no,provider_trade_no&limit=1`,
  );

  if (!response.ok) {
    throw new Error(`load order failed: ${response.status} ${await response.text()}`);
  }

  const rows = (await response.json()) as OrderRow[];
  return rows[0] ?? null;
}

async function updateOrderPayment(
  orderId: string,
  payload: Record<string, unknown>,
): Promise<void> {
  const response = await supabaseRequest(
    `/rest/v1/orders?id=eq.${encodeURIComponent(orderId)}`,
    {
      method: 'PATCH',
      headers: {
        Prefer: 'return=minimal',
      },
      body: JSON.stringify(payload),
    },
  );

  if (!response.ok) {
    throw new Error(`update order failed: ${response.status} ${await response.text()}`);
  }
}

async function incrementPendingBalance(
  guideId: string,
  amount: number,
): Promise<void> {
  const response = await supabaseRequest('/rest/v1/rpc/increment_pending_balance', {
    method: 'POST',
    body: JSON.stringify({
      target_user_id: guideId,
      amount,
    }),
  });

  if (!response.ok) {
    throw new Error(
      `increment pending balance failed: ${response.status} ${await response.text()}`,
    );
  }
}

async function ensureChatRoom(
  orderId: string,
  participantIds: string[],
): Promise<void> {
  const existing = await supabaseRequest(
    `/rest/v1/chat_rooms?order_id=eq.${encodeURIComponent(
      orderId,
    )}&select=id&limit=1`,
  );

  if (!existing.ok) {
    throw new Error(`load chat room failed: ${existing.status} ${await existing.text()}`);
  }

  const rows = (await existing.json()) as Array<{ id: string }>;
  if (rows.length > 0) {
    return;
  }

  const response = await supabaseRequest('/rest/v1/chat_rooms', {
    method: 'POST',
    headers: {
      Prefer: 'return=minimal',
    },
    body: JSON.stringify({
      order_id: orderId,
      participant_ids: participantIds,
    }),
  });

  if (!response.ok) {
    throw new Error(`create chat room failed: ${response.status} ${await response.text()}`);
  }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return text('fail', 405);
  }

  const missing = requiredEnv.filter((name) => !Deno.env.get(name));
  if (missing.length > 0) {
    console.error('alipay notify missing env:', missing);
    return text('fail', 500);
  }

  try {
    const params = await parseRequestParams(req);
    console.log('alipay notify params:', params);

    const verified = await verifyAlipaySignature(
      params,
      Deno.env.get('ALIPAY_PUBLIC_KEY')!,
    );

    if (!verified) {
      console.error('alipay notify signature verify failed');
      return text('fail', 400);
    }

    const appId = params.app_id?.trim();
    const expectedAppId = Deno.env.get('ALIPAY_APP_ID')!.trim();
    if (appId != expectedAppId) {
      console.error('alipay notify app_id mismatch', { appId, expectedAppId });
      return text('fail', 400);
    }

    const merchantOrderNo = params.out_trade_no?.trim() ?? '';
    const tradeNo = params.trade_no?.trim() ?? '';
    const tradeStatus = params.trade_status?.trim() ?? '';
    const totalAmount = Number(params.total_amount ?? '0');

    if (!merchantOrderNo || !tradeNo || !tradeStatus || !(totalAmount > 0)) {
      console.error('alipay notify missing required business params', params);
      return text('fail', 400);
    }

    const order = await loadOrderByMerchantOrderNo(merchantOrderNo);
    if (!order) {
      console.error('alipay notify order not found', { merchantOrderNo });
      return text('fail', 404);
    }

    if (Number(order.amount).toFixed(2) !== totalAmount.toFixed(2)) {
      console.error('alipay notify amount mismatch', {
        orderId: order.id,
        orderAmount: order.amount,
        totalAmount,
      });
      return text('fail', 400);
    }

    if (tradeStatus === 'TRADE_SUCCESS' || tradeStatus === 'TRADE_FINISHED') {
      const alreadyPaid =
        order.payment_status === 'paid' &&
        order.provider_trade_no === tradeNo;

      if (!alreadyPaid) {
        await updateOrderPayment(order.id, {
          payment_status: 'paid',
          status: 1,
          payment_request_id: order.payment_request_id ?? merchantOrderNo,
          provider_trade_no: tradeNo,
          paid_at: new Date().toISOString(),
        });

        await incrementPendingBalance(order.guide_id, order.amount);

        const orderDetailResponse = await supabaseRequest(
          `/rest/v1/orders?id=eq.${encodeURIComponent(
            order.id,
          )}&select=user_id,guide_id&limit=1`,
        );
        if (!orderDetailResponse.ok) {
          throw new Error(
            `load order detail failed: ${orderDetailResponse.status} ${await orderDetailResponse.text()}`,
          );
        }
        const orderDetailRows = (await orderDetailResponse.json()) as Array<{
          user_id: string;
          guide_id: string;
        }>;
        const detail = orderDetailRows[0];
        if (detail?.user_id && detail?.guide_id) {
          await ensureChatRoom(order.id, [detail.user_id, detail.guide_id]);
        }
      }

      return text('success');
    }

    if (tradeStatus === 'TRADE_CLOSED') {
      await updateOrderPayment(order.id, {
        payment_status: 'closed',
        provider_trade_no: tradeNo || order.provider_trade_no,
      });
      return text('success');
    }

    console.warn('alipay notify ignored trade status', tradeStatus);
    return text('success');
  } catch (error) {
    console.error('alipay notify error:', error);
    return text('fail', 500);
  }
});
