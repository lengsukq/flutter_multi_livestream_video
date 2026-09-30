#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_realtime_video_effects.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_realtime_video_effects'
  s.version          = '0.0.1'
  s.summary          = 'Provider-neutral realtime video effects bridge.'
  s.description      = <<-DESC
Native macOS camera, person-segmentation and processed-video frame bridge.
                       DESC
  s.homepage         = 'https://github.com/lengsukq/flutter_multi_livestream_video'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'OnePlusDream' => 'developers@oneplusdream.com' }

  s.source           = { :path => '.' }
  s.source_files = 'flutter_realtime_video_effects/Sources/flutter_realtime_video_effects/**/*',
    'flutter_realtime_video_effects/Sources/RealtimeNativeFrameSinks/**/*.{h,mm}'
  s.public_header_files = 'flutter_realtime_video_effects/Sources/RealtimeNativeFrameSinks/include/*.h'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_realtime_video_effects_privacy' => ['flutter_realtime_video_effects/Sources/flutter_realtime_video_effects/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'
  s.frameworks = 'AVFoundation', 'Vision', 'CoreImage', 'CoreVideo'

  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/flutter_realtime_video_effects/Sources/RealtimeNativeFrameSinks/agora" "$(PODS_TARGET_SRCROOT)/flutter_realtime_video_effects/Sources/RealtimeNativeFrameSinks/include"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17'
  }
  s.swift_version = '5.9'
end
