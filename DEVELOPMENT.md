# Development notes

## Repository checkout name on iOS

The pub package is named `flutter_aws_chime`, while this GitHub repository is
named `flutter_multi_livestream_video`. Flutter 3.47.x has a Swift Package
Manager issue for local path plugins when the plugin checkout directory name
differs from the Dart package name. Flutter merged the upstream fix on
August 14, 2026, but that change landed after the Flutter 3.47 branch cutoff
and is not present in the current 3.47 stable line.

For local iOS SwiftPM development, clone the repository into a directory named
`flutter_aws_chime`:

```bash
git clone https://github.com/lengsukq/flutter_multi_livestream_video.git flutter_aws_chime
cd flutter_aws_chime
```

This limitation affects the repository's own local `example/` path dependency.
Apps that consume a published package are resolved into a package directory
with the correct package identity and are not affected by this checkout-name
workaround.

The CI workflow intentionally checks out the repository as `flutter_aws_chime`
so the SwiftPM build validates the supported consumer layout.

Upstream issue/fix: <https://github.com/flutter/flutter/issues/186881> and
<https://github.com/flutter/flutter/pull/188647>.

## iOS dependency managers

The plugin supports both:

- Swift Package Manager through `ios/flutter_aws_chime/Package.swift`;
- CocoaPods through `ios/flutter_aws_chime.podspec`.

Both dependency managers compile the same Swift source tree under
`ios/flutter_aws_chime/Sources/flutter_aws_chime`.

## Real-device media verification

See [`DEVICE_E2E.md`](DEVICE_E2E.md) for the opt-in physical-device workflow.
