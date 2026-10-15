#!/usr/bin/env python3
"""Stage an unpublished preview package without vendor binaries or local state.

Does not resolve dependencies, download, commit, push, or publish. Run the
normal pub dry-run in the staged directory before deciding to publish.
"""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def _render_readmes(destination: Path, version: str, root: Path) -> None:
    """Stage the English default README and its complete Chinese companion."""
    templates = root / "scripts/templates"
    for filename in ("README.md", "README.zh-CN.md"):
        template_name = f"single_sdk_{filename}"
        content = (templates / template_name).read_text(encoding="utf-8")
        (destination / filename).write_text(
            content.replace("@VERSION@", version), encoding="utf-8"
        )


def _write_inventory(destination: Path) -> int:
    files = {str(path.relative_to(destination)): hashlib.sha256(path.read_bytes()).hexdigest()
             for path in sorted(destination.rglob("*"))
             if path.is_file()
             and not ({".git", ".dart_tool"} & set(path.relative_to(destination).parts))
             and path.name not in {"pubspec.lock", ".flutter-plugins", ".flutter-plugins-dependencies"}}
    (destination.parent / "FILES.sha256.json").write_text(json.dumps(files, indent=2) + "\n")
    return len(files)


def refresh_readmes(version: str, root: Path = ROOT) -> Path:
    """Refresh *only* docs of an unpublished staged version, not binaries/code."""
    if not re.fullmatch(r"0\.1\.0-dev\.[1-9][0-9]*", version):
        raise ValueError("Expected an explicit preview version: 0.1.0-dev.N")
    destination = root / "build/pub_release" / version / "flutter_realtime_sdk"
    pubspec = destination / "pubspec.yaml"
    if not pubspec.is_file() or f"version: {version}" not in pubspec.read_text():
        raise FileNotFoundError("Expected the matching staged preview package")
    _render_readmes(destination, version, root)
    count = _write_inventory(destination)
    metadata = destination.parent / "PREPARATION.json"
    if metadata.exists():
        data = json.loads(metadata.read_text())
        data["fileCount"] = count
        metadata.write_text(json.dumps(data, indent=2) + "\n")
    return destination


def prepare(version: str, root: Path = ROOT) -> Path:
    # Stable releases need a separate acceptance decision. This tool prepares
    # only an explicitly versioned preview, retaining pending evidence as such.
    if not re.fullmatch(r"0\.1\.0-dev\.[1-9][0-9]*", version):
        raise ValueError("Expected an explicit preview version: 0.1.0-dev.N")
    source = root / "build/single_sdk_candidate"
    destination = root / "build/pub_release" / version / "flutter_realtime_sdk"
    if destination.exists():
        raise FileExistsError(f"Release already staged; preserve it or choose a new version: {destination}")
    for required in ("pubspec.yaml", "ios/vendor_frameworks.json", "ios/podfile.rb",
                     "ios/vendor_frameworks.rb", "LICENSE"):
        if not (source / required).is_file():
            raise FileNotFoundError(source / required)

    def ignore(folder, names):
        relative = Path(folder).relative_to(source)
        if relative == Path("."):
            return set(names) & {".git", ".dart_tool", ".flutter-plugins", "pubspec.lock",
                                  ".flutter-plugins-dependencies", "tool", "ASSEMBLY_REPORT.json"}
        if relative == Path("ios"):
            return set(names) & {"Frameworks"}
        return set()

    shutil.copytree(source, destination, ignore=ignore)
    pubspec = destination / "pubspec.yaml"
    content = re.sub(r"(?m)^version:.*$", f"version: {version}", pubspec.read_text())
    content = re.sub(r"(?m)^publish_to:.*\n", "", content)
    content = content.replace("Prototype of a single public Flutter Realtime SDK artifact.",
                              "Provider-neutral realtime media, chat, optional UI and interaction presets in one Flutter plugin.")
    pubspec.write_text(content)
    for platform in ("ios", "macos"):
        spec = destination / platform / "flutter_realtime_sdk.podspec"
        spec.write_text(re.sub(r"s\.version = '[^']+'", f"s.version = '{version}'", spec.read_text()))
    _render_readmes(destination, version, root)
    if version == "0.1.0-dev.1":
        notes = (
            "- First single-package preview combining runtime, providers, optional UI and presets.\n"
            "- Resolve iOS IVS from pinned official archives without bundling vendor binaries.\n"
            "- Include an explicit Podfile integration helper for Agora RTC/Chat duplicate framework embeds.\n"
        )
    else:
        notes = (
            "- Fix camera-off background selection followed by camera-on in external Headless apps.\n"
            "- Add RealtimeRoom.setCameraEnabled with serialized effects/source publication; preserve support for custom effects controllers.\n"
            "- Expose DefaultRealtimeVideoEffects via the single public SDK import, with Headless usage guidance.\n"
            "- Unify default meeting/live virtual-background entries and unsupported-state messaging.\n"
        )
    (destination / "CHANGELOG.md").write_text(
        f"## {version}\n\n"
        + notes
        + "- iOS Simulator, Windows/Linux and real-device vendor acceptance remain pending/unsupported as documented.\n"
    )
    # Parent build/ is ignored by the source checkout. Make Pub's package file
    # inventory independent of that checkout, without creating a source commit.
    subprocess.run(["git", "init", "--quiet"], cwd=destination, check=True)
    file_count = _write_inventory(destination)
    (destination.parent / "PREPARATION.json").write_text(json.dumps({
        "package": "flutter_realtime_sdk", "version": version,
        "published": False, "fileCount": file_count,
        "iosVendorFrameworksIncluded": False,
        "validation": "Run analyze, independent-host iOS build, and pub publish --dry-run; retain their actual results.",
        "pending": ["physical-device vendor E2E", "Windows/Linux builds", "redistribution/license review"],
    }, indent=2) + "\n")
    return destination


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument(
        "--refresh-readmes", action="store_true",
        help="Update only bilingual READMEs and file inventory in an existing unpublished staged version."
    )
    args = parser.parse_args()
    print(
        refresh_readmes(args.version) if args.refresh_readmes
        else prepare(args.version)
    )
