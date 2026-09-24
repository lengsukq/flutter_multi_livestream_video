import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildAgoraRtcToken,
  normalizeAgoraTokenTtl,
} from '../agora-token.mjs';

test('Agora token TTL is bounded and has a safe default', () => {
  assert.equal(normalizeAgoraTokenTtl(undefined), 600);
  assert.equal(normalizeAgoraTokenTtl(1), 60);
  assert.equal(normalizeAgoraTokenTtl(120), 120);
  assert.equal(normalizeAgoraTokenTtl(1000000), 86400);
});

test('builds an AccessToken2 token without exposing the certificate', () => {
  const certificate = 'abcdef0123456789abcdef0123456789';
  const token = buildAgoraRtcToken({
    appId: '0123456789abcdef0123456789abcdef',
    appCertificate: certificate,
    channelName: 'media-test',
    uid: 123,
    role: 'host',
    ttlSeconds: 600,
  });

  assert.equal(typeof token, 'string');
  assert.ok(token.length > 80);
  assert.equal(token.includes(certificate), false);
});

test('viewer and publisher tokens use different role grants', () => {
  const common = {
    appId: '0123456789abcdef0123456789abcdef',
    appCertificate: 'abcdef0123456789abcdef0123456789',
    channelName: 'media-test',
    uid: 123,
    ttlSeconds: 600,
  };
  const viewer = buildAgoraRtcToken({ ...common, role: 'viewer' });
  const host = buildAgoraRtcToken({ ...common, role: 'host' });

  assert.notEqual(viewer, host);
});
