function buildPostSelect({ viewerIdParam = null } = {}) {
  const viewerStateSelect = viewerIdParam
    ? `
    exists(
      select 1
      from public.post_likes vpl
      where vpl.user_id = ${viewerIdParam} and vpl.post_id = p.id
    ) as is_liked,
    exists(
      select 1
      from public.post_favorites vpf
      where vpf.user_id = ${viewerIdParam} and vpf.post_id = p.id
    ) as is_favorited,
`
    : `
    false as is_liked,
    false as is_favorited,
`;

  return `
  select
    p.id,
    p.user_id,
    p.author_name,
    p.author_avatar,
    p.content,
    p.images,
    p.location,
    (
      select count(*)
      from public.post_likes pl
      where pl.post_id = p.id
    )::int as likes,
    (
      select count(*)
      from public.post_favorites pf
      where pf.post_id = p.id
    )::int as favorites,
    (
      select count(*)
      from public.post_comments pc
      where pc.post_id = p.id
    )::int as comments,
    ${viewerStateSelect}
    p.review_status,
    p.reject_reason,
    p.created_at
  from public.posts p
`;
}

export async function listPosts(client, { query, viewerId = '' }) {
  const params = [];
  const normalizedViewerId = viewerId?.toString().trim() ?? '';
  const viewerIdParam = normalizedViewerId
    ? `$${params.push(normalizedViewerId)}`
    : null;
  let where = '';
  if (query) {
    const queryParam = `$${params.push(`%${query}%`)}`;
    where =
      `where p.content ilike ${queryParam} or p.author_name ilike ${queryParam} or p.location ilike ${queryParam}`;
  }

  const result = await client.query(
    `
      ${buildPostSelect({ viewerIdParam })}
      ${where}
      order by p.created_at desc
    `,
    params,
  );
  return result.rows;
}

export async function listPostsByUser(client, userId, viewerId = '') {
  const params = [];
  const normalizedViewerId = viewerId?.toString().trim() ?? '';
  const viewerIdParam = normalizedViewerId
    ? `$${params.push(normalizedViewerId)}`
    : null;
  const authorIdParam = `$${params.push(userId)}`;
  const result = await client.query(
    `
      ${buildPostSelect({ viewerIdParam })}
      where p.user_id = ${authorIdParam}
      order by p.created_at desc
    `,
    params,
  );
  return result.rows;
}

export async function createPost(client, payload) {
  const result = await client.query(
    `
      insert into public.posts (
        user_id, author_name, author_avatar, content, images, location,
        likes, comments, review_status, reject_reason, moderation_hits, moderation_source
      )
      values ($1, $2, $3, $4, $5::text[], $6, 0, 0, $7, $8, $9::text[], $10)
      returning *
    `,
    [
      payload.user_id,
      payload.author_name,
      payload.author_avatar,
      payload.content,
      payload.images ?? [],
      payload.location ?? '',
      payload.review_status ?? 'approved',
      payload.reject_reason ?? null,
      payload.moderation_hits ?? [],
      payload.moderation_source ?? null,
    ],
  );
  return result.rows[0] ?? null;
}

export async function updatePostLikes(client, postId, delta) {
  await client.query(
    `
      update public.posts
      set likes = greatest(coalesce(likes, 0) + $2, 0)
      where id = $1
    `,
    [postId, delta],
  );
}

export async function findPostById(client, postId, viewerId = '') {
  const params = [];
  const normalizedViewerId = viewerId?.toString().trim() ?? '';
  const viewerIdParam = normalizedViewerId
    ? `$${params.push(normalizedViewerId)}`
    : null;
  const postIdParam = `$${params.push(postId)}`;
  const result = await client.query(
    `
      ${buildPostSelect({ viewerIdParam })}
      where p.id = ${postIdParam}
      limit 1
    `,
    params,
  );
  return result.rows[0] ?? null;
}
