(function installProcessedVideoBridge(global) {
  if (global.RealtimeProcessedVideoBridge) return;
  const sources = new Map();
  function requireSource(id) {
    const source = sources.get(id);
    if (!source) throw new Error('processedVideo.source.unregistered');
    return source;
  }
  global.RealtimeProcessedVideoBridge = Object.freeze({
    register(id, source) {
      if (!id || sources.has(id)) throw new Error('processedVideo.source.duplicate');
      sources.set(id, source);
    },
    unregister(id) { sources.delete(id); },
    getTrack(id) { return requireSource(id).track; },
    setEnabled(id, enabled) { return requireSource(id).setEnabled(enabled); },
    selectCamera(id, deviceId) { return requireSource(id).setCameraDevice(deviceId); },
    attachPreviewElement(id, element, fit) {
      const source = requireSource(id);
      if (source.attachPreviewElement) return source.attachPreviewElement(element, fit);
      const video = global.document.createElement('video');
      video.autoplay = true; video.muted = true; video.playsInline = true;
      video.style.width = '100%'; video.style.height = '100%'; video.style.objectFit = fit;
      video.srcObject = new global.MediaStream([source.track]);
      element.replaceChildren(video);
      void video.play().catch(() => {}); // Browser playback policy; host still controls source ownership.
    },
  });
})(globalThis);
