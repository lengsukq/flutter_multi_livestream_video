#!/usr/bin/env python3
"""Run the Demo's iOS build/debug command with project-local SwiftPM enabled."""
import re
import signal
import subprocess
import sys
from pathlib import Path

from build_flutter_macos import without_generated_swiftpm_dependency


_FLUTTER_FRAMEWORK_PACKAGE = '''// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "FlutterFramework",
    platforms: [.iOS("15.0")],
    products: [.library(name: "FlutterFramework", targets: ["Flutter"])],
    targets: [.binaryTarget(name: "Flutter", path: "Flutter.xcframework")]
)
'''


def ensure_flutter_framework_dependencies(project: Path) -> None:
    """Repair missing local SwiftPM Flutter wrappers used by native plugins.

    Flutter only creates these wrappers for some plugins. Their Package.swift
    files still refer to ../FlutterFramework, so Xcode cannot resolve a fresh
    checkout unless the missing local binary packages are bootstrapped.
    """
    packages = project.parent / 'packages'
    plugin_manifests = list(packages.glob('*/ios/*/Package.swift'))
    required = [
        manifest.parent.parent / 'FlutterFramework'
        for manifest in plugin_manifests
        if '.package(name: "FlutterFramework", path: "../FlutterFramework")'
        in manifest.read_text()
    ]
    if not required:
        return
    generated = project / 'ios/Flutter/Generated.xcconfig'
    settings = generated.read_text() if generated.is_file() else ''
    match = re.search(r'(?m)^FLUTTER_ROOT=(.+)$', settings)
    if not match:
        raise RuntimeError('Run flutter pub get to generate ios/Flutter/Generated.xcconfig first.')
    framework = (Path(match.group(1).strip()) /
                 'bin/cache/artifacts/engine/ios/Flutter.xcframework')
    if not framework.exists():
        raise RuntimeError('Flutter iOS engine is missing. Run flutter precache --ios.')
    for folder in required:
        folder.mkdir(parents=True, exist_ok=True)
        package_manifest = folder / 'Package.swift'
        if not package_manifest.exists():
            package_manifest.write_text(_FLUTTER_FRAMEWORK_PACKAGE)
        binary = folder / 'Flutter.xcframework'
        if binary.is_symlink() and not binary.exists():
            binary.unlink()
        if not binary.exists():
            binary.symlink_to(framework, target_is_directory=True)


def run_ios(project: Path, args: list[str], run=subprocess.run) -> int:
    if not args or (args[0] != 'run' and args[:2] != ['build', 'ios']):
        raise ValueError('Use build ios [options] or run -d <iOS device> [options].')
    manifest = project / 'pubspec.yaml'
    original = manifest.read_text()
    modified, count = re.subn(
        r'(?m)^([ \t]+enable-swift-package-manager:)[ \t]*(?:true|false)[ \t]*$',
        r'\1 true', original, count=1,
    )
    if count != 1:
        raise ValueError('Expected the Demo SwiftPM setting; refusing an unknown manifest.')
    backup = project / 'build/ios/pubspec-before-swiftpm.yaml'
    backup.parent.mkdir(parents=True, exist_ok=True)
    backup.write_text(original)
    try:
        manifest.write_text(modified)
        resolved = run(['flutter', 'pub', 'get', '--offline'], cwd=project)
        if resolved.returncode != 0:
            return resolved.returncode
        ensure_flutter_framework_dependencies(project)
        return run(['flutter', *args], cwd=project).returncode
    finally:
        if manifest.read_text() == modified:
            manifest.write_text(original)
            # iOS pub get also wires SwiftPM into macOS Runner. Remove only
            # Flutter's generated macOS dependency before the next IDE run.
            runner = project / 'macos/Runner.xcodeproj/project.pbxproj'
            if runner.is_file():
                runner.write_text(without_generated_swiftpm_dependency(runner.read_text()))
        else:
            print(f'Manifest changed during the command; newer edits preserved. Backup: {backup}', file=sys.stderr)


def stop(_signal, _frame):
    raise KeyboardInterrupt


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, stop)
    raise SystemExit(run_ios(Path(__file__).resolve().parents[1] / 'example', sys.argv[1:]))
