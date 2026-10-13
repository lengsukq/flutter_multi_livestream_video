package com.oneplusdream.flutter_realtime_media_livekit;

import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin;
import com.cloudwebrtc.webrtc.MethodCallHandlerImpl;
import com.cloudwebrtc.webrtc.video.LocalVideoTrack;
import com.oneplusdream.flutter_realtime_processed_video.ProcessedVideoFrame;
import com.oneplusdream.flutter_realtime_processed_video.ProcessedVideoFrameHub;
import com.oneplusdream.flutter_realtime_processed_video.ProcessedVideoFrameSink;
import org.webrtc.*;
import java.nio.ByteBuffer;
import android.util.Log;
import java.util.*;

final class ProcessedWebRtcTrack implements ProcessedVideoFrameSink {
    final String sourceId;
    final String trackId = UUID.randomUUID().toString();
    final String streamId = UUID.randomUUID().toString();
    final VideoSource videoSource;
    final VideoTrack track;
    final MediaStream stream;
    final MethodCallHandlerImpl handler;
    volatile boolean disposed;
    private final boolean logFramePerformance = Log.isLoggable("LiveKitFramePerf", Log.DEBUG);
    private long performanceStartNs;
    private long conversionNs;
    private long deliveryNs;
    private int deliveredFrames;

    ProcessedWebRtcTrack(String sourceId) throws Exception {
        this.sourceId = sourceId;
        FlutterWebRTCPlugin plugin = FlutterWebRTCPlugin.sharedSingleton;
        if (plugin == null || plugin.getPeerConnectionFactory() == null) {
            throw new IllegalStateException("WebRTC must be initialized before attaching processed video.");
        }
        // FlutterWebRTC exposes registration on its handler but no plugin getter.
        // Resolve that handler once; video frames use typed native APIs below.
        java.lang.reflect.Field field = FlutterWebRTCPlugin.class.getDeclaredField("methodCallHandler");
        field.setAccessible(true);
        handler = (MethodCallHandlerImpl) field.get(plugin);
        PeerConnectionFactory factory = plugin.getPeerConnectionFactory();
        videoSource = factory.createVideoSource(false);
        track = factory.createVideoTrack(trackId, videoSource);
        stream = factory.createLocalMediaStream(streamId);
        stream.addTrack(track);
        handler.putLocalTrack(trackId, new LocalVideoTrack(track));
        handler.putLocalStream(streamId, stream);
        videoSource.getCapturerObserver().onCapturerStarted(true);
        ProcessedVideoFrameHub.INSTANCE.register(sourceId, this);
    }

    Map<String,Object> descriptor() {
        Map<String,Object> video = new HashMap<>();
        video.put("id",trackId); video.put("label","SDK processed camera");
        video.put("kind","video"); video.put("enabled",true);
        Map<String,Object> value = new HashMap<>();
        value.put("streamId",streamId); value.put("ownerTag","local");
        value.put("audioTracks",Collections.emptyList()); value.put("videoTracks",Collections.singletonList(video));
        return value;
    }

    @Override public synchronized void onVideoFrame(ProcessedVideoFrame input) {
        if (disposed) return;
        final int width = input.getWidth(), height = input.getHeight();
        final int stride = input.getRowStride();
        final ByteBuffer rgba = input.getRgba().duplicate();
        final long required = (long) stride * (height - 1) + (long) width * 4;
        if (!"rgba8888".equals(input.getPixelFormat()) || !rgba.isDirect()
                || width <= 0 || height <= 0 || stride < (long) width * 4
                || required > rgba.limit()) {
            throw new IllegalArgumentException("Expected a direct RGBA frame with valid row strides.");
        }
        rgba.position(0);
        final long started = logFramePerformance ? System.nanoTime() : 0;
        // RGBA bytes are called ABGR by libyuv on little-endian Android.
        // Use WebRTC's native SIMD converter instead of Kotlin pixel loops.
        // A refcounted I420 buffer stays valid if the encoder retains this frame.
        final JavaI420Buffer buffer = JavaI420Buffer.allocate(width, height);
        try {
            YuvHelper.ABGRToI420(rgba, stride,
                    buffer.getDataY(), buffer.getStrideY(),
                    buffer.getDataU(), buffer.getStrideU(),
                    buffer.getDataV(), buffer.getStrideV(), width, height);
        } catch (RuntimeException | Error error) {
            buffer.release();
            throw error;
        }
        final long converted = logFramePerformance ? System.nanoTime() : 0;
        final VideoFrame frame = new VideoFrame(buffer, input.getRotationDegrees(), input.getTimestampNs());
        try {
            videoSource.getCapturerObserver().onFrameCaptured(frame);
        } finally {
            frame.release();
        }
        if (logFramePerformance) {
            if (performanceStartNs == 0) performanceStartNs = started;
            conversionNs += converted - started;
            deliveryNs += System.nanoTime() - converted;
            deliveredFrames++;
            final double seconds = (System.nanoTime() - performanceStartNs) / 1_000_000_000.0;
            if (seconds >= 5) {
                Log.d("LiveKitFramePerf", String.format(Locale.US,
                        "%dx%d delivered=%.1ffps convert=%.2fms capture=%.2fms",
                        width, height, deliveredFrames / seconds,
                        conversionNs / 1_000_000.0 / deliveredFrames,
                        deliveryNs / 1_000_000.0 / deliveredFrames));
                performanceStartNs = 0;
                conversionNs = 0;
                deliveryNs = 0;
                deliveredFrames = 0;
            }
        }
    }
    synchronized void dispose() {
        if (disposed) return; disposed=true;
        ProcessedVideoFrameHub.INSTANCE.unregister(sourceId,this);
        videoSource.getCapturerObserver().onCapturerStopped();
        // Dart normally unregisters first. Engine detachment must also release an
        // attachment when no Dart cleanup runs. These native objects are SDK-owned.
        try { handler.trackDispose(trackId); } catch (IllegalStateException ignored) { }
        try { handler.streamDispose(streamId); } catch (IllegalStateException ignored) { }
        try { track.dispose(); } catch (IllegalStateException ignored) { }
        try { stream.dispose(); } catch (IllegalStateException ignored) { }
        videoSource.dispose();
    }
}
