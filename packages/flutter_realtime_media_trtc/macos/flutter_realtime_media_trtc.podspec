Pod::Spec.new do |s|
  s.name = 'flutter_realtime_media_trtc'
  s.version = '0.1.0'
  s.summary = 'Provider-owned processed video sink.'
  s.description = s.summary
  s.homepage = 'https://github.com/lengsukq/flutter_multi_livestream_video'
  s.license = { :type => 'MIT' }
  s.author = { 'OnePlusDream' => 'developers@oneplusdream.com' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*.{h,m,mm}'
  s.public_header_files = 'Classes/FlutterRealtimeMediaTrtcPlugin.h'
  s.private_header_files = 'Classes/Realtime*.h', 'Classes/agora/**/*.h'
  s.dependency 'FlutterMacOS'
  s.dependency 'flutter_realtime_processed_video'
  s.frameworks = 'CoreVideo'
  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Classes/agora"', 'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17' }
end
