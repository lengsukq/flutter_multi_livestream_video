#!/usr/bin/env python3
"""Fetch the pinned Apache-2.0 OpenCV Zoo PPHumanSeg model for Windows."""
import hashlib
import sys
import urllib.request
from pathlib import Path

BASE = "https://huggingface.co/opencv/opencv_zoo/resolve/main/models/human_segmentation_pphumanseg/"
NAME = "human_segmentation_pphumanseg_2023mar.onnx"
SHA256 = "552d8a984054e59b5d773d24b9b12022b22046ceb2bbc4c9aaeaceb36a9ddf24"
OUT = Path(__file__).resolve().parent.parent / "assets" / "windows" / "pphumanseg.onnx"
LICENSE = OUT.with_name("PPHUMANSEG_LICENSE.txt")
LICENSE_URL = (
    "https://raw.githubusercontent.com/opencv/opencv_zoo/main/"
    "models/human_segmentation_pphumanseg/LICENSE"
)


def main() -> int:
    try:
        if OUT.exists() and hashlib.sha256(OUT.read_bytes()).hexdigest() == SHA256:
            print(f"Verified cached model: {OUT}")
        else:
            req = urllib.request.Request(BASE + NAME, headers={"User-Agent": "FlutterVideoModelFetcher/1.0"})
            with urllib.request.urlopen(req, timeout=45) as response:
                data = response.read(16 * 1024 * 1024 + 1)
            if len(data) > 16 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != SHA256:
                raise RuntimeError("Unexpected model size or SHA-256; refusing to cache model")
            OUT.parent.mkdir(parents=True, exist_ok=True)
            OUT.write_bytes(data)
        OUT.parent.mkdir(parents=True, exist_ok=True)
        if not LICENSE.exists():
            req = urllib.request.Request(LICENSE_URL, headers={"User-Agent": "FlutterVideoModelFetcher/1.0"})
            with urllib.request.urlopen(req, timeout=45) as response:
                notice = response.read(65_536)
            if b"Apache License" not in notice[:512] or b"Version 2.0" not in notice[:512]:
                raise RuntimeError("Model license download is not Apache License 2.0")
            LICENSE.write_bytes(notice)
        if b"Apache License" not in LICENSE.read_bytes()[:512]:
            raise RuntimeError("Missing valid model license notice")
        print(f"Verified PPHumanSeg model and license: {OUT}")
        return 0
    except Exception as exc:
        print(f"Model fetch failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
