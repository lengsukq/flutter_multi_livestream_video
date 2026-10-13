import assert from 'node:assert/strict';
import { once } from 'node:events';
import test from 'node:test';
import { createDemoApplication } from '../app.ts';

test('application factory owns an explicit idempotent listener lifecycle', async () => {
  const runtime = await createDemoApplication({
    AWS_REGION: 'us-east-1', VERCEL: '1', MEDIA_CONNECTIONS_ENABLED: 'false',
    MEDIA_PROVIDER_STATE_PATH: '/tmp/realtime-clean-code-test-provider-state.json',
  });
  const listener = runtime.start(0);
  assert.equal(runtime.start(0), listener);
  await once(listener, 'listening');
  const address = listener.address();
  assert.ok(address && typeof address === 'object');
  const shell = await fetch(`http://127.0.0.1:${address.port}/`);
  assert.equal(shell.status, 200);
  assert.match(await shell.text(), /type="module" src="\/dashboard\/dashboard.js"/);
  const module = await fetch(`http://127.0.0.1:${address.port}/dashboard/dashboard.js`);
  assert.equal(module.status, 200);
  const first = runtime.stop();
  assert.equal(runtime.stop(), first);
  await first;
  assert.equal(listener.listening, false);
});
