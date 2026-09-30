(function installRealtimeVideoEffectsBridge(global) {
  'use strict';

  const assetUrl = (relativePath) =>
    new URL(
      `assets/packages/flutter_realtime_video_effects/assets/web/${relativePath}`,
      document.baseURI,
    ).toString();

  let visionFilesetPromise = null;

  async function visionFileset() {
    const runtime = global.SdkVideoEffectsVision;
    if (!runtime?.FilesetResolver || !runtime?.ImageSegmenter) {
      throw new Error(
        'SDK video effects runtime is unavailable: MediaPipe Vision was not loaded.',
      );
    }
    if (!visionFilesetPromise) {
      visionFilesetPromise = runtime.FilesetResolver.forVisionTasks(
        assetUrl('wasm'),
      ).catch((error) => {
        visionFilesetPromise = null;
        throw error;
      });
    }
    return visionFilesetPromise;
  }

  async function createSegmenter() {
    const runtime = global.SdkVideoEffectsVision;
    const fileset = await visionFileset();
    return runtime.ImageSegmenter.createFromOptions(fileset, {
      baseOptions: {
        modelAssetPath: assetUrl(
          'models/selfie_segmenter_landscape.tflite',
        ),
        delegate: 'GPU',
      },
      runningMode: 'VIDEO',
      outputConfidenceMasks: true,
      outputCategoryMask: false,
    });
  }

  async function createFaceDetector() {
    const runtime = global.SdkVideoEffectsVision;
    if (!runtime?.FaceDetector) throw new Error('SDK face protection runtime is unavailable.');
    return runtime.FaceDetector.createFromOptions(await visionFileset(), {
      baseOptions: {modelAssetPath: assetUrl('models/blaze_face_short_range.tflite'), delegate: 'GPU'},
      runningMode: 'VIDEO', minDetectionConfidence: 0.75,
    });
  }

  function blurRadius(strength) {
    if (strength === 'low') return 10;
    if (strength === 'high') return 28;
    return 18;
  }

  async function createProcessedVideo({
    effect = { type: 'none', blurStrength: 'medium' },
    deviceId = null,
    width = 1280,
    height = 720,
    frameRate = 24,
    onError = () => {},
  } = {}) {
    const mediaDevices = global.navigator?.mediaDevices;
    if (!mediaDevices?.getUserMedia) {
      throw new Error('Browser camera capture is unavailable.');
    }
    if (typeof document === 'undefined') {
      throw new Error('SDK video effects require a browser document.');
    }

    const video = document.createElement('video');
    video.autoplay = true;
    video.muted = true;
    video.playsInline = true;

    const outputCanvas = document.createElement('canvas');
    const foregroundCanvas = document.createElement('canvas');
    const maskCanvas = document.createElement('canvas');
    const outputContext = outputCanvas.getContext('2d', {
      alpha: false,
      desynchronized: true,
    });
    const foregroundContext = foregroundCanvas.getContext('2d', {
      alpha: true,
      desynchronized: true,
    });
    const maskContext = maskCanvas.getContext('2d', {
      alpha: true,
      willReadFrequently: true,
    });
    if (!outputContext || !foregroundContext || !maskContext) {
      throw new Error('Canvas 2D rendering is unavailable.');
    }

    let sourceTrack = null;
    let sourceStream = null;
    let outputTrack = null;
    let currentEffect = { type: 'none', blurStrength: 'medium' };
    let backgroundImage = null;
    let enabled = true;
    let effectRevision = 0;
    let segmenter = null;
    let segmenterPromise = null;
    let faceDetector = null;
    let faceBoxes = [];
    let outputSuspended = false;
    let latestMask = null;
    let stopped = false;
    let frameHandle = null;
    let lastSegmentationAt = 0;

    async function openCamera(nextDeviceId = null) {
      const nextStream = await mediaDevices.getUserMedia({
        audio: false,
        video: {
          width: { ideal: width },
          height: { ideal: height },
          frameRate: { ideal: frameRate, max: Math.max(frameRate, 30) },
          ...(nextDeviceId === 'front' || nextDeviceId === 'back'
            ? {facingMode: {ideal: nextDeviceId === 'front' ? 'user' : 'environment'}}
            : nextDeviceId ? { deviceId: { exact: String(nextDeviceId) } }
            : { facingMode: 'user' }),
        },
      });
      if (stopped) { nextStream.getTracks().forEach((track) => track.stop()); throw new Error('The video source was disposed.'); }
      const nextTrack = nextStream.getVideoTracks()[0];
      if (!nextTrack) {
        nextStream.getTracks().forEach((track) => track.stop());
        throw new Error('No camera video track was returned.');
      }

      const previousTrack = sourceTrack;
      const previousStream = sourceStream;
      nextTrack.enabled = enabled;
      video.srcObject = nextStream;
      try { await video.play?.(); } catch (error) {
        nextStream.getTracks().forEach((track) => track.stop());
        video.srcObject = previousStream;
        throw error;
      }
      if (stopped) { nextStream.getTracks().forEach((track) => track.stop()); video.srcObject = null; throw new Error('The video source was disposed.'); }
      sourceTrack = nextTrack;
      sourceStream = nextStream;
      latestMask = null;
      faceBoxes = [];
      previousTrack?.stop?.();
      previousStream?.getTracks?.().forEach((track) => {
        if (track !== previousTrack) track.stop?.();
      });

      const settings = nextTrack.getSettings?.() || {};
      const outputWidth = Math.max(
        1,
        Number(settings.width || video.videoWidth || width),
      );
      const outputHeight = Math.max(
        1,
        Number(settings.height || video.videoHeight || height),
      );
      outputCanvas.width = outputWidth;
      outputCanvas.height = outputHeight;
      foregroundCanvas.width = outputWidth;
      foregroundCanvas.height = outputHeight;

      if (!outputTrack) {
        const outputStream = outputCanvas.captureStream(frameRate);
        outputTrack = outputStream.getVideoTracks()[0];
        if (!outputTrack) {
          throw new Error('Canvas capture did not produce a video track.');
        }
        outputTrack.enabled = enabled && !outputSuspended;
      }
    }

    async function ensureSegmenter() {
      if (segmenter) return;
      if (!segmenterPromise) {
        segmenterPromise = (async () => {
          const created = await createSegmenter();
          let faces;
          try { faces = await createFaceDetector(); }
          catch (error) { created.close?.(); throw error; }
          if (stopped) { created.close?.(); faces.close?.(); throw new Error('The video source was disposed.'); }
          segmenter = created; faceDetector = faces;
        })().finally(() => { segmenterPromise = null; });
      }
      await segmenterPromise;
    }

    function blankOutput() {
      outputContext.save();
      outputContext.filter = 'none';
      outputContext.fillStyle = '#000';
      outputContext.fillRect(0, 0, outputCanvas.width, outputCanvas.height);
      outputContext.restore();
      outputTrack?.requestFrame?.();
    }

    function failClosed(error) {
      outputSuspended = true;
      latestMask = null;
      // Cloned supplier tracks share the canvas, but their enabled flags are
      // independent. Clear that shared canvas as well as disabling our track.
      blankOutput();
      if (sourceTrack) sourceTrack.enabled = false;
      if (outputTrack) outputTrack.enabled = false;
      onError(error);
    }

    function updateMask(mask) {
      latestMask = null;
      if (!mask) return;
      const values = mask.getAsFloat32Array?.();
      const maskWidth = Number(mask.width || 0);
      const maskHeight = Number(mask.height || 0);
      if (!values || maskWidth <= 0 || maskHeight <= 0) return;
      if (maskCanvas.width !== maskWidth) maskCanvas.width = maskWidth;
      if (maskCanvas.height !== maskHeight) maskCanvas.height = maskHeight;
      const pixels = new Uint8ClampedArray(maskWidth * maskHeight * 4);
      // The landscape model outputs a small matte. Expand uncertain person
      // edges by at most one matte pixel and remap their confidence so hair
      // and shoulders stay in the sharp foreground. Feathering is confined
      // to the outer edge rather than blending blur through the whole person.
      for (let i = 0; i < maskWidth * maskHeight; i += 1) {
        const x = i % maskWidth;
        const y = Math.floor(i / maskWidth);
        let confidence = Math.max(0, Math.min(1, Number(values[i] || 0)));
        for (let dy = -1; dy <= 1; dy += 1) for (let dx = -1; dx <= 1; dx += 1) {
          const nx = x + dx; const ny = y + dy;
          if (nx >= 0 && ny >= 0 && nx < maskWidth && ny < maskHeight) {
            const weight = (dx && dy) ? 0.55 : 0.7;
            confidence = Math.max(confidence, Number(values[ny * maskWidth + nx] || 0) * weight);
          }
        }
        const t = Math.max(0, Math.min(1, (confidence - 0.1) / 0.45));
        let opacity = t * t * (3 - 2 * t);
        // Independent face detection protects cheeks and temples when the
        // coarse person model misses a side-lit face. Keep the protected
        // ellipse inside the detected face and feather its outer band.
        for (const box of faceBoxes) {
          const px = (x + 0.5) * video.videoWidth / maskWidth;
          const py = (y + 0.5) * video.videoHeight / maskHeight;
          const cx = box.originX + box.width * 0.5;
          const cy = box.originY + box.height * 0.5;
          const distance = Math.hypot((px - cx) / (box.width * 0.51), (py - cy) / (box.height * 0.53));
          const faceAlpha = Math.max(0, Math.min(1, (1.04 - distance) / 0.18));
          opacity = Math.max(opacity, faceAlpha * faceAlpha * (3 - 2 * faceAlpha));
        }
        const offset = i * 4;
        pixels[offset] = 255;
        pixels[offset + 1] = 255;
        pixels[offset + 2] = 255;
        pixels[offset + 3] = Math.round(opacity * 255);
      }
      maskContext.putImageData(
        new ImageData(pixels, maskWidth, maskHeight),
        0,
        0,
      );
      latestMask = maskCanvas;
    }

    async function updateSegmentation(now) {
      if (currentEffect.type === 'none' || !enabled || outputSuspended || video.readyState < 2) return;
      if (now - lastSegmentationAt < 1000 / frameRate - 1) return;
      lastSegmentationAt = now;
      await ensureSegmenter();
      const faces = faceDetector.detectForVideo(video, now);
      faceBoxes = (faces?.detections || []).map((face) => face.boundingBox)
        .filter((box) => box && box.width > 0 && box.height > 0).slice(0, 4);
      const result = segmenter.segmentForVideo(video, now);
      try {
        const masks = result?.confidenceMasks;
        updateMask(masks?.[masks.length > 1 ? 1 : 0]);
      } finally {
        result?.close?.();
      }
    }

    function drawFrame() {
      const outputWidth = outputCanvas.width;
      const outputHeight = outputCanvas.height;
      if (!enabled || stopped || outputSuspended || !outputWidth || !outputHeight || video.readyState < 2) return;

      outputContext.save();
      outputContext.clearRect(0, 0, outputWidth, outputHeight);
      if (currentEffect.type === 'none') {
        outputContext.filter = 'none';
        outputContext.drawImage(video, 0, 0, outputWidth, outputHeight);
        outputContext.restore();
        return;
      }

      // Privacy first: before segmentation produces a usable person mask,
      // publish a fully blurred frame rather than leaking the raw background.
      if (currentEffect.type === 'replaceImage') {
        outputContext.filter = 'none';
        const scale = Math.max(outputWidth / backgroundImage.width, outputHeight / backgroundImage.height);
        const w = backgroundImage.width * scale;
        const h = backgroundImage.height * scale;
        outputContext.drawImage(backgroundImage, (outputWidth - w) / 2, (outputHeight - h) / 2, w, h);
      } else {
        outputContext.filter = `blur(${blurRadius(currentEffect.blurStrength)}px)`;
        outputContext.drawImage(video, 0, 0, outputWidth, outputHeight);
        outputContext.filter = 'none';
      }

      if (latestMask) {
        foregroundContext.save();
        foregroundContext.clearRect(0, 0, outputWidth, outputHeight);
        foregroundContext.globalCompositeOperation = 'source-over';
        foregroundContext.drawImage(video, 0, 0, outputWidth, outputHeight);
        foregroundContext.globalCompositeOperation = 'destination-in';
        foregroundContext.drawImage(
          latestMask,
          0,
          0,
          outputWidth,
          outputHeight,
        );
        foregroundContext.restore();
        outputContext.drawImage(
          foregroundCanvas,
          0,
          0,
          outputWidth,
          outputHeight,
        );
      }
      outputContext.restore();
    }

    function scheduleFrame() {
      if (stopped) return;
      const render = async (now) => {
        try {
          await updateSegmentation(now);
          drawFrame();
        } catch (error) {
          failClosed(error);
        }
        scheduleFrame();
      };
      if (typeof video.requestVideoFrameCallback === 'function') {
        frameHandle = video.requestVideoFrameCallback(
          () => render(performance.now()),
        );
      } else {
        frameHandle = global.requestAnimationFrame(render);
      }
    }

    async function setEffect(nextEffect) {
      const revision = ++effectRevision;
      const type = nextEffect?.type || 'none';
      if (!['none', 'blur', 'replaceImage'].includes(type)) {
        throw new Error(`Unsupported background effect: ${type}`);
      }
      outputSuspended = true;
      blankOutput();
      if (outputTrack) outputTrack.enabled = false;
      let nextImage = null;
      try {
        if (type === 'replaceImage') {
          const bytes = nextEffect.imageBytes;
          if (!bytes?.length || bytes.length > 16 * 1024 * 1024) throw new Error('Background image bytes must be between 1 byte and 16 MiB.');
          nextImage = await global.createImageBitmap(new Blob([new Uint8Array(bytes)]));
          if (!nextImage.width || !nextImage.height || nextImage.width > 4096 || nextImage.height > 4096) throw new Error('Background image dimensions must be between 1 and 4096 pixels.');
        }
        if (type !== 'none') await ensureSegmenter();
        if (stopped || revision !== effectRevision) { nextImage?.close?.(); return; }
        const previous = backgroundImage;
        backgroundImage = nextImage;
        latestMask = null;
        currentEffect = { type, blurStrength: nextEffect?.blurStrength || 'medium' };
        previous?.close?.();
        outputSuspended = false;
        if (sourceTrack) sourceTrack.enabled = enabled;
        if (outputTrack) outputTrack.enabled = enabled;
      } catch (error) {
        nextImage?.close?.();
        if (!stopped && revision === effectRevision) failClosed(error);
        throw error;
      }
    }

    try {
      // Initialize effects before opening the camera or scheduling any output.
      await setEffect(effect);
      await openCamera(deviceId);
      scheduleFrame();
    } catch (error) {
      stopped = true;
      sourceStream?.getTracks?.().forEach((track) => track.stop());
      outputTrack?.stop?.();
      segmenter?.close?.();
      faceDetector?.close?.();
      backgroundImage?.close?.();
      video.srcObject = null;
      throw error;
    }

    return {
      get track() {
        return outputTrack;
      },
      get info() {
        const settings = sourceTrack?.getSettings?.() || {};
        return { width: outputCanvas.width, height: outputCanvas.height, frameRate: settings.frameRate || frameRate, cameraDeviceId: settings.deviceId || null, rotationDegrees: 0, pixelFormat: 'rgba8888', mirrored: false };
      },
      get effect() {
        return { ...currentEffect };
      },
      setEffect,
      async setCameraDevice(nextDeviceId) {
        await openCamera(nextDeviceId);
      },
      setEnabled(value) {
        enabled = Boolean(value);
        if (!enabled) blankOutput();
        if (sourceTrack) sourceTrack.enabled = enabled && !outputSuspended;
        if (outputTrack) outputTrack.enabled = enabled && !outputSuspended;
      },
      stop() {
        if (stopped) return;
        stopped = true;
        effectRevision++;
        backgroundImage?.close?.();
        if (
          typeof video.cancelVideoFrameCallback === 'function' &&
          frameHandle != null
        ) {
          video.cancelVideoFrameCallback(frameHandle);
        } else if (frameHandle != null) {
          global.cancelAnimationFrame?.(frameHandle);
        }
        outputTrack?.stop?.();
        sourceStream?.getTracks?.().forEach((track) => track.stop?.());
        segmenter?.close?.();
        faceDetector?.close?.();
        segmenter = null; faceDetector = null; faceBoxes = [];
        video.srcObject = null;
      },
    };
  }

  const sources = new Map();

  function parsePayload(value) {
    if (!value) return {};
    return typeof value === 'string' ? JSON.parse(value) : value;
  }

  function requireSource(sourceId) {
    const id = String(sourceId || '');
    const source = sources.get(id);
    if (!source) {
      throw new Error(`Unknown processed video source: ${id}`);
    }
    return source;
  }

  global.RealtimeVideoEffectsBridge = {
    async createSource(sourceId, serializedArgs) {
      const id = String(sourceId || '');
      if (!id) throw new Error('Processed video sourceId is required.');
      if (sources.has(id)) {
        throw new Error(`Duplicate processed video source: ${id}`);
      }
      const args = parsePayload(serializedArgs);
      const source = await createProcessedVideo({
        effect: args.effect || {
          type: 'none',
          blurStrength: 'medium',
        },
        deviceId: args.cameraDeviceId || null,
        width: Number(args.width || 1280),
        height: Number(args.height || 720),
        frameRate: Number(args.frameRate || 24),
        onError: (error) => global.__flutterVideoEffectsOnError?.(id, String(error?.message || error)),
      });
      sources.set(id, source);
      return source.info;
    },

    async setEffect(sourceId, serializedEffect) {
      await requireSource(sourceId).setEffect(
        parsePayload(serializedEffect),
      );
    },

    async setEnabled(sourceId, enabled) {
      requireSource(sourceId).setEnabled(Boolean(enabled));
    },

    async selectCamera(sourceId, deviceId) {
      await requireSource(sourceId).setCameraDevice(deviceId || null);
    },

    getSourceInfo(sourceId) { return requireSource(sourceId).info; },

    getTrack(sourceId) {
      return requireSource(sourceId).track;
    },

    attachPreview(sourceId, elementId) {
      const container = document.getElementById(String(elementId || ''));
      if (container) this.attachPreviewElement(sourceId, container);
    },

    attachPreviewElement(sourceId, container) {
      if (!container) throw new Error('A preview container is required.');
      let video = container.querySelector('video');
      if (!video) {
        video = document.createElement('video');
        video.autoplay = true;
        video.playsInline = true;
        video.muted = true;
        video.style.width = '100%';
        video.style.height = '100%';
        video.style.objectFit = 'cover';
        container.replaceChildren(video);
      }
      video.srcObject = new MediaStream([requireSource(sourceId).track]);
      video.play().catch(() => {});
    },

    detachPreview(_sourceId, elementId) {
      const container = document.getElementById(String(elementId || ''));
      if (!container) return;
      const video = container.querySelector('video');
      if (video) {
        video.pause?.();
        video.srcObject = null;
      }
      container.replaceChildren();
    },

    disposeSource(sourceId) {
      const id = String(sourceId || '');
      const source = sources.get(id);
      if (!source) return;
      sources.delete(id);
      source.stop();
    },
  };
})(globalThis);
