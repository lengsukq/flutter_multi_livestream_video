import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import test from 'node:test';
import { buildArtcAuthInfo } from '../artc-token.ts';
import { createArtcProvider, normalizeArtcTokenTtl } from '../providers/artc.ts';
import { ProviderOperationError, ProviderRegistry } from '../providers/provider-registry.ts';

const appKey = 'test-only-artc-app-key-not-for-response';

test('ARTC single-parameter auth info signs the app, channel, user, and expiry', () => {
  const expiresAtSeconds = Math.floor(Date.now() / 1000) + 600;
  const authInfo = buildArtcAuthInfo({
    appId: 'demo-app',
    appKey,
    channelId: 'media-room01',
    userId: 'u-person1',
    expiresAtSeconds,
  });
  const parsed = JSON.parse(Buffer.from(authInfo, 'base64').toString('utf8')) as Record<string, unknown>;
  const expectedSignature = createHash('sha256')
    .update(`demo-app${appKey}media-room01u-person1${expiresAtSeconds}`)
    .digest('hex');

  assert.deepEqual(parsed, {
    appid: 'demo-app',
    channelid: 'media-room01',
    userid: 'u-person1',
    nonce: '',
    timestamp: expiresAtSeconds,
    token: expectedSignature,
  });
  assert.equal(authInfo.includes(appKey), false);
});

test('ARTC token TTL defaults safely and rejects invalid ranges', () => {
  assert.equal(normalizeArtcTokenTtl(undefined), 600);
  assert.equal(normalizeArtcTokenTtl('120'), 120);
  assert.throws(() => normalizeArtcTokenTtl('59'), /between 60 and 86400/);
  assert.throws(() => normalizeArtcTokenTtl('not-a-number'), /between 60 and 86400/);
});

test('ARTC provider reports missing signing configuration before room creation', () => {
  const provider = createArtcProvider({
    env: {},
    contractVersion: 1,
    normalizeDisplayName: (raw) => String(raw ?? '').trim(),
  });
  const registry = new ProviderRegistry([provider]);

  assert.equal(provider.isConfigured(), false);
  assert.throws(
    () => registry.requireConfigured('artc'),
    (error) =>
      error instanceof ProviderOperationError &&
      error.status === 503 &&
      error.code === 'provider-not-configured' &&
      error.message.includes('ARTC_APP_ID and ARTC_APP_KEY'),
  );
});
