package com.oneplusdream.flutter_realtime_media_livekit;

import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin;
import com.cloudwebrtc.webrtc.MethodCallHandlerImpl;
import com.cloudwebrtc.webrtc.video.LocalVideoTrack;
import com.oneplusdream.flutter_realtime_video_effects.ProcessedVideoFrame;
import com.oneplusdream.flutter_realtime_video_effects.ProcessedVideoFrameHub;
import com.oneplusdream.flutter_realtime_video_effects.ProcessedVideoFrameSink;
import org.webrtc.*;
import java.nio.ByteBuffer;
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
        int w=input.getWidth(), h=input.getHeight(), cw=(w+1)/2, ch=(h+1)/2;
        ByteBuffer data=input.toI420();
        ByteBuffer y=plane(data,0,w*h), u=plane(data,w*h,cw*ch), v=plane(data,w*h+cw*ch,cw*ch);
        JavaI420Buffer buffer=JavaI420Buffer.wrap(w,h,y,w,u,cw,v,cw,null);
        VideoFrame frame=new VideoFrame(buffer,input.getRotationDegrees(),input.getTimestampNs());
        try { videoSource.getCapturerObserver().onFrameCaptured(frame); }
        finally { frame.release(); }
    }
    private static ByteBuffer plane(ByteBuffer data,int offset,int length) {
        ByteBuffer view=data.duplicate(); view.position(offset); view.limit(offset+length); return view.slice();
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
