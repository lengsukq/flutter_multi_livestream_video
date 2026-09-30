#import "SdkNativeProviderSink.h"
#import "ProcessedNativeInterfaces.h"
#include "IAgoraRtcEngine.h"
#include "IAgoraMediaEngine.h"

@interface SdkNativeProviderSink () <FlutterRealtimeProcessedVideoFrameSink>
@property NSString *sourceId;
@property NSString *provider;
@property uint32_t trackId;
@property void *mediaEngine;
@property BOOL disposed;
@end
@implementation SdkNativeProviderSink
+ (instancetype)attachWithSourceId:(NSString *)sourceId provider:(NSString *)provider engineHandle:(int64_t)handle trackId:(uint32_t)trackId {
  Class hub = NSClassFromString(@"FlutterRealtimeProcessedVideoFrameHub");
  if (!sourceId.length || ![hub respondsToSelector:@selector(containsSourceId:)] || ![hub containsSourceId:sourceId]) return nil;
  SdkNativeProviderSink *sink = [self new];
  sink.sourceId = sourceId; sink.provider = provider; sink.trackId = trackId;
  if ([provider isEqualToString:@"agora"]) {
    auto *engine = reinterpret_cast<agora::rtc::IRtcEngine *>(handle);
    agora::media::IMediaEngine *media = nullptr;
    if (!engine || engine->queryInterface(agora::rtc::AGORA_IID_MEDIA_ENGINE, reinterpret_cast<void **>(&media))) return nil;
    sink.mediaEngine = media;
  } else if ([provider isEqualToString:@"trtc"]) {
    Class cloud = NSClassFromString(@"TRTCCloud");
    Class frame = NSClassFromString(@"TRTCVideoFrame");
    if (![cloud respondsToSelector:@selector(sharedInstance)] || !frame) return nil;
    id engine = [cloud sharedInstance];
    if (![engine respondsToSelector:@selector(enableCustomVideoCapture:enable:)] ||
        ![engine respondsToSelector:@selector(sendCustomVideoData:frame:)]) return nil;
    [engine stopLocalPreview];
    [engine enableCustomVideoCapture:0 enable:YES];
  } else return nil;
  [NSClassFromString(@"FlutterRealtimeProcessedVideoFrameHub") registerWithSourceId:sourceId sink:sink];
  return sink;
}
- (void)onProcessedVideoFrame:(FlutterRealtimeProcessedVideoFrame *)input {
  @synchronized(self) {
    if (_disposed) return;
    if (_mediaEngine) {
      CVPixelBufferLockBaseAddress(input.pixelBuffer,kCVPixelBufferLock_ReadOnly);
      agora::media::base::ExternalVideoFrame frame;
      frame.format = agora::media::base::VIDEO_PIXEL_BGRA;
      frame.buffer = CVPixelBufferGetBaseAddress(input.pixelBuffer);
      frame.stride = (int)CVPixelBufferGetBytesPerRow(input.pixelBuffer)/4;
      frame.height = (int)input.height;
      frame.cropRight = frame.stride - (int)input.width;
      frame.timestamp = input.timestampNs/1000000;
      int result = reinterpret_cast<agora::media::IMediaEngine *>(_mediaEngine)->pushVideoFrame(&frame,_trackId);
      CVPixelBufferUnlockBaseAddress(input.pixelBuffer,kCVPixelBufferLock_ReadOnly);
      if (result != 0) {
        void (^failure)(NSString *) = self.onFailure;
        [self dispose];
        if (failure) failure([NSString stringWithFormat:@"Agora rejected a processed video frame (%d).", result]);
      }
    } else {
      id frame = [NSClassFromString(@"TRTCVideoFrame") new];
      if (!frame) return;
      [frame setValue:@(6) forKey:@"pixelFormat"];
      [frame setValue:@(1) forKey:@"bufferType"];
      [frame setValue:(__bridge id)input.pixelBuffer forKey:@"pixelBuffer"];
      [frame setValue:@(input.width) forKey:@"width"];
      [frame setValue:@(input.height) forKey:@"height"];
      [frame setValue:@(input.timestampNs/1000000) forKey:@"timestamp"];
      [frame setValue:@(0) forKey:@"rotation"];
      [[NSClassFromString(@"TRTCCloud") sharedInstance] sendCustomVideoData:0 frame:frame];
    }
  }
}
- (void)dispose {
  @synchronized(self) {
    if (_disposed) return; _disposed=YES;
    [NSClassFromString(@"FlutterRealtimeProcessedVideoFrameHub") unregisterWithSourceId:_sourceId sink:self];
    if (_mediaEngine) { reinterpret_cast<agora::media::IMediaEngine *>(_mediaEngine)->release(); _mediaEngine=nullptr; }
    else if ([_provider isEqualToString:@"trtc"]) [[NSClassFromString(@"TRTCCloud") sharedInstance] enableCustomVideoCapture:0 enable:NO];
  }
}
- (void)dealloc { [self dispose]; }
@end
