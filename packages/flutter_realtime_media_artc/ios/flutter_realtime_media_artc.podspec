Pod::Spec.new do |s|
  s.name             = 'flutter_realtime_media_artc'
  s.version          = '0.1.0'
  s.summary          = 'Provider-neutral Flutter adapter for Alibaba Cloud ARTC.'
  s.description      = 'An optional Flutter adapter that maps Alibaba Cloud ARTC into flutter_realtime_media_core.'
  s.homepage         = 'https://github.com/lengsukq/flutter_multi_livestream_video'
  s.license          = { :type => 'MIT' }
  s.author           = { 'OnePlusDream' => 'developers@oneplusdream.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'AliVCSDK_ARTC', '7.11.0'
  s.platform = :ios, '15.0'
  s.swift_version = '5.0'
  s.static_framework = true
end
