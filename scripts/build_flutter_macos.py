#!/usr/bin/env python3
"""Build the Demo with CocoaPods without changing global Flutter settings.

The Demo enables SwiftPM for iOS-only IVS packages. Flutter 3.47 gives that
manifest value precedence over FLUTTER_SWIFT_PACKAGE_MANAGER=false, so macOS
needs a scoped manifest override for Iris' FlutterMacOS linkage.
"""
import re
import signal
import subprocess
import sys
from pathlib import Path

project = Path(__file__).resolve().parents[1] / 'example'
manifest = project / 'pubspec.yaml'
original = manifest.read_text()
modified, count = re.subn(r'(?m)^([ \t]+enable-swift-package-manager:)[ \t]*true[ \t]*$', r'\1 false', original, count=1)
if count == 0 and not re.search(r'enable-swift-package-manager:\s*false', original):
    raise SystemExit('Expected the Demo SwiftPM setting; refusing to rewrite an unknown manifest.')
backup = project / 'build' / 'macos' / 'pubspec-before-cocoapods.yaml'
backup.parent.mkdir(parents=True, exist_ok=True)
backup.write_text(original)

def stop(_signal, _frame):
    raise KeyboardInterrupt

signal.signal(signal.SIGTERM, stop)
try:
    manifest.write_text(modified)
    args = sys.argv[1:] or ['--release', '--no-pub']
    result = subprocess.run(['flutter', 'build', 'macos', *args], cwd=project)
finally:
    if manifest.read_text() == modified:
        manifest.write_text(original)
    else:
        print(f'Manifest changed during the build; newer edits preserved. Original backup: {backup}', file=sys.stderr)
raise SystemExit(result.returncode)
