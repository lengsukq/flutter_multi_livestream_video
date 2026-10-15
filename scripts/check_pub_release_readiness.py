#!/usr/bin/env python3
"""Read-only metadata linter for the 44 *internal development* SDK modules.

This is NOT the single published flutter_realtime_sdk release gate. Use
audit_single_pub_package.py, a real bundled plugin build, then pub dry-run.
No PyYAML, network access, credential access, or modification of pubspec files.
"""

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
PACKAGES = ROOT / "packages"
OWNED = json.loads((ROOT / "scripts" / "sdk_packages.json").read_text())


def field(source: str, key: str) -> str:
    found = re.search(rf"(?m)^{re.escape(key)}:\s*(.*?)\s*$", source)
    return found.group(1).strip(" '\"") if found else ""


def check(name: str) -> tuple[str, list[str]]:
    folder = PACKAGES / name
    pubspec = folder / "pubspec.yaml"
    if not pubspec.is_file():
        return name, ["pubspec.yaml missing"]
    source = pubspec.read_text(encoding="utf-8")
    issues: list[str] = []
    if field(source, "name") != name:
        issues.append("pubspec name mismatch")
    for filename in ("README.md", "CHANGELOG.md", "LICENSE"):
        if not (folder / filename).is_file():
            issues.append(f"missing {filename}")
    if not field(source, "version"):
        issues.append("missing version")
    if not field(source, "description"):
        issues.append("missing description")
    if not (field(source, "repository") or field(source, "homepage")):
        issues.append("missing repository/homepage")
    if field(source, "publish_to") == "none":
        issues.append("publish_to: none")
    # Pub disallows path dependencies even if they appear in dev_dependencies.
    count = len(re.findall(r"(?m)^\s+path:\s*[^\s#]+", source))
    if count:
        issues.append(f"{count} local path dependencies")
    if not (folder / "lib" / f"{name}.dart").is_file():
        issues.append("missing public lib entrypoint")
    return name, issues


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--package", action="append",
        help="Restrict to named owned package; may be repeated",
    )
    parser.add_argument(
        "--report-only", action="store_true",
        help="Return zero even if publication blockers remain",
    )
    args = parser.parse_args()
    names = args.package or OWNED
    unknown = sorted(set(names) - set(OWNED))
    if unknown:
        parser.error(f"unknown/unowned packages: {', '.join(unknown)}")

    failed = 0
    for name in names:
        label, issues = check(name)
        if issues:
            failed += 1
        print(f"{'BLOCKED' if issues else 'READY'} {label}: "
              f"{', '.join(issues) if issues else 'metadata files present'}")
    print(
        f"Checked {len(names)} internal modules; {failed} cannot be published "
        "independently (independent publication is NOT the product target)."
    )
    print("Reminder: license ownership, binary redistribution, real device E2E "
          "and dart pub publish --dry-run require separate manual checks.")
    return 0 if args.report_only or failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
