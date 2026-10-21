Pod::Spec.new do |s|
  s.name = 'flutter_realtime_video_effects'
  s.version = '0.1.0'
  s.summary = 'Native iOS real-time camera background effects.'
  s.description = s.summary
  s.homepage = 'https://github.com/lengsukq/multi-video'
  s.license = { :type => 'MIT' }
  s.author = { 'OnePlusDream' => 'developers@oneplusdream.com' }
  s.source = { :path => '.' }
  s.source_files = 'flutter_realtime_video_effects/Sources/flutter_realtime_video_effects/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'flutter_realtime_processed_video'
  s.frameworks = 'AVFoundation', 'Vision', 'CoreImage', 'CoreVideo'
  s.platform = :ios, '15.0'
  s.swift_version = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
