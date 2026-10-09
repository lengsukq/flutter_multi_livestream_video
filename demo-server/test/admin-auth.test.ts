import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { Request, Response, NextFunction } from 'express';
import { createAdminAuth } from '../services/admin-auth.ts';

function harness(headers: Record<string, string> = {}, secure = false) {
  const received = new Map<string, string>();
  const req = {
    secure,
    protocol: secure ? 'https' : 'http',
    get: (name: string) => headers[name.toLowerCase()] ?? undefined,
  } as Request;
  const res = {
    setHeader: (name: string, value: string) => { received.set(name, value); },
    set: (name: string, value: string) => { received.set(name, value); return res; },
  } as unknown as Response;
  let nextCalled = false;
  const next = (() => { nextCalled = true; }) as NextFunction;
  return { req, res, next, received, wasAllowed: () => nextCalled };
}

function auth(errors: string[] = []) {
  return createAdminAuth({
    password: 'local-test-only',
    cookieName: 'session',
    sessionTtlSeconds: 3600,
    isVercel: false,
    nodeEnv: 'production',
    contractError: (_res, status, code) => {
      errors.push(`${status}:${code}`);
      return _res;
    },
  });
}

test('admin session cookie verifies signed expiry and denies tampering', () => {
  const suite = auth();
  const source = harness({ host: 'example.test' }, true);
  suite.setAdminCookie(source.res, source.req);
  const cookie = source.received.get('Set-Cookie')!;
  assert.match(cookie, /HttpOnly; SameSite=Strict/);
  assert.match(cookie, /; Secure/);
  const token = cookie.split(';')[0]!;
  assert.equal(suite.hasAdminSession(harness({ cookie: token }).req), true);
  assert.equal(suite.hasAdminSession(harness({ cookie: token + 'tampered' }).req), false);
  const alteredExpiry = token.replace(/\d{10}/, '1111111111');
  assert.equal(suite.hasAdminSession(harness({ cookie: alteredExpiry }).req), false);
});

test('admin and same-origin middleware reject unauthenticated and foreign-origin requests', () => {
  const errors: string[] = [];
  const suite = auth(errors);
  const unauthenticated = harness({ host: 'demo.test' });
  suite.requireAdmin(unauthenticated.req, unauthenticated.res, unauthenticated.next);
  assert.equal(unauthenticated.wasAllowed(), false);
  assert.deepEqual(errors, ['401:admin-auth-required']);
  const foreign = harness({ host: 'demo.test', origin: 'https://another.test' });
  suite.requireSameOrigin(foreign.req, foreign.res, foreign.next);
  assert.equal(foreign.wasAllowed(), false);
  assert.equal(errors.at(-1), '403:cross-origin-request');
  const matching = harness({ host: 'demo.test', origin: 'http://demo.test' });
  suite.requireSameOrigin(matching.req, matching.res, matching.next);
  assert.equal(matching.wasAllowed(), true);
});
