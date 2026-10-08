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

These fingerprints make CI reject stale declarations, including changes to the full catalog or conditional Web features.

- `packages/flutter_realtime_chat_agora/lib/src/agora_chat_join_info.dart`: `d22aef6bbadc524d`
- `packages/flutter_realtime_chat_core/lib/src/model/chat_role.dart`: `9b92f5cea74f4d02`
- `packages/flutter_realtime_chat_ivs/lib/src/ivs_chat_join_info.dart`: `4e2a4e38f8f0698b`
- `packages/flutter_realtime_chat_tencent/lib/src/tencent_chat_join_info.dart`: `94dcd174ddb23d0a`
- `packages/flutter_realtime_media_agora/lib/src/agora_media_session.dart`: `0a99ac21f2442b97`
- `packages/flutter_realtime_media_agora/lib/src/agora_session_factory.dart`: `1091ebbda6494793`
- `packages/flutter_realtime_media_artc/lib/src/artc_media_session.dart`: `53c49624e591e0db`
- `packages/flutter_realtime_media_artc/lib/src/artc_session_factory.dart`: `6f9ec3b27f59c029`
- `packages/flutter_realtime_media_chime/lib/src/chime_media_session.dart`: `2bfdff817da8f646`
- `packages/flutter_realtime_media_chime/lib/src/chime_session_factory.dart`: `d6c7497cc184cb65`
- `packages/flutter_realtime_media_ivs/lib/src/ivs_media_session.dart`: `31b7e2df086a4a49`
- `packages/flutter_realtime_media_ivs/lib/src/ivs_session_factory.dart`: `cbf35f041d635df7`
- `packages/flutter_realtime_media_livekit/lib/src/livekit_media_session.dart`: `2470883b10053944`
- `packages/flutter_realtime_media_livekit/lib/src/livekit_session_factory.dart`: `5b98fdbad49619be`
- `packages/flutter_realtime_media_trtc/lib/src/trtc_media_session.dart`: `e5262412df207a82`
- `packages/flutter_realtime_media_trtc/lib/src/trtc_session_factory.dart`: `cb4feae6fecfa027`
- `packages/flutter_realtime_media_web/lib/src/provider_web_profile.dart`: `ae0162dbdbab1f73`
- `packages/flutter_realtime_media_web/lib/src/provider_web_session_factory.dart`: `c5fdf546f573693d`
- `packages/flutter_realtime_provider_agora/lib/src/drivers_native.dart`: `f24244ffef214375`
- `packages/flutter_realtime_provider_agora/lib/src/drivers_web.dart`: `fa32bfbf8ac91021`
- `packages/flutter_realtime_provider_agora_chat/lib/src/drivers_native.dart`: `8560b62e603c1946`
- `packages/flutter_realtime_provider_agora_chat/lib/src/drivers_web.dart`: `b93148259caab69b`
- `packages/flutter_realtime_provider_artc/lib/src/drivers_native.dart`: `cbebb1a43c97dfa5`
- `packages/flutter_realtime_provider_artc/lib/src/drivers_web.dart`: `94ec8e7769a0a671`
- `packages/flutter_realtime_provider_aws/lib/src/drivers_native.dart`: `037ae7abc443c94f`
- `packages/flutter_realtime_provider_aws/lib/src/drivers_web.dart`: `4486b8ddb930e2c9`
- `packages/flutter_realtime_provider_ivs_chat/lib/src/drivers_native.dart`: `23f1daf87c3790c3`
- `packages/flutter_realtime_provider_ivs_chat/lib/src/drivers_web.dart`: `bb5f38cf70d9a155`
- `packages/flutter_realtime_provider_livekit/lib/src/drivers_native.dart`: `9a3da5a002b5511e`
- `packages/flutter_realtime_provider_livekit/lib/src/drivers_web.dart`: `ee5b34bd8dd7c74a`
- `packages/flutter_realtime_provider_tencent_chat/lib/src/drivers_native.dart`: `0b05f22c8052fa47`
- `packages/flutter_realtime_provider_tencent_chat/lib/src/drivers_web.dart`: `356d22f5979a87b3`
- `packages/flutter_realtime_provider_trtc/lib/src/drivers_native.dart`: `4565bf627999588f`
- `packages/flutter_realtime_provider_trtc/lib/src/drivers_web.dart`: `813797e63c045dbd`
- `packages/flutter_realtime_sdk/lib/src/default_driver_catalog_native.dart`: `572dd5d48ce8db74`
- `packages/flutter_realtime_sdk/lib/src/default_driver_catalog_web.dart`: `572dd5d48ce8db74`
- `packages/flutter_realtime_video_effects/pubspec.yaml`: `30f3580d898ed16e`
