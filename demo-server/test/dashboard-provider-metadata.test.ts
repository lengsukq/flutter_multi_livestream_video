import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';

test('dashboard provider switcher is metadata-driven and its script parses', async () => {
  const shell = await readFile(
    path.resolve(import.meta.dirname, '..', 'public', 'index.html'),
    'utf8',
  );

  const directory = path.resolve(import.meta.dirname, '..', 'public', 'dashboard');
  const modules = await Promise.all((await readdir(directory)).filter((name) => name.endsWith('.js')).map((name) => readFile(path.join(directory, name), 'utf8')));
  const html = shell + modules.join('\n');
  assert.match(shell, /type="module" src="\/dashboard\/dashboard.js"/);
  assert.match(html, /id="provider-switcher"/);
  assert.match(html, /id="provider-capability-matrix"/);
  assert.match(html, /id="media-capability-details"/);
  assert.match(html, /id="chat-provider-switcher"/);
  assert.match(html, /id="chat-provider-capability-matrix"/);
  assert.match(html, /id="chat-capability-details"/);
  assert.match(html, /id="standalone-chat-rooms"/);
  assert.match(html, /renderStandaloneChatRoomsTable\(\)/);
  assert.match(html, /promptCloseChatRoom\(this\)/);
  assert.match(html, /\/api\/chat\/cloud-rooms/);
  assert.match(html, /d\.providerList/);
  assert.match(html, /d\.chatProviderList/);
  assert.match(html, /renderProviderSwitcher\(d\.activeProvider\)/);
  assert.match(html, /renderProviderCapabilityMatrix\(activeProvider\)/);
  assert.match(html, /provider\.capabilities/);
  assert.match(html, /capabilityTooltipElement\.className = 'capability-tooltip'/);
  assert.match(
    html,
    /renderChatProviderSwitcher\(d\.activeChatProvider \|\| null\)/,
  );
  assert.match(html, /renderChatProviderCapabilityMatrix\(activeProvider\)/);
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

  assert.match(html, /function updateCapabilityTooltip\(\)/);
  assert.match(html, /function executeCloseChatRoom\(\)/);
  for (const module of modules) {
    const body = module.replace(/^import[^;]+;\n/gm, '').replace(/\bexport /g, '');
    assert.doesNotThrow(() => new Function(body));
  }

});

test('dashboard cloud chat management routes require admin authentication', async () => {
  const chatRoutes = await readFile(
    path.resolve(import.meta.dirname, '..', 'routes', 'chat-routes.ts'),
    'utf8',
  );
  assert.match(
    chatRoutes,
    /app\.get\('\/api\/chat\/cloud-rooms', requireAdmin/,
  );
  assert.match(
    chatRoutes,
    /'\/api\/chat\/cloud-rooms\/:provider\/:roomId'/,
  );
  const cloudRoomService = await readFile(path.resolve(import.meta.dirname, '..', 'services', 'chat', 'delete-api-chat-cloud-rooms-by-provider-by-roomid.ts'), 'utf8');
  assert.match(cloudRoomService, /provider\.deleteCloudRoom\(providerRoomId\)/);
});

test('chat-token route is protected by the shared room middleware', async () => {
  const server = await readFile(
    path.resolve(import.meta.dirname, '..', 'app.ts'),
    'utf8',
  );
  const middlewareIndex = server.indexOf("app.use('/rooms'");
  const registerIndex = server.indexOf('registerRoomRoutes(app');
  const roomRoutes = await readFile(
    path.resolve(import.meta.dirname, '..', 'routes', 'room-routes.ts'),
    'utf8',
  );

  assert.notEqual(middlewareIndex, -1, 'room middleware was not found');
  assert.notEqual(registerIndex, -1, 'room routes were not registered');
  assert.match(roomRoutes, /app\.post\('\/rooms\/:code\/chat\/token'/);
  assert.ok(
    middlewareIndex < registerIndex,
    'chat-token route must be registered after the shared /rooms middleware',
  );
});
