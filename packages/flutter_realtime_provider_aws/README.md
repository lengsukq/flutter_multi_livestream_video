# flutter_realtime_provider_aws

Optional AWS RTC provider bundle for [Flutter Realtime SDK](https://github.com/lengsukq/flutter_multi_livestream_video). The **single public provider ID `aws`** routes Meeting to Amazon Chime and Live broadcasts to Amazon IVS Real-Time. Native and Web drivers differ; always check runtime capabilities.

> **Not yet published on pub.dev**; still uses local monorepo dependencies and `publish_to: none`. See [release readiness](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/doc/PUB_DEV_RELEASE_GUIDE.zh-CN.md).

```dart
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_provider_aws/flutter_realtime_provider_aws.dart';

final realtime = Realtime(
  backendUrl: 'https://your-backend.example',
  providers: [createAwsProvider()],
);
```

The host needs `flutter_realtime_sdk` and this Provider bundle; optional Product Chat providers (`flutter_realtime_provider_ivs_chat`, etc.) are separate registrations. The backend creates Chime/IVS rooms and issues short-lived credentials: **never ship AWS access keys or cloud recording credentials in Flutter**.

Cloud recording is a backend feature. Chime, IVS and MP4 export have different provider pipelines and S3/MediaConvert requirements; see [cloud recording](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/doc/CLOUD_RECORDING.md). See [capability matrix](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/doc/SDK_CAPABILITY_MATRIX.zh-CN.md) for macOS/Windows and screen-share constraints.
