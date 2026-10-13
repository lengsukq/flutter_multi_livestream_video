import AC from 'agora-chat';
import { createAgoraChatBridge } from './agora-chat-entry.js';

const pendingTokenRequests = new Map();
let nextTokenRequestId = 0;

function post(message) {
  globalThis.webkit?.messageHandlers?.flutterAgoraChat?.postMessage(message);
}

globalThis.__flutterAgoraChatOnEvent = (sessionId, eventType, payload) => {
  post({ kind: 'event', sessionId, eventType, payload });
};

globalThis.__flutterAgoraChatRequestToken = (sessionId) =>
  new Promise((resolve, reject) => {
    const requestId = `token_${nextTokenRequestId++}`;
    pendingTokenRequests.set(requestId, { resolve, reject });
    post({ kind: 'tokenRequest', requestId, sessionId });
  });

globalThis.__flutterAgoraChatResolveToken = (requestId, response) => {
  const pending = pendingTokenRequests.get(String(requestId));
  if (!pending) return;
  pendingTokenRequests.delete(String(requestId));
  if (response?.error) {
    pending.reject(new Error(String(response.error)));
    return;
  }
  if (!response?.token) {
    pending.reject(new Error('Agora Chat token refresh returned no token.'));
    return;
  }
  pending.resolve(JSON.stringify({ token: response.token }));
};

globalThis.AgoraChatBridge = createAgoraChatBridge(AC, globalThis);
post({ kind: 'ready' });
