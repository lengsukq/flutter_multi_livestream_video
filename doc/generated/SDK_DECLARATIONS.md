# Generated SDK declarations

Generated from optional driver registrations and adapter declarations. This is implementation evidence, not build or real-call acceptance.

| Provider | Engine | Driver | Platforms | Declared roles |
| --- | --- | --- | --- | --- |
| agora | agora | native | android, ios, macos, windows | participant, host, viewer |
| agora | agora | web | web | participant, host, viewer |
| agora-chat | agora-chat | native | android, ios, macos | participant, host, viewer (credential-dependent) |
| agora-chat | agora-chat | web | web | participant, host, viewer (credential-dependent) |
| artc | artc | native | android, ios, macos | participant, host, viewer |
| artc | artc | web | web | participant, host, viewer |
| aws | chime | native | android, ios, macos | participant |
| aws | ivs | native | android, ios, macos | participant, host, viewer |
| aws | chime | web | web | participant |
| aws | ivs | web | web | participant, host, viewer |
| ivs-chat | ivs-chat | native | android, ios, macos | participant, host, viewer (credential-dependent) |
| ivs-chat | ivs-chat | web | web | participant, host, viewer (credential-dependent) |
| livekit | livekit | native | android, ios, macos, windows | participant, host, viewer |
| livekit | livekit | web | web | participant, host, viewer |
| tencent-chat | tencent-chat | native | android, ios, macos, windows | participant, host, viewer (credential-dependent) |
| tencent-chat | tencent-chat | web | web | participant, host, viewer (credential-dependent) |
| trtc | trtc | native | android, ios, macos, windows | participant, host, viewer |
| trtc | trtc | web | web | participant, host, viewer |

## Background and media feature declarations

Expressions below are copied from source. Runtime probes, role conditions and platform restrictions remain part of the declaration; an implemented sink does not prove a successful remote call.

### livekit

Processed-video sink in adapter source: **yes**.

- `canBlurBackground`: `!isViewer && (kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.macOS)`
- `canReplaceBackgroundImage`: `!isViewer && (kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.macOS)`
- `canScreenShare`: `!isViewer && (!kIsWeb || !lk.lkPlatformIsWebMobile())`
- `canReportNetworkStats`: `true`

### agora

Processed-video sink in adapter source: **yes**.

- `canBlurBackground`: `!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.macOS)`
- `canReplaceBackgroundImage`: `!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.macOS)`
- `canScreenShare`: `false`
- `canReportNetworkStats`: `true`

### trtc

Processed-video sink in adapter source: **yes**.

- `canBlurBackground`: `!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.macOS)`
- `canReplaceBackgroundImage`: `!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.macOS)`
- `canScreenShare`: `!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)`
- `canReportNetworkStats`: `true`

### artc

Processed-video sink in adapter source: **yes**.

- `canBlurBackground`: `_capabilities.canPublishVideo && _effectsPlatform`
- `canReplaceBackgroundImage`: `_capabilities.canPublishVideo && _effectsPlatform`
- `canScreenShare`: `(not explicitly declared here; inspect factory/profile defaults)`
- `canReportNetworkStats`: `(not explicitly declared here; inspect factory/profile defaults)`

### chime

Processed-video sink in adapter source: **yes**.

- `canBlurBackground`: `_chimeCapabilities.canPublishVideo && _effectsPlatform`
- `canReplaceBackgroundImage`: `_chimeCapabilities.canPublishVideo && _effectsPlatform`
- `canScreenShare`: `(not explicitly declared here; inspect factory/profile defaults)`
- `canReportNetworkStats`: `(not explicitly declared here; inspect factory/profile defaults)`

### ivs

Processed-video sink in adapter source: **yes**.

- `canBlurBackground`: `publisher && _effectsPlatform`
- `canReplaceBackgroundImage`: `publisher && _effectsPlatform`
- `canScreenShare`: `(not explicitly declared here; inspect factory/profile defaults)`
- `canReportNetworkStats`: `true`

## Source fingerprints

These fingerprints make CI reject stale declarations, including changes to the explicit provider registrations, SDK dependency boundary and conditional Web features.

