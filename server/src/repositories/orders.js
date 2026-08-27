export async function findOrderById(client, orderId) {
  const result = await client.query(
    `
      select
        id,
        user_id,
        guide_id,
        service_name,
        amount,
        status,
        payment_status,
        payment_method,
        payment_request_id,
        merchant_order_no,
        provider_trade_no
      from public.orders
      where id = $1
      limit 1
    `,
    [orderId],
  );

  return result.rows[0] ?? null;
}

export async function findOrderByMerchantOrderNo(client, merchantOrderNo) {
  const result = await client.query(
    `
      select
        id,
        user_id,
        guide_id,
        service_name,
        amount,
        status,
        payment_status,
        payment_method,
        payment_request_id,
        merchant_order_no,
        provider_trade_no
      from public.orders
      where merchant_order_no = $1
      limit 1
    `,
    [merchantOrderNo],
  );

  return result.rows[0] ?? null;
}

export async function updateOrderPayment(client, orderId, payload) {
  const fields = [];
  const values = [];

  const entries = Object.entries(payload);
  for (const [index, entry] of entries.entries()) {
    const [key, value] = entry;
    fields.push(`${key} = $${index + 1}`);
    values.push(value);
  }

  values.push(orderId);
  await client.query(
    `update public.orders set ${fields.join(', ')} where id = $${values.length}`,
    values,
  );
}

export async function ensureChatRoom(client, orderId, participantIds) {
  const existing = await client.query(
    `
      select id
      from public.chat_rooms
      where order_id = $1
      limit 1
    `,
    [orderId],
  );

  if (existing.rowCount && existing.rows[0]) {
    return existing.rows[0];
  }

  const created = await client.query(
    `
      insert into public.chat_rooms (participant_ids, order_id)
      values ($1::uuid[], $2)
      returning id
    `,
    [participantIds, orderId],
  );

  return created.rows[0] ?? null;
}
