export async function ensureWallet(client, userId) {
  await client.query(
    `
      insert into public.wallets (user_id)
      values ($1)
      on conflict (user_id) do nothing
    `,
    [userId],
  );
}

export async function incrementPendingBalance(client, userId, amount) {
  await ensureWallet(client, userId);
  await client.query(
    `
      update public.wallets
      set
        pending_balance = coalesce(pending_balance, 0) + $2,
        total_earned = coalesce(total_earned, 0) + $2,
        updated_at = now()
      where user_id = $1
    `,
    [userId, amount],
  );
}

export async function recordWalletTransaction(client, {
  userId,
  orderId,
  type = 'income',
  amount,
  platformFee = 0,
  actualAmount,
  description = '',
}) {
  await client.query(
    `
      insert into public.transactions (
        user_id, order_id, type, amount, platform_fee, actual_amount, description
      ) values ($1,$2,$3,$4,$5,$6,$7)
    `,
    [
      userId,
      orderId,
      type,
      amount,
      platformFee,
      actualAmount ?? amount,
      description,
    ],
  );
}
