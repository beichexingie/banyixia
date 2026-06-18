export async function listPosts(client, { query }) {
  const params = [];
  let where = '';
  if (query) {
    params.push(`%${query}%`);
    where = `where content ilike $1 or author_name ilike $1 or location ilike $1`;
  }

  const result = await client.query(
    `
      select *
      from public.posts
      ${where}
      order by created_at desc
    `,
    params,
  );
  return result.rows;
}

export async function listPostsByUser(client, userId) {
  const result = await client.query(
    `
      select *
      from public.posts
      where user_id = $1
      order by created_at desc
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
      select *
      from public.posts
      where id = $1
      limit 1
    `,
    [postId],
  );
  return result.rows[0] ?? null;
}