- `packages/flutter_realtime_chat_agora/lib/src/agora_chat_join_info.dart`: `b582e4b16a9f1033`
- `packages/flutter_realtime_chat_core/lib/src/model/chat_role.dart`: `9b92f5cea74f4d02`
- `packages/flutter_realtime_chat_ivs/lib/src/ivs_chat_join_info.dart`: `e6a17278c17c422e`
- `packages/flutter_realtime_chat_tencent/lib/src/tencent_chat_join_info.dart`: `3884ff1e25b5fa03`
- `packages/flutter_realtime_media_agora/lib/src/agora_media_session.dart`: `bacc15d8499fb31c`
- `packages/flutter_realtime_media_agora/lib/src/agora_session_factory.dart`: `3aa6d565e8f46d7c`
- `packages/flutter_realtime_media_artc/lib/src/artc_media_session.dart`: `ceb906e34fd61093`
- `packages/flutter_realtime_media_artc/lib/src/artc_session_factory.dart`: `518680ef5600f7b5`
- `packages/flutter_realtime_media_chime/lib/src/chime_media_session.dart`: `28356d067c176c2d`
- `packages/flutter_realtime_media_chime/lib/src/chime_session_factory.dart`: `0ab5d595b8d7c8e8`
- `packages/flutter_realtime_media_ivs/lib/src/ivs_media_session.dart`: `43917a177fc4fc4c`
- `packages/flutter_realtime_media_ivs/lib/src/ivs_session_factory.dart`: `0313e54a89b103ba`
- `packages/flutter_realtime_media_livekit/lib/src/livekit_media_session.dart`: `86541b889f11125b`
- `packages/flutter_realtime_media_livekit/lib/src/livekit_session_factory.dart`: `17bea6a36df94f9d`
- `packages/flutter_realtime_media_trtc/lib/src/trtc_media_session.dart`: `18b475e4152a26c3`
- `packages/flutter_realtime_media_trtc/lib/src/trtc_session_factory.dart`: `0725426dd935202e`
- `packages/flutter_realtime_media_web/lib/src/provider_web_profile.dart`: `767eba65b2f9f5ea`
- `packages/flutter_realtime_media_web/lib/src/provider_web_session_factory.dart`: `b91ead75f86a265a`
- `packages/flutter_realtime_provider_agora/lib/src/drivers_native.dart`: `d11802c76dc0c759`
- `packages/flutter_realtime_provider_agora/lib/src/drivers_web.dart`: `6ed0a1e16a415de4`
- `packages/flutter_realtime_provider_agora_chat/lib/src/drivers_native.dart`: `d08d482cbe94ac72`
- `packages/flutter_realtime_provider_agora_chat/lib/src/drivers_web.dart`: `ea37a522e2246302`
- `packages/flutter_realtime_provider_artc/lib/src/drivers_native.dart`: `6c4975d443e9b421`
- `packages/flutter_realtime_provider_artc/lib/src/drivers_web.dart`: `d90f3a652c09fa14`
- `packages/flutter_realtime_provider_aws/lib/src/drivers_native.dart`: `d57cb5c93a0cf9f1`
- `packages/flutter_realtime_provider_aws/lib/src/drivers_web.dart`: `cb1d2442e506f0cc`
- `packages/flutter_realtime_provider_ivs_chat/lib/src/drivers_native.dart`: `1fcf7e18de32be5d`
- `packages/flutter_realtime_provider_ivs_chat/lib/src/drivers_web.dart`: `ef1e144fa3e3f879`
- `packages/flutter_realtime_provider_livekit/lib/src/drivers_native.dart`: `ca0c1bddbdb3a9bf`
- `packages/flutter_realtime_provider_livekit/lib/src/drivers_web.dart`: `2508237ef819878c`
- `packages/flutter_realtime_provider_tencent_chat/lib/src/drivers_native.dart`: `5862c1fea875fdfb`
- `packages/flutter_realtime_provider_tencent_chat/lib/src/drivers_web.dart`: `83276f7af33054a5`
- `packages/flutter_realtime_provider_trtc/lib/src/drivers_native.dart`: `6d53143bfb145b96`
- `packages/flutter_realtime_provider_trtc/lib/src/drivers_web.dart`: `35ce904ba8a88aa6`
- `packages/flutter_realtime_sdk/pubspec.yaml`: `14205eebd030dfa3`
- `packages/flutter_realtime_sdk_runtime/lib/src/provider_web_session_wrapper.dart`: `da906bcbf530dfe3`
- `packages/flutter_realtime_video_effects/pubspec.yaml`: `30f3580d898ed16e`
