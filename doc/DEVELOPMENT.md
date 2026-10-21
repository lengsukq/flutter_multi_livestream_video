# Development notes

## Repository checkout name on iOS

The pub package is named `flutter_aws_chime`, while this GitHub repository is
named `multi-video`. Flutter 3.47.x has a Swift Package
Manager issue for local path plugins when the plugin checkout directory name
differs from the Dart package name. Flutter merged the upstream fix on
August 14, 2026, but that change landed after the Flutter 3.47 branch cutoff
and is not present in the current 3.47 stable line.

For local iOS SwiftPM development, clone the repository into a directory named
`flutter_aws_chime`:

```bash
git clone https://github.com/lengsukq/multi-video.git flutter_aws_chime
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

The full Demo defaults to CocoaPods so normal macOS IDE debug runs work.
Its iOS IVS Media/Chat plugins require SwiftPM. From the repository root, use:

```sh
python3 scripts/flutter_ios.py build ios --release --no-codesign
python3 scripts/flutter_ios.py run -d <ios-device-id>
```

This helper enables SwiftPM only for the command, resolves Dart dependencies
from the local cache, then restores the Demo configuration and removes generated
macOS SwiftPM references. It does not change global Flutter settings. Use this
entry point for full Demo iOS builds/debugging; a direct iOS run with the default
configuration cannot register the SwiftPM-only IVS plugins. Run Apple platform
commands one at a time because they share generated plugin files.

## Real-device media verification

See [`DEVICE_E2E.md`](DEVICE_E2E.md) for the opt-in physical-device workflow.

## macOS validation

The full Demo uses CocoaPods by default, including normal IDE debug runs:

```sh
cd example
flutter run -d macos
```

If Flutter previously generated SwiftPM macOS Runner references, or if you want
a standalone interactive CocoaPods-only entrypoint, run from the repo root:

```sh
./run_macos_debug.command
# or: python3 scripts/run_flutter_macos.py --debug
```

This invokes the real `flutter run -d macos --debug` command (not a build-only
launch): use `r` to hot reload, `R` to restart and `q` to quit. It also removes
stale generated SwiftPM Runner dependencies before launching, and restores the
original `pubspec.yaml` configuration when the session ends. VS Code users can
choose **Terminal → Run Task → Flutter macOS Debug (CocoaPods + Hot Reload)**.
Run only one macOS/iOS Flutter command at a time against this Demo.

The project setting applies before the environment/global feature flag. Do not
change user-wide settings to run this check. The macOS build helper also repairs
generated Runner references left by earlier SwiftPM builds.

### Validate desktop provider runtime assets

After building the Demo on macOS, check that all provider JS entrypoints are
included in the native Flutter asset bundle:

```sh
python3 scripts/check_macos_provider_assets.py --configuration Debug
python3 scripts/check_macos_provider_assets.py --configuration Release
python3 -m unittest discover -s scripts/tests
```

The arm64 DMG packager runs the Release asset check automatically **before**
creating or installing the app. Native AWS WebKit loads Chime/IVS JavaScript
from `flutter_realtime_provider_aws`, the shared media bridge from
`flutter_realtime_media_web`, and IVS Chat from
`flutter_realtime_provider_ivs_chat`. The core `flutter_realtime_sdk` package
does not bundle these optional provider scripts. Do not hardcode the old
`flutter_realtime_sdk/assets/provider_web_runtime` path in native plugins.

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
The macOS Runner uses **CocoaPods only**: the generated Flutter SwiftPM product
was removed from `example/macos/Runner.xcodeproj`, avoiding Xcode 27 errors
resolving `iris_method_channel_objc` and `RealtimeNativeFrameSinks` when the
same plugins are provided by CocoaPods. The helper also removes those generated
Runner references again if Flutter recreates them after dependency changes.
The project-level `enable-swift-package-manager: false` setting in
`example/pubspec.yaml` also covers direct macOS build/debug commands. For iOS
IVS Media/Chat, use `scripts/flutter_ios.py` as described above; it temporarily
enables SwiftPM and restores the default afterwards.
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

### macOS build lock troubleshooting

The one-click packager holds an advisory lock at
`example/.dart_tool/macos-arm64-package.lock` for its full build/package/install
run. Starting another `.command` while the first is active exits with the
current packager PID instead of letting two builds contend for Xcode's
`XCBuildData/build.db`. The lock is automatically released on normal exit,
failure, or process termination; **do not delete the lock file** (it is
deliberately persistent to avoid races). `--skip-build` also takes this lock
to avoid two installers replacing the same `.app` simultaneously.

Before compiling, the script checks for external builders currently holding
`example/build/macos/Build/Intermediates.noindex/XCBuildData/build.db` via
`lsof` and reports the process names/PIDs. It never kills processes or clears
build files automatically. To diagnose an unexpected `database is locked`
error, stop or wait for the other Flutter/Xcode build first. Once **all**
builds have exited, you may remove only the generated `XCBuildData` directory
and retry; it is unsafe to remove it while Xcode still holds it open. The
`iris_method_channel` / `RealtimeNativeFrameSinks` module resolution errors
are unrelated Swift Package Manager/CocoaPods integration problems and will
not be fixed by deleting `build.db`.

This is a **development DMG**, not a signed/notarized public distribution.
macOS Gatekeeper may require additional approval on other machines. Build
validation proves the main executable supports arm64; it does not replace
device-level tests of bundled media plugins, microphone/camera permissions,
or backend connectivity.
