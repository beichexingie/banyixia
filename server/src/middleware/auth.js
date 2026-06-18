import { fail } from '../utils/http.js';

function extractBearerToken(headerValue) {
  if (!headerValue) return '';
  const value = Array.isArray(headerValue) ? headerValue[0] : headerValue;
  const match = value.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : '';
}

export function readAuthToken(req) {
  return (
    extractBearerToken(req.headers.authorization) ||
    req.headers['x-auth-token']?.toString().trim() ||
    req.headers['x-user-token']?.toString().trim() ||
    ''
  );
}

export function requireAuth(req, res, next) {
  const token = readAuthToken(req);
  if (!token) {
    return fail(res, 401, '未登录');
  }
  req.authToken = token;
  return next();
}

export function requireAdmin(_req, _res, next) {
  return next();
}
