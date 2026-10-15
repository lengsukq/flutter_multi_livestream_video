#!/bin/bash
# Publish only the already prepared single-package dev.6 SDK.
# Does not rebuild or overwrite a staged version; never auto-confirms upload.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="0.1.0-dev.6"
PACKAGE="$ROOT/build/pub_release/$VERSION/flutter_realtime_sdk"

if [[ ! -f "$PACKAGE/pubspec.yaml" ]]; then
  echo "Release package not found: $PACKAGE" >&2
  echo "Generate and verify the dev.6 release candidate first." >&2
  exit 1
fi
if ! grep -qx "version: $VERSION" "$PACKAGE/pubspec.yaml"; then
  echo "Refusing to publish: pubspec.yaml does not contain version: $VERSION" >&2
  exit 1
fi

python3 "$ROOT/scripts/verify_single_sdk_web_assets.py" --package "$PACKAGE"

cd "$PACKAGE"
flutter pub get
flutter analyze --no-pub
flutter pub publish --dry-run

printf '\nThe irreversible upload target is pub.dev / flutter_realtime_sdk %s.\n' "$VERSION"
printf 'Type "PUBLISH %s" to continue, anything else to cancel: ' "$VERSION"
IFS= read -r approval
if [[ "$approval" != "PUBLISH $VERSION" ]]; then
  echo "Canceled: nothing was uploaded."
  exit 0
fi

# Flutter pub also prompts for confirmation; check its displayed version.
flutter pub publish
