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
        updated_at = now()
      where user_id = $1
    `,
    [userId, amount],
  );
}
