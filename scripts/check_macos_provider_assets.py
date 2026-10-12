#!/usr/bin/env python3
"""Verify macOS Flutter bundles contain the runtime scripts used by providers.

Run after a Debug/Release build. This also checks the provider-specific asset
URLs referenced by Dart, so a package split cannot silently break a bundle.
"""

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

# Native AWS desktop WebKit uses these exact packages. Other providers load
# scripts from their own packages via the Dart web runtime asset adapters.
AWS_DESKTOP_SCRIPTS = frozenset({
    'packages/flutter_realtime_provider_aws/assets/chime-sdk.js',
    'packages/flutter_realtime_provider_aws/assets/amazon-ivs-web-broadcast.js',
    'packages/flutter_realtime_media_web/assets/media-provider-bridge.js',
    'packages/flutter_realtime_provider_ivs_chat/assets/ivs-chat-provider.js',
})

ASSET_URL = re.compile(r"['\"]assets/(packages/flutter_realtime_[^'\"]+?\.js)['\"]")


def expected_assets(root: Path = ROOT) -> set[str]:
    """Discover literal package JS URLs used by the opt-in Dart providers."""
    assets = set(AWS_DESKTOP_SCRIPTS)
    for dart in sorted((root / 'packages').glob('flutter_realtime_provider_*/lib/src/assets.dart')):
        assets.update(ASSET_URL.findall(dart.read_text(encoding='utf-8')))
    return assets


def missing_assets(app: Path, root: Path = ROOT) -> list[str]:
    flutter_assets = app / 'Contents/Frameworks/App.framework/Resources/flutter_assets'
    return sorted(asset for asset in expected_assets(root)
                  if not (flutter_assets / asset).is_file())


def verify_assets(app: Path, root: Path = ROOT) -> None:
    missing = missing_assets(app, root)
    if missing:
        raise RuntimeError(
            f'{app} is missing {len(missing)} provider runtime asset(s):\n' +
            '\n'.join(f'  {name}' for name in missing)
        )


def main() -> int:
    parser = argparse.ArgumentParser(description='Validate Flutter provider JS assets inside macOS .app.')
    parser.add_argument('--configuration', choices=('Debug', 'Release'), default='Release')
    args = parser.parse_args()
    app = (ROOT / 'example/build/macos/Build/Products' / args.configuration /
           'flutter_aws_chime_example.app')
    try:
        verify_assets(app)
    except RuntimeError as error:
        parser.exit(1, f'{error}\n')
    print(f'OK: {len(expected_assets())} provider JS assets found in {app}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
