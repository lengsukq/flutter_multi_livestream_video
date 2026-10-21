Pod::Spec.new do |s|
  s.name = 'flutter_realtime_media_trtc'
  s.version = '0.1.0'
  s.summary = 'Tencent TRTC iOS processed-video sink'
  s.description = s.summary
  s.homepage = 'https://github.com/lengsukq/flutter_multi_livestream_video'
  s.license = { :type => 'MIT' }
  s.author = { 'OnePlusDream' => 'developers@oneplusdream.com' }
  s.source = { :path => '.' }
  s.source_files = 'flutter_realtime_media_trtc/Sources/flutter_realtime_media_trtc/**/*.{h,m,mm}'
  s.public_header_files = 'flutter_realtime_media_trtc/Sources/flutter_realtime_media_trtc/FlutterRealtimeMediaTrtcPlugin.h'
  s.dependency 'Flutter'
  s.dependency 'flutter_realtime_processed_video'
  s.dependency 'tencent_rtc_sdk'
  s.frameworks = 'CoreVideo'
  s.platform = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17' }
end
