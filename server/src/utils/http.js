export function ok(res, data = {}) {
  return res.status(200).json({ success: true, ...data });
}

export function fail(res, status, message, extra = {}) {
  return res.status(status).json({
    success: false,
    message,
    ...extra,
  });
}
