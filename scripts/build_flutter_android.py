#!/usr/bin/env python3
"""Build the Demo release with runtime plugins, restoring development dependencies."""
import re
import signal
import subprocess
import sys
from pathlib import Path


def build(project: Path, arguments: list[str], run=subprocess.run) -> int:
    manifest = project / 'pubspec.yaml'
    original = manifest.read_text()
    # Flutter's --no-pub release path can retain the integration-test registrant,
    # while its Gradle loader excludes that dev plugin. Refresh both from one
    # temporary manifest; never manually rewrite GeneratedPluginRegistrant.
    modified, count = re.subn(r'(?m)^  integration_test:\n    sdk: flutter\n', '', original)
    if count != 1:
        raise ValueError('Expected one SDK integration_test development dependency.')
    backup = project / 'build/android/pubspec-before-release.yaml'
    backup.parent.mkdir(parents=True, exist_ok=True)
    backup.write_text(original)
    try:
        manifest.write_text(modified)
        resolved = run(['flutter', 'pub', 'get', '--offline'], cwd=project)
        if resolved.returncode:
            return resolved.returncode
        return run(['flutter', 'build', 'apk', *(arguments or ['--release', '--no-pub'])], cwd=project).returncode
    finally:
        if manifest.read_text() == modified:
            manifest.write_text(original)
            restored = run(['flutter', 'pub', 'get', '--offline'], cwd=project)
            if restored.returncode:
                print('Development plugin metadata restore failed; run offline pub get before tests.', file=sys.stderr)
        else:
            print(f'Concurrent manifest edits preserved. Original backup: {backup}', file=sys.stderr)


def stop(_signal, _frame):
    raise KeyboardInterrupt


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, stop)
    raise SystemExit(build(Path(__file__).resolve().parents[1] / 'example', sys.argv[1:]))
