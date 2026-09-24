import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';

test('dashboard provider switcher is metadata-driven and its script parses', async () => {
  const html = await readFile(
    path.resolve(import.meta.dirname, '..', 'public', 'index.html'),
    'utf8',
  );

  assert.match(html, /id="provider-switcher"/);
  assert.match(html, /d\.providerList/);
  assert.match(html, /renderProviderSwitcher\(d\.activeProvider\)/);

  for (const hardcodedFlow of [
    'provider-livekit',
    'provider-agora',
    'provider-chime',
    'provider-trtc',
    'isLiveKit',
    'isAgora',
    'isTrtc',
    'isChime',
  ]) {
    assert.equal(html.includes(hardcodedFlow), false, `dashboard still hardcodes ${hardcodedFlow}`);
  }

  const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);
  assert.ok(scriptMatch, 'dashboard inline script not found');
  assert.doesNotThrow(() => new Function(scriptMatch[1]!));
});
