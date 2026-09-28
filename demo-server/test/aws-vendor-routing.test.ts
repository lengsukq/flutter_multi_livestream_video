import assert from 'node:assert/strict';
import test from 'node:test';

import {
  AWS_LIVE_ENGINE,
  AWS_MEETING_ENGINE,
  AWS_VENDOR_ID,
  awsEngineForRoomMode,
  isAwsEngine,
  publicVendorForEngine,
} from '../providers/aws.ts';

test('AWS routes Meeting to Chime and Live to IVS', () => {
  assert.equal(awsEngineForRoomMode('meeting'), AWS_MEETING_ENGINE);
  assert.equal(awsEngineForRoomMode('broadcast'), AWS_LIVE_ENGINE);
});

test('Chime and IVS engines expose AWS as their public vendor', () => {
  assert.equal(isAwsEngine('chime'), true);
  assert.equal(isAwsEngine('ivs'), true);
  assert.equal(publicVendorForEngine('chime'), AWS_VENDOR_ID);
  assert.equal(publicVendorForEngine('ivs'), AWS_VENDOR_ID);
  assert.equal(publicVendorForEngine('livekit'), 'livekit');
});
