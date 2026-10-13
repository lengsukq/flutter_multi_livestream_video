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
- `canScreenShare`: `!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows)`
- `canReportNetworkStats`: `true`

### trtc

Processed-video sink in adapter source: **yes**.

- `canBlurBackground`: `!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.macOS)`
- `canReplaceBackgroundImage`: `!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.macOS)`
- `canScreenShare`: `!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows)`
- `canReportNetworkStats`: `true`

### artc

Processed-video sink in adapter source: **yes**.

- `canBlurBackground`: `_capabilities.canPublishVideo && _effectsPlatform`
- `canReplaceBackgroundImage`: `_capabilities.canPublishVideo && _effectsPlatform`
- `canScreenShare`: `true`
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
- `packages/flutter_realtime_media_agora/lib/src/agora_media_session.dart`: `d013a0ac12c9513c`
- `packages/flutter_realtime_media_agora/lib/src/agora_session_factory.dart`: `3aa6d565e8f46d7c`
- `packages/flutter_realtime_media_artc/lib/src/artc_media_session.dart`: `9875f1bf25b4dc7e`
- `packages/flutter_realtime_media_artc/lib/src/artc_session_factory.dart`: `518680ef5600f7b5`
- `packages/flutter_realtime_media_chime/lib/src/chime_media_session.dart`: `fd2ab50a72e1db32`
- `packages/flutter_realtime_media_chime/lib/src/chime_session_factory.dart`: `0ab5d595b8d7c8e8`
- `packages/flutter_realtime_media_ivs/lib/src/ivs_media_session.dart`: `6b1c9d2de6b0730d`
- `packages/flutter_realtime_media_ivs/lib/src/ivs_session_factory.dart`: `0313e54a89b103ba`
- `packages/flutter_realtime_media_livekit/lib/src/livekit_media_session.dart`: `78d6b59015b471e0`
- `packages/flutter_realtime_media_livekit/lib/src/livekit_session_factory.dart`: `17bea6a36df94f9d`
- `packages/flutter_realtime_media_trtc/lib/src/trtc_media_session.dart`: `1e0c5644b3a254c6`
- `packages/flutter_realtime_media_trtc/lib/src/trtc_session_factory.dart`: `0725426dd935202e`
- `packages/flutter_realtime_media_web/lib/src/provider_web_profile.dart`: `767eba65b2f9f5ea`
- `packages/flutter_realtime_media_web/lib/src/provider_web_session_factory.dart`: `209ed9f6a0846624`
- `packages/flutter_realtime_provider_agora/lib/src/drivers_native.dart`: `e1b9b49fa520a269`
- `packages/flutter_realtime_provider_agora/lib/src/drivers_web.dart`: `bd81a8d666ea0441`
- `packages/flutter_realtime_provider_agora_chat/lib/src/drivers_native.dart`: `d08d482cbe94ac72`
- `packages/flutter_realtime_provider_agora_chat/lib/src/drivers_web.dart`: `ea37a522e2246302`
- `packages/flutter_realtime_provider_artc/lib/src/drivers_native.dart`: `8a7597c818ca21c5`
- `packages/flutter_realtime_provider_artc/lib/src/drivers_web.dart`: `7aa589413c8e9665`
- `packages/flutter_realtime_provider_aws/lib/src/drivers_native.dart`: `22bde5d25b6fc764`
- `packages/flutter_realtime_provider_aws/lib/src/drivers_web.dart`: `8ebcb8186e43b6ef`
- `packages/flutter_realtime_provider_ivs_chat/lib/src/drivers_native.dart`: `1fcf7e18de32be5d`
- `packages/flutter_realtime_provider_ivs_chat/lib/src/drivers_web.dart`: `ef1e144fa3e3f879`
- `packages/flutter_realtime_provider_livekit/lib/src/drivers_native.dart`: `133da921d7b64523`
- `packages/flutter_realtime_provider_livekit/lib/src/drivers_web.dart`: `caf4095823a79672`
- `packages/flutter_realtime_provider_tencent_chat/lib/src/drivers_native.dart`: `5862c1fea875fdfb`
- `packages/flutter_realtime_provider_tencent_chat/lib/src/drivers_web.dart`: `83276f7af33054a5`
- `packages/flutter_realtime_provider_trtc/lib/src/drivers_native.dart`: `1b8dcacf17325abe`
- `packages/flutter_realtime_provider_trtc/lib/src/drivers_web.dart`: `fe51dd06f5757189`
- `packages/flutter_realtime_sdk/pubspec.yaml`: `a815f8e7eca7cae6`
- `packages/flutter_realtime_sdk_runtime/lib/src/provider_web_session_wrapper.dart`: `da906bcbf530dfe3`
- `packages/flutter_realtime_video_effects/pubspec.yaml`: `67a2f7272941e8ae`
