Pod::Spec.new do |s|
  s.name             = 'flutter_realtime_recorder_native'
  s.version          = '0.1.0'
  s.summary          = 'Optional native local recording of a user-authorized screen.'
  s.description      = 'Provider-neutral system display recording for macOS.'
  s.homepage         = 'https://github.com/lengsukq/flutter_multi_livestream_video'
  s.license          = { :type => 'MIT' }
  s.author           = { 'OnePlusDream' => 'developers@oneplusdream.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_realtime_recorder_native/Sources/flutter_realtime_recorder_native/**/*.swift'
  s.dependency 'FlutterMacOS'
  s.frameworks       = 'ScreenCaptureKit', 'AVFoundation', 'AppKit'
  s.platform         = :osx, '12.0'
  s.swift_version    = '5.0'
  s.static_framework = true
end
