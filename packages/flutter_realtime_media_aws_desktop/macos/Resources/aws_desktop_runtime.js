(function installAwsDesktopRuntime(global) {
  'use strict';

  const native = global.webkit && global.webkit.messageHandlers
    ? global.webkit.messageHandlers.awsDesktop
    : null;
  const bindings = new Map();
  const snapshots = new Map();
  const pendingChatTokens = new Map();
  let nextChatTokenRequestId = 0;

  function post(value) {
    if (native) native.postMessage(value);
  }

  global.__flutterMediaProviderOnEvent = function(sessionId, serializedEvent) {
    let event;
    try {
      event = typeof serializedEvent === 'string'
        ? JSON.parse(serializedEvent)
        : serializedEvent;
    } catch (error) {
      event = { type: 'error', message: String(error) };
    }
    if (event && event.type === 'snapshot') snapshots.set(sessionId, event);
    post({ kind: 'event', sessionId: sessionId, event: event });
  };

  global.__flutterIvsChatOnEvent = function(sessionId, type, serializedPayload) {
    let payload;
    try {
      payload = typeof serializedPayload === 'string'
        ? JSON.parse(serializedPayload)
        : serializedPayload;
    } catch (error) {
      payload = { type: 'error', code: -1, message: String(error) };
    }
    post({
      kind: 'chatEvent',
      sessionId: sessionId,
      event: Object.assign({ type: type }, payload || {}),
    });
  };

  global.__flutterIvsChatRequestToken = function(sessionId) {
    return new Promise(function(resolve, reject) {
      const requestId = 'ivs-chat-token-' + String(++nextChatTokenRequestId);
      const timeout = global.setTimeout(function() {
        pendingChatTokens.delete(requestId);
        reject(new Error('Timed out waiting for refreshed IVS Chat credentials.'));
      }, 30000);
      pendingChatTokens.set(requestId, {
        resolve: resolve,
        reject: reject,
        timeout: timeout,
      });
      post({
        kind: 'chatTokenRequest',
        requestId: requestId,
        sessionId: sessionId,
      });
    });
  };

  function requireBridge() {
    if (!global.MediaProviderBridge) {
      throw new Error('MediaProviderBridge is unavailable in the AWS desktop runtime.');
    }
    return global.MediaProviderBridge;
  }

  async function invoke(providerId, sessionId, operation, payload) {
    const bridge = requireBridge();
    switch (operation) {
      case 'create':
        return bridge.create(providerId, sessionId, JSON.stringify(payload || {}));
      case 'join':
        return bridge.join(providerId, sessionId);
      case 'leave':
        return bridge.leave(providerId, sessionId);
      case 'dispose':
        return bridge.dispose(providerId, sessionId);
      case 'command':
        return bridge.command(
          providerId,
          sessionId,
          String(payload && payload.name || ''),
          JSON.stringify(payload && payload.args || {}),
        );
      default:
        throw new Error('Unsupported AWS desktop operation: ' + operation);
    }
  }

  async function bindTrack(providerId, sessionId, trackId, viewKey) {
    unbindTrack(viewKey);
    const container = document.createElement('div');
    container.className = 'capture';
    container.id = 'aws-desktop-' + String(viewKey).replace(/[^a-zA-Z0-9_-]/g, '_');
    document.body.appendChild(container);
    await requireBridge().attachVideo(providerId, sessionId, trackId, container.id);

    const canvas = document.createElement('canvas');
    const context = canvas.getContext('2d', { alpha: false });
    let busy = false;
    const timer = global.setInterval(function() {
      if (busy) return;
      const video = container.querySelector('video');
      if (!video || video.readyState < 2 || !video.videoWidth || !video.videoHeight) return;
      busy = true;
      try {
        const maxWidth = 960;
        const scale = Math.min(1, maxWidth / video.videoWidth);
        canvas.width = Math.max(1, Math.round(video.videoWidth * scale));
        canvas.height = Math.max(1, Math.round(video.videoHeight * scale));
        context.drawImage(video, 0, 0, canvas.width, canvas.height);
        post({
          kind: 'frame',
          viewKey: viewKey,
          data: canvas.toDataURL('image/jpeg', 0.72),
          width: canvas.width,
          height: canvas.height,
        });
      } catch (_) {
      } finally {
        busy = false;
      }
    }, 100);
    bindings.set(viewKey, {
      providerId: providerId,
      sessionId: sessionId,
      trackId: trackId,
      container: container,
      timer: timer,
    });
  }

  function unbindTrack(viewKey) {
    const binding = bindings.get(viewKey);
    if (!binding) return;
    global.clearInterval(binding.timer);
    try {
      requireBridge().detachVideo(
        binding.providerId,
        binding.sessionId,
        binding.trackId,
        binding.container.id,
      );
    } catch (_) {}
    binding.container.remove();
    bindings.delete(viewKey);
  }

  global.AwsDesktopRuntime = {
    invoke: invoke,
    bindTrack: bindTrack,
    unbindTrack: unbindTrack,
    snapshot: function(sessionId) { return snapshots.get(sessionId) || null; },
  };

  global.AwsDesktopChatRuntime = {
    invoke: async function(operation, sessionId, payload) {
      const bridge = global.IvsChatMessagingBridge;
      if (!bridge) throw new Error('The bundled Amazon IVS Chat bridge is unavailable.');
      switch (operation) {
        case 'create':
          return bridge.create(sessionId, JSON.stringify(payload || {}));
        case 'connect':
          return bridge.connect(sessionId);
        case 'command':
          return bridge.command(
            sessionId,
            String(payload && payload.name || ''),
            JSON.stringify(payload && payload.arguments || {}),
          );
        case 'dispose':
          return bridge.dispose(sessionId);
        default:
          throw new Error('Unsupported Amazon IVS Chat operation: ' + operation);
      }
    },
    resolveToken: function(requestId, response, errorMessage) {
      const pending = pendingChatTokens.get(requestId);
      if (!pending) return false;
      pendingChatTokens.delete(requestId);
      global.clearTimeout(pending.timeout);
      if (errorMessage) {
        pending.reject(new Error(String(errorMessage)));
      } else {
        pending.resolve(response);
      }
      return true;
    },
  };

  post({ kind: 'ready' });
})(globalThis);
