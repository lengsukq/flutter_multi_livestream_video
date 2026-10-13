#!/usr/bin/env python3
"""Use CocoaPods for the Demo build without changing global Flutter settings."""
import re
import signal
import subprocess
import sys
from pathlib import Path

SWIFT_STUB = '''// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "FlutterGeneratedPluginSwiftPackage",
  platforms: [.macOS("12.0")],
  products: [.library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])],
  dependencies: [],
  targets: [.target(name: "FlutterGeneratedPluginSwiftPackage", dependencies: [])]
)
'''

# Flutter may re-add its generated SwiftPM dependency to Runner when `flutter
# pub get` is run with SwiftPM enabled for the project's iOS plugins. macOS
# builds must use only CocoaPods: every macOS plugin has a podspec, while
# linking both copies makes Xcode 27 fail to resolve iris_method_channel_objc.
# These are the Flutter-generated Xcode project IDs, not user-owned packages.
GENERATED_SWIFTPM_IDS = frozenset({
    '78A318202AECB46A00862997',  # Swift package in Frameworks build phase
    '78E0A7A72DC9AD7400C4905E',  # Swift package file reference
    '781AD8BC2B33823900A9FFBB',  # Local Swift package reference
    '78A3181F2AECB46A00862997',  # Swift package product dependency
})


def without_generated_swiftpm_dependency(project_file: str) -> str:
    """Remove only Flutter's generated SwiftPM reference from macOS Runner.

    This is intentionally persistent: Flutter pub get may regenerate the Xcode
    project, and the next macOS build must repair it again. Keep the project's
    iOS SwiftPM configuration intact. Never modify unrelated Xcode objects.
    """
    matched = set()
    result = []
    drop_object = False
    for line in project_file.splitlines(keepends=True):
        if drop_object:
            if line.startswith('\t\t};'):
                drop_object = False
            continue
        found = [item for item in GENERATED_SWIFTPM_IDS if item in line]
        if found:
            matched.update(found)
            if line.startswith('\t\t') and ' = {' in line and not line.rstrip().endswith('};'):
                drop_object = True
            continue
        result.append(line)
    if drop_object:
        raise ValueError('Unexpected generated SwiftPM object layout in Runner.')
    if matched and matched != GENERATED_SWIFTPM_IDS:
        raise ValueError('Incomplete generated SwiftPM wiring in Runner; refusing partial removal.')
    return ''.join(result)


def with_cocoapods(project: Path, command: list[str], run=subprocess.run) -> int:
    """Run a macOS Flutter command with CocoaPods without changing iOS config.

    A `flutter run` process inherits the terminal's stdin/stdout, so hot reload
    stays interactive until the user quits. The manifest is restored afterward.
    """
    manifest = project / 'pubspec.yaml'
    original = manifest.read_text()
    modified, count = re.subn(
        r'(?m)^([ \t]+enable-swift-package-manager:)[ \t]*true[ \t]*$',
        r'\1 false', original, count=1,
    )
    if count == 0 and not re.search(r'enable-swift-package-manager:\s*false', original):
        raise ValueError('Expected the Demo SwiftPM setting; refusing to rewrite an unknown manifest.')

    # Remove the macOS-only SwiftPM product left in Runner by earlier `pub get`
    # runs. Running only with a stub Package.swift does not prevent Xcode 27
    # from scanning stale SwiftPM modules. Keep the pbxproj canonical; do not
    # restore the duplicate dependency after this macOS build.
    runner_project = project / 'macos/Runner.xcodeproj/project.pbxproj'
    if runner_project.is_file():
        before = runner_project.read_text()
        after = without_generated_swiftpm_dependency(before)
        if after != before:
            runner_project.write_text(after)

    # Flutter can retain a generated SwiftPM package after disabling SwiftPM.
    # Do not let a stale package manifest pull in the same native frameworks
    # while the macOS CocoaPods build is running.
    swift_manifest = project / 'macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift'
    swift_original = swift_manifest.read_text() if swift_manifest.exists() else None
    backup = project / 'build/macos/pubspec-before-cocoapods.yaml'
    backup.parent.mkdir(parents=True, exist_ok=True)
    backup.write_text(original)
    try:
        manifest.write_text(modified)
        if swift_original is not None:
            swift_manifest.write_text(SWIFT_STUB)
        result = run(command, cwd=project)
        return result.returncode
    finally:
        if swift_original is not None and swift_manifest.exists() and swift_manifest.read_text() == SWIFT_STUB:
            swift_manifest.write_text(swift_original)
        if manifest.read_text() == modified:
            manifest.write_text(original)
        else:
            print(f'Manifest changed during the build; newer edits preserved. Original backup: {backup}', file=sys.stderr)


def build(project: Path, args: list[str], run=subprocess.run) -> int:
    return with_cocoapods(project, ['flutter', 'build', 'macos', *(args or ['--release', '--no-pub'])], run)


def debug(project: Path, args: list[str], run=subprocess.run) -> int:
    """Launch the normal Flutter debug tool (including hot reload and restart)."""
    return with_cocoapods(project, ['flutter', 'run', '-d', 'macos', *(args or [])], run)


def stop(_signal, _frame):
    raise KeyboardInterrupt


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, stop)
    raise SystemExit(build(Path(__file__).resolve().parents[1] / 'example', sys.argv[1:]))
