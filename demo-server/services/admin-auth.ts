import crypto from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';

export interface AdminAuthDependencies {
  password: string;
  cookieName: string;
  sessionTtlSeconds: number;
  isVercel: boolean;
  nodeEnv?: string;
  contractError(res: Response, status: number, code: string, message: string): Response;
}

/** Same-origin admin authentication; all secrets remain in process-only config. */
export function createAdminAuth(deps: AdminAuthDependencies) {
  const {
    password: MEDIA_ADMIN_PASSWORD, cookieName: ADMIN_SESSION_COOKIE,
    sessionTtlSeconds: ADMIN_SESSION_TTL_SECONDS, isVercel: IS_VERCEL,
    nodeEnv: NODE_ENV, contractError,
  } = deps;

function getCookie(req: Request, name: string): string | null {
  const header = req.get('Cookie');
  if (!header) return null;
  for (const pair of header.split(';')) {
    const separator = pair.indexOf('=');
    if (separator < 0 || pair.slice(0, separator).trim() !== name) continue;
    const value = pair.slice(separator + 1).trim();
    try { return decodeURIComponent(value); } catch (_) { return value; }
  }
  return null;
}

function adminSessionSignature(expiresAtSeconds: string): string {
  return crypto.createHmac('sha256', MEDIA_ADMIN_PASSWORD).update(expiresAtSeconds).digest('base64url');
}

function hasAdminSession(req: Request): boolean {
  if (!MEDIA_ADMIN_PASSWORD) return false;
  const token = getCookie(req, ADMIN_SESSION_COOKIE);
  if (!token) return false;
  const [expiresAtSeconds, signature, ...extra] = token.split('.');
  if (extra.length || !expiresAtSeconds || !/^\d{10}$/.test(expiresAtSeconds) || !signature) return false;
  if (Number(expiresAtSeconds) <= Math.floor(Date.now() / 1000)) return false;
  const supplied = Buffer.from(signature, 'base64url');
  const expected = Buffer.from(adminSessionSignature(expiresAtSeconds), 'base64url');
  return supplied.length === expected.length && crypto.timingSafeEqual(supplied, expected);
}

function setAdminCookie(res: Response, req: Request): void {
  const expiresAtSeconds = String(Math.floor(Date.now() / 1000) + ADMIN_SESSION_TTL_SECONDS);
  const secure = IS_VERCEL || req.secure;
  res.setHeader(
    'Set-Cookie',
    `${ADMIN_SESSION_COOKIE}=${expiresAtSeconds}.${adminSessionSignature(expiresAtSeconds)}; Path=/; HttpOnly; SameSite=Strict; Max-Age=${ADMIN_SESSION_TTL_SECONDS}${secure ? '; Secure' : ''}`,
  );
}

function clearAdminCookie(res: Response, req: Request): void {
  const secure = IS_VERCEL || req.secure;
  res.setHeader(
    'Set-Cookie',
    `${ADMIN_SESSION_COOKIE}=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0${secure ? '; Secure' : ''}`,
  );
}

function requireSameOrigin(req: Request, res: Response, next: NextFunction): Response | void {
  const origin = req.get('Origin');
  if (!origin) return next();
  const protocol = req.get('x-forwarded-proto')?.split(',')[0]?.trim() || req.protocol;
  const expectedOrigin = `${protocol}://${req.get('host')}`;
  try {
    if (new URL(origin).origin === expectedOrigin) return next();
  } catch (_) {
    // Invalid Origin headers are rejected below.
  }
  return contractError(res, 403, 'cross-origin-request', 'Admin actions must come from this site.');
}

function requireAdmin(req: Request, res: Response, next: NextFunction): Response | void {
  res.set('Cache-Control', 'no-store');
  if (!MEDIA_ADMIN_PASSWORD && !IS_VERCEL && NODE_ENV !== 'production') return next();
  if (!MEDIA_ADMIN_PASSWORD) {
    return contractError(res, 503, 'admin-not-configured', 'Set MEDIA_ADMIN_PASSWORD before using admin routes.');
  }
  if (!hasAdminSession(req)) {
    return contractError(res, 401, 'admin-auth-required', 'Sign in to manage this service.');
  }
  next();
}

  return { hasAdminSession, setAdminCookie, clearAdminCookie, requireSameOrigin, requireAdmin };
}
