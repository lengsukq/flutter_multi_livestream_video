import assert from 'node:assert/strict';
import { inflateSync } from 'node:zlib';
import test from 'node:test';

import {
  buildTrtcCredentials,
  TRTC_PUBLISHER_PRIVILEGES,
  TRTC_VIEWER_PRIVILEGES,
} from '../trtc-token.ts';

const secretKey = 'test-only-trtc-secret-never-returned';

function decodeSig(value: string): Record<string, unknown> {
  const encoded = value.replace(/_/g, '=').replace(/-/g, '/').replace(/\*/g, '+');
  return JSON.parse(inflateSync(Buffer.from(encoded, 'base64')).toString('utf8')) as Record<string, unknown>;
}

function readRoomPrivileges(privateMapKey: string, userId: string) {
  const document = decodeSig(privateMapKey);
  const userBuffer = Buffer.from(String(document['TLS.userbuf']), 'base64');
  return {
    privileges: userBuffer.readUInt32BE(15 + userId.length),
    expiresAt: userBuffer.readUInt32BE(11 + userId.length),
    strRoomId: userBuffer.subarray(25 + userId.length).toString('utf8'),
  };
}

test('signs short-lived credentials for one user and string room without returning the secret', () => {
  const now = Math.floor(Date.now() / 1000);
  const credentials = buildTrtcCredentials({
    sdkAppId: 1400000000,
    secretKey,
    userId: 'user-01',
    strRoomId: 'media-room01',
    ttlSeconds: 600,
    role: 'host',
  });
  const userSig = decodeSig(credentials.userSig);
  const roomPermissions = readRoomPrivileges(credentials.privateMapKey, 'user-01');

  assert.equal(userSig['TLS.sdkappid'], 1400000000);
  assert.equal(userSig['TLS.identifier'], 'user-01');
  assert.equal(userSig['TLS.expire'], 600);
  assert.equal(roomPermissions.privileges, TRTC_PUBLISHER_PRIVILEGES);
  assert.equal(roomPermissions.strRoomId, 'media-room01');
  assert.ok(roomPermissions.expiresAt >= now + 595);
  assert.ok(roomPermissions.expiresAt <= now + 605);
  assert.equal(JSON.stringify(credentials).includes(secretKey), false);
});

test('viewer PrivateMapKey includes entry and receive rights but no publish rights', () => {
  const credentials = buildTrtcCredentials({
    sdkAppId: 1400000000,
    secretKey,
    userId: 'viewer-1',
    strRoomId: 'media-room02',
    ttlSeconds: 600,
    role: 'viewer',
  });
  const roomPermissions = readRoomPrivileges(credentials.privateMapKey, 'viewer-1');

  assert.equal(roomPermissions.privileges, TRTC_VIEWER_PRIVILEGES);
  assert.equal(roomPermissions.privileges & (4 | 16 | 64), 0);
  assert.notEqual(credentials.privateMapKey, '');
});

test('rejects unsafe identifiers, unsupported roles, and impractical TTLs', () => {
  const common = {
    sdkAppId: 1400000000,
    secretKey,
    userId: 'user-01',
    strRoomId: 'media-room01',
    ttlSeconds: 600,
    role: 'participant',
  };
  assert.throws(() => buildTrtcCredentials({ ...common, userId: 'x'.repeat(33) }));
  assert.throws(() => buildTrtcCredentials({ ...common, role: 'admin' }));
  assert.throws(() => buildTrtcCredentials({ ...common, ttlSeconds: 30 }));
});
