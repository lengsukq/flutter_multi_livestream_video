import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeAvatarUrl, publicParticipantProfiles} from '../services/participant-profile.ts';

test('avatar links are optional HTTP references and are never fetched by the server', () => {
  assert.equal(normalizeAvatarUrl(' https://avatar.test/photo.png '), 'https://avatar.test/photo.png');
  assert.equal(normalizeAvatarUrl(' '), undefined);
  for (const value of ['file:///tmp/a.png', 'data:image/png;base64,a', 'https://user:secret@avatar.test/a', 42]) {
    assert.throws(() => normalizeAvatarUrl(value));
  }
});
test('public participant profiles include images and exclude authority credentials', () => {
  assert.deepEqual(publicParticipantProfiles({attendees: [{attendeeId: 'p1', externalUserId: 'u1',
    displayName: '小明', avatarUrl: 'https://avatar.test/a.png', joinedAt: '', participantCredentialHash: 'private'}]}),
    [{participantId: 'p1', displayName: '小明', avatarUrl: 'https://avatar.test/a.png'}]);
});
