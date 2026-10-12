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

## macOS validation

The full Demo validates macOS with CocoaPods. Use the command-scoped override:

```sh
FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter build macos --release --no-pub
```

The separate macOS CI job sets this override; iOS retains its existing SwiftPM
configuration and device-target build. Flutter project/global configuration has
higher priority than the environment override. Do not change user-wide settings
just to run this check.

## Apple Silicon release installer and Applications installation

Use an **Apple Silicon Mac** with Flutter, Xcode, CocoaPods, and the Demo's Dart
dependencies installed. On first checkout, resolve packages from `example/`:

```sh
cd example
flutter pub get
cd ..
```

From the **repository root**, run:

```sh
./build_macos_arm64.command
./build_macos_arm64.command --skip-build
```

Or double-click `build_macos_arm64.command` in Finder. It automatically builds
the Demo, creates the DMG, installs/replaces the same application in
`/Applications`, and opens it. If necessary, enable execution once with
`chmod +x build_macos_arm64.command`. The shell entry point invokes the internal
Python packaging utility; you do not need to run a `.py` file yourself.

The command builds `example/` in Release mode through
`scripts/build_flutter_macos.py --release --no-pub` (temporarily using CocoaPods
without changing global Flutter settings), validates that the main executable
contains an **arm64 slice**, and writes a compressed DMG under `dist/macos/`.
The DMG contains the `.app` and an `Applications` shortcut for drag-and-drop.
The default `.command` invocation copies the `.app` into `/Applications` and
replaces existing installations of the same application. Replacement is refused for a
different bundle identifier or symlink and stages the new app before swapping
it into place. Close the previous Demo app before replacing it.

The command launches the installed app; `--skip-build` packages the latest
existing Release artifact without rebuilding. If `/Applications` is not writable
for your account, either use the DMG's drag-and-drop install in Finder (macOS
will request authorization if necessary) or pass
`./build_macos_arm64.command --applications-dir ~/Applications` after creating
that directory.
Do not run the Flutter build itself with `sudo`.

This is a **development DMG**, not a signed/notarized public distribution.
macOS Gatekeeper may require additional approval on other machines. Build
validation proves the main executable supports arm64; it does not replace
device-level tests of bundled media plugins, microphone/camera permissions,
or backend connectivity.
