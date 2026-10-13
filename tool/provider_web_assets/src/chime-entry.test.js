import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';
import { runInNewContext } from 'node:vm';

const bundleRoot = resolve(import.meta.dirname, '../../../packages');

for (const file of [
  'flutter_realtime_provider_aws/assets/chime-sdk.js',
]) {
  test(`bundled ${file} exports working Chime constructors to WebKit`, () => {
    const context = {
      globalThis: {},
      console,
      navigator: { userAgent: 'Mozilla/5.0 Chrome/120', mediaDevices: {} },
      self: {}, window: {},
      setTimeout, clearTimeout, setInterval, clearInterval,
    };
    runInNewContext(readFileSync(resolve(bundleRoot, file), 'utf8'), context, {
      timeout: 2000,
    });
    const sdk = context.globalThis.ChimeSDK;
    assert.ok(sdk, 'ChimeSDK global must exist');
    for (const name of [
      'ConsoleLogger', 'DefaultDeviceController',
      'MeetingSessionConfiguration', 'DefaultMeetingSession',
    ]) {
      assert.equal(typeof sdk[name], 'function', `${name} must be a constructor`);
    }
    assert.equal(typeof sdk.LogLevel, 'object');
    assert.equal(typeof sdk.LogLevel.WARN, 'number');
    assert.ok(sdk.MeetingSessionStatusCode, 'Chime stop observer uses status codes');
    assert.notEqual(sdk.MeetingSessionStatusCode.Left, undefined);
    assert.doesNotThrow(() => new sdk.ConsoleLogger('bundle-smoke-test', sdk.LogLevel.WARN));
  });
}
