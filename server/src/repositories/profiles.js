export async function incrementFollowCount(client, userId, delta) {
  await client.query(
    `
      update public.users
      set follow_count = greatest(coalesce(follow_count, 0) + $2, 0)
      where id = $1
    `,
    [userId, delta],
  );
}

export async function incrementFanCount(client, userId, delta) {
  await client.query(
    `
      update public.users
      set fans_count = greatest(coalesce(fans_count, 0) + $2, 0)
      where id = $1
    `,
    [userId, delta],
  );
}

