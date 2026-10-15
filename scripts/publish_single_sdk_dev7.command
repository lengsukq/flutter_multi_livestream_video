#!/bin/bash
# Manual, guarded pub.dev preview publication. This script never auto-confirms.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="0.1.0-dev.7"
PACKAGE="$ROOT/build/pub_release/$VERSION/flutter_realtime_sdk"

if [[ ! -f "$PACKAGE/pubspec.yaml" ]]; then
  echo "Missing staged $VERSION release at: $PACKAGE" >&2
  echo "First run: python3 scripts/assemble_single_sdk_distribution.py" >&2
  echo "Then: python3 scripts/prepare_single_sdk_release.py --version $VERSION" >&2
  exit 1
fi

if ! grep -qx "version: $VERSION" "$PACKAGE/pubspec.yaml"; then
  echo "Refusing to publish: incorrect pubspec.yaml version" >&2
  exit 1
fi

python3 "$ROOT/scripts/verify_single_sdk_web_assets.py" --package "$PACKAGE"
cd "$PACKAGE"
flutter pub get
flutter analyze --no-pub
flutter pub publish --dry-run

printf '\nAbout to publish flutter_realtime_sdk %s to pub.dev. This cannot be undone.\n' "$VERSION"
printf 'Type "PUBLISH %s" to continue: ' "$VERSION"
IFS= read -r confirmation
if [[ "$confirmation" != "PUBLISH $VERSION" ]]; then
  echo "Canceled. No package uploaded."
  exit 0
fi

flutter pub publish
