#!/usr/bin/env python3
"""Run the macOS Demo in CocoaPods mode with Flutter hot reload enabled."""
import signal
import sys
from pathlib import Path

from build_flutter_macos import debug, stop


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, stop)
    raise SystemExit(debug(Path(__file__).resolve().parents[1] / 'example', sys.argv[1:]))
