#!/usr/bin/env python3
"""Validate hosted SDK Flutter Web asset packaging before pub.dev publication.

Optionally check a real host's 'flutter build web' output and AssetManifest.
No network, credentials, source mutations or publishing.
"""
import argparse
import base64
import json
from pathlib import Path

EFFECTS_PREFIX = "assets/bundled/flutter_realtime_video_effects/web/"
PUBLIC_PREFIX = "assets/packages/flutter_realtime_sdk/"
OLD_JS_PREFIX = "assets/packages/flutter_realtime_video_effects/assets/web/"
REQUIRED = (
    "vision.js",
    "video-effects-bridge.js",
    "models/selfie_segmenter_landscape.tflite",
    "models/blaze_face_short_range.tflite",
    "wasm/vision_wasm_internal.wasm",
    "wasm/vision_wasm_nosimd_internal.wasm",
    "wasm/vision_wasm_internal.js",
    "wasm/vision_wasm_nosimd_internal.js",
)


def verify(package: Path, web_build: Path | None = None) -> None:
    package = package.resolve()
    spec = (package / "pubspec.yaml").read_text(encoding="utf-8")
    for file in (package / "assets/bundled").rglob("*"):
        if not file.is_file():
            continue
        entry = f"    - {file.parent.relative_to(package).as_posix()}/"
        if entry not in spec:
            raise AssertionError(
                f"Flutter directory assets are not recursive: {entry} "
                f"must be declared for {file.relative_to(package)}"
            )
    for name in REQUIRED:
        asset = package / EFFECTS_PREFIX / name
        if not asset.is_file() or asset.stat().st_size == 0:
            raise AssertionError(f"Missing/empty hosted SDK asset: {asset}")
    bridge = (package / EFFECTS_PREFIX / "video-effects-bridge.js").read_text()
    expected_prefix = PUBLIC_PREFIX + EFFECTS_PREFIX
    if OLD_JS_PREFIX in bridge or expected_prefix not in bridge:
        raise AssertionError("Video-effects JS still points to old standalone package assets.")
    dart_loader = (
        package
        / "lib/src/_bundled/flutter_realtime_video_effects/src/video_effects_assets_web.dart"
    ).read_text()
    if expected_prefix not in dart_loader:
        raise AssertionError("Dart loader and bundled JS must use the same hosted asset prefix.")

    if web_build is not None:
        web_build = web_build.resolve()
        manifest = web_build / "assets/AssetManifest.bin.json"
        if not manifest.is_file():
            raise AssertionError(f"Flutter Web AssetManifest missing: {manifest}")
        encoded = json.loads(manifest.read_text(encoding="utf-8"))
        # Modern Flutter writes a base64-encoded binary map in
        # AssetManifest.bin.json, not JSON object keys.
        manifest_bytes = (
            base64.b64decode(encoded) if isinstance(encoded, str) else None
        )
        keys = encoded if isinstance(encoded, dict) else None
        for name in REQUIRED:
            key = (expected_prefix + name).removeprefix("assets/")
            if (
                (keys is not None and key not in keys)
                or (
                    manifest_bytes is not None
                    and key.encode("utf-8") not in manifest_bytes
                )
            ):
                raise AssertionError(f"AssetManifest missing packaged asset: {key}")
            output = web_build / PUBLIC_PREFIX / EFFECTS_PREFIX / name
            if not output.is_file() or output.stat().st_size == 0:
                raise AssertionError(f"Missing built Web asset: {output}")
        print(f"PASS: independent Web build contains {len(REQUIRED)} required effects assets")
    print(f"PASS: hosted SDK Web asset manifest, JS URLs and {len(REQUIRED)} resources")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--web-build", type=Path)
    args = parser.parse_args()
    verify(args.package, args.web_build)


if __name__ == "__main__":
    main()
