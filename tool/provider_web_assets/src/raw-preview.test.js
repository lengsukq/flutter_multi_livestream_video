import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import { build } from 'esbuild';

async function harness() {
  let captures = 0, stops = 0;
  const context = vm.createContext({console, setTimeout, clearTimeout, setInterval, clearInterval,
    navigator: {mediaDevices: {
      async enumerateDevices() { return []; },
      async getUserMedia() { captures++; const track = {id: 'raw', stop() { stops++; }}; return {getTracks: () => [track], getVideoTracks: () => [track]}; },
    }},
  });
  const result = await build({entryPoints: [new URL('./bridge.js', import.meta.url).pathname], bundle: true, write: false, format: 'iife'});
  vm.runInContext(result.outputFiles[0].text, context);
  return {bridge: context.MediaProviderBridge, counts: () => ({captures, stops})};
}

test('a minimal preview acquires video only on enable and stops it on disable', async () => {
 const {bridge, counts} = await harness();
 await bridge.createLocalPreview('agora', 'preview', {cameraEnabled: false, microphoneEnabled: false});
 assert.deepEqual(counts(), {captures: 0, stops: 0});
 await bridge.command('agora', 'preview', 'listDevices', {});
 await bridge.command('agora', 'preview', 'selectDevice', {device: {kind: 'camera', id: 'camera-2'}});
 assert.deepEqual(counts(), {captures: 0, stops: 0});
 await bridge.command('agora', 'preview', 'setVideoEnabled', {enabled: true});
 assert.deepEqual(counts(), {captures: 1, stops: 0});
 await bridge.command('agora', 'preview', 'setVideoEnabled', {enabled: false});
 assert.deepEqual(counts(), {captures: 1, stops: 1});
 await bridge.command('agora', 'preview', 'setVideoEnabled', {enabled: true});
 await bridge.dispose('agora', 'preview');
 assert.deepEqual(counts(), {captures: 2, stops: 2});
});
