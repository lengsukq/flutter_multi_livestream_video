#!/usr/bin/env python3
"""Verify a *real* finalized MP4/WebM recording using ffprobe.

Usage:
  python3 scripts/verify_recording.py path/to/recording.mp4
  python3 scripts/verify_recording.py recording.mp4 --require-audio --min-seconds 3

An existing nonempty file by itself does not count as a valid recording.
Requires ffprobe (from FFmpeg) on PATH. No network or SDK vendor credentials.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys


def evaluate_probe(
    payload: dict, *, require_audio: bool = False, min_seconds: float = 1.0
) -> tuple[bool, list[str]]:
    """Return an objective validation verdict and any failures."""
    errors: list[str] = []
    streams = payload.get("streams") or []
    metadata = payload.get("format") or {}
    videos = [stream for stream in streams if stream.get("codec_type") == "video"]
    audios = [stream for stream in streams if stream.get("codec_type") == "audio"]
    if not videos:
        errors.append("No encoded video track.")
    elif not any(
        (stream.get("width") or 0) > 0
        and (stream.get("height") or 0) > 0
        and stream.get("codec_name") not in (None, "unknown")
        for stream in videos
    ):
        errors.append("Video track lacks valid dimensions or a recognized codec.")
    if require_audio and not audios:
        errors.append("No encoded audio track (requested --require-audio).")
    try:
        duration = float(metadata.get("duration", 0))
    except (TypeError, ValueError):
        duration = 0
    if duration < min_seconds:
        errors.append(f"Duration {duration:.2f}s is under {min_seconds:.2f}s.")
    try:
        size = int(metadata.get("size", 0))
    except (TypeError, ValueError):
        size = 0
    if size <= 0:
        errors.append("Container has zero or unknown size.")
    return not errors, errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path, help="Completed local recording (MP4/WebM).")
    parser.add_argument("--require-audio", action="store_true")
    parser.add_argument("--min-seconds", type=float, default=1.0)
    args = parser.parse_args()
    if args.min_seconds <= 0:
        parser.error("--min-seconds must be positive")
    if not args.file.is_file() or args.file.stat().st_size == 0:
        print(f"FAIL: Missing or empty recording: {args.file}", file=sys.stderr)
        return 1
    try:
        completed = subprocess.run(
            [
                "ffprobe", "-v", "error", "-show_entries",
                "format=format_name,duration,size:stream=codec_type,codec_name,width,height",
                "-of", "json", str(args.file),
            ],
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )
    except FileNotFoundError:
        print(
            "FAIL: ffprobe is required for media validation. Install FFmpeg first.",
            file=sys.stderr,
        )
        return 2
    except subprocess.TimeoutExpired:
        print("FAIL: ffprobe timed out.", file=sys.stderr)
        return 2
    if completed.returncode:
        print(f"FAIL: ffprobe could not decode container: {completed.stderr.strip()}")
        return 1
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError:
        print("FAIL: ffprobe returned invalid JSON.")
        return 1
    passed, failures = evaluate_probe(
        payload, require_audio=args.require_audio, min_seconds=args.min_seconds
    )
    fmt = payload.get("format") or {}
    streams = payload.get("streams") or []
    print(
        f"file={args.file} format={fmt.get('format_name')} "
        f"duration={fmt.get('duration')}s "
        f"streams={[s.get('codec_type') + ':' + str(s.get('codec_name')) for s in streams if s.get('codec_type')]}"
    )
    if not passed:
        for error in failures:
            print(f"FAIL: {error}")
        return 1
    print("PASS: Encoded recording has a real playable video track and valid duration.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
