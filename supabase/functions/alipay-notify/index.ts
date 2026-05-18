Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('fail', { status: 405 });
  }

  const payload = await req.text().catch(() => '');
  console.log('alipay notify payload:', payload);

  return new Response('success', {
    status: 200,
    headers: { 'Content-Type': 'text/plain' },
  });
});
