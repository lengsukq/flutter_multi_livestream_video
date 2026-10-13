#!/usr/bin/env python3
"""Run the Demo's iOS build/debug command with project-local SwiftPM enabled."""
import re
import signal
import subprocess
import sys
from pathlib import Path

from build_flutter_macos import without_generated_swiftpm_dependency


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
