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
  assert.match(html, /id="provider-capability-matrix"/);
  assert.match(html, /id="capability-detail-modal"/);
  assert.match(html, /id="chat-provider-switcher"/);
  assert.match(html, /d\.providerList/);
  assert.match(html, /d\.chatProviderList/);
  assert.match(html, /renderProviderSwitcher\(d\.activeProvider\)/);
  assert.match(html, /renderProviderCapabilityMatrix\(activeProvider\)/);
  assert.match(html, /provider\.capabilities/);
  assert.match(html, /onclick="showCapabilityDetail\(this\)"/);
  assert.match(html, /function showCapabilityDetail\(button\)/);
  assert.match(
    html,
    /renderChatProviderSwitcher\(d\.activeChatProvider \|\| null\)/,
  );
  assert.match(html, /switchChatProvider\(this\.dataset\.provider\)/);
  assert.match(html, /CHAT_DEFAULT_PROVIDER/);

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

test('chat-token route is protected by the shared room middleware', async () => {
  const server = await readFile(
    path.resolve(import.meta.dirname, '..', 'server.ts'),
    'utf8',
  );
  const middlewareIndex = server.indexOf("app.use('/rooms'");
  const chatTokenIndex = server.indexOf("app.post('/rooms/:code/chat/token'");

  assert.notEqual(middlewareIndex, -1, 'room middleware was not found');
  assert.notEqual(chatTokenIndex, -1, 'chat-token route was not found');
  assert.ok(
    middlewareIndex < chatTokenIndex,
    'chat-token route must be registered after the shared /rooms middleware',
  );
});
