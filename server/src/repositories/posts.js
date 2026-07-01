const POST_SELECT = `
  select
    p.id,
    p.user_id,
    p.author_name,
    p.author_avatar,
    p.content,
    p.images,
    p.location,
    coalesce(p.likes, 0) as likes,
    (
      select count(*)
      from public.post_comments pc
      where pc.post_id = p.id
    )::int as comments,
    p.created_at
  from public.posts p
`;

export async function listPosts(client, { query }) {
  const params = [];
  let where = '';
  if (query) {
    params.push(`%${query}%`);
    where =
      `where p.content ilike $1 or p.author_name ilike $1 or p.location ilike $1`;
  }

  const result = await client.query(
    `
      ${POST_SELECT}
      ${where}
      order by p.created_at desc
    `,
    params,
  );
  return result.rows;
}

export async function listPostsByUser(client, userId) {
  const result = await client.query(
    `
      ${POST_SELECT}
      where p.user_id = $1
      order by p.created_at desc
    `,
    [userId],
  );
  return result.rows;
}

export async function createPost(client, payload) {
  const result = await client.query(
    `
      insert into public.posts (
        user_id, author_name, author_avatar, content, images, location, likes, comments
      )
      values ($1, $2, $3, $4, $5::text[], $6, 0, 0)
      returning *
    `,
    [
      payload.user_id,
      payload.author_name,
      payload.author_avatar,
      payload.content,
      payload.images ?? [],
      payload.location ?? '',
    ],
  );
  return result.rows[0] ?? null;
}

export async function updatePostLikes(client, postId, likes) {
  await client.query(
    `
      update public.posts
      set likes = $2
      where id = $1
    `,
    [postId, likes],
  );
}

export async function findPostById(client, postId) {
  const result = await client.query(
    `
      ${POST_SELECT}
      where p.id = $1
      limit 1
    `,
    [postId],
  );
  return result.rows[0] ?? null;
}
