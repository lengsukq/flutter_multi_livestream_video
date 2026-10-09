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


def build(project: Path, args: list[str], run=subprocess.run) -> int:
    manifest = project / 'pubspec.yaml'
    original = manifest.read_text()
    modified, count = re.subn(
        r'(?m)^([ \t]+enable-swift-package-manager:)[ \t]*true[ \t]*$',
        r'\1 false', original, count=1,
    )
    if count == 0 and not re.search(r'enable-swift-package-manager:\s*false', original):
        raise ValueError('Expected the Demo SwiftPM setting; refusing to rewrite an unknown manifest.')

    # Flutter retains a generated SwiftPM package after disabling SwiftPM.
    # Its empty product keeps the Xcode project valid while CocoaPods alone
    # embeds frameworks, avoiding duplicate framework build outputs.
    swift_manifest = project / 'macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift'
    swift_original = swift_manifest.read_text() if swift_manifest.exists() else None
    backup = project / 'build/macos/pubspec-before-cocoapods.yaml'
    backup.parent.mkdir(parents=True, exist_ok=True)
    backup.write_text(original)
    try:
        manifest.write_text(modified)
        if swift_original is not None:
            swift_manifest.write_text(SWIFT_STUB)
        result = run(['flutter', 'build', 'macos', *(args or ['--release', '--no-pub'])], cwd=project)
        return result.returncode
    finally:
        if swift_original is not None and swift_manifest.exists() and swift_manifest.read_text() == SWIFT_STUB:
            swift_manifest.write_text(swift_original)
        if manifest.read_text() == modified:
            manifest.write_text(original)
        else:
            print(f'Manifest changed during the build; newer edits preserved. Original backup: {backup}', file=sys.stderr)


def stop(_signal, _frame):
    raise KeyboardInterrupt


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, stop)
    raise SystemExit(build(Path(__file__).resolve().parents[1] / 'example', sys.argv[1:]))
