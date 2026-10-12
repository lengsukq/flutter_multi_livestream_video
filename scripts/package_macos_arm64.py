#!/usr/bin/env python3
"""Package the example Flutter macOS Release app as an arm64-capable DMG.

The existing CocoaPods-aware build helper is the only Flutter build entry.
This script never alters SDK source, Xcode project settings, or signing keys.
"""

import argparse
import os
import platform
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[1]


class PackagingError(RuntimeError):
    """A package or install precondition was not met."""


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, check=True, capture_output=False, text=True)


def configuration_value(configuration: Path, name: str) -> str:
    match = re.search(
        rf'(?m)^{re.escape(name)}\s*=\s*([a-zA-Z0-9_.-]+)\s*$',
        configuration.read_text(encoding='utf-8'),
    )
    if not match:
        raise PackagingError(f'Unable to read {name} from {configuration}.')
    return match.group(1)


def app_metadata(app: Path) -> dict:
    if app.is_symlink() or not app.is_dir():
        raise PackagingError(f'Expected a built macOS .app directory: {app}')
    info = app / 'Contents' / 'Info.plist'
    if not info.is_file():
        raise PackagingError(f'Missing macOS app Info.plist: {info}')
    with info.open('rb') as source:
        return plistlib.load(source)


def release_app(repository: Path) -> tuple[Path, str]:
    configuration = repository / 'example/macos/Runner/Configs/AppInfo.xcconfig'
    app_name = configuration_value(configuration, 'PRODUCT_NAME') + '.app'
    bundle_id = configuration_value(configuration, 'PRODUCT_BUNDLE_IDENTIFIER')
    app = repository / 'example/build/macos/Build/Products/Release' / app_name
    return app, bundle_id


def verify_arm64(app: Path, bundle_id: str) -> str:
    metadata = app_metadata(app)
    if metadata.get('CFBundleIdentifier') != bundle_id:
        raise PackagingError('Release app bundle ID differs from the Demo target. Refusing to package it.')
    executable_name = metadata.get('CFBundleExecutable')
    if not isinstance(executable_name, str) or not re.fullmatch(r'[a-zA-Z0-9_.-]+', executable_name):
        raise PackagingError('The app declares an invalid executable name.')
    executable = app / 'Contents/MacOS' / executable_name
    if not executable.is_file() or executable.is_symlink():
        raise PackagingError(f'Missing app executable: {executable}')
    result = subprocess.run(
        ['lipo', '-archs', str(executable)], check=True, capture_output=True, text=True,
    )
    if 'arm64' not in result.stdout.split():
        raise PackagingError(f'The macOS executable lacks arm64: {result.stdout.strip()}')
    version = metadata.get('CFBundleShortVersionString')
    return re.sub(r'[^a-zA-Z0-9.+-]', '-', str(version or 'unknown'))


def make_dmg(app: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Keep the old DMG intact until hdiutil has produced a complete replacement.
    with tempfile.TemporaryDirectory(prefix='.macos-package-', dir=destination.parent) as temporary:
        temporary_dir = Path(temporary)
        volume = temporary_dir / 'volume'
        volume.mkdir()
        run(['ditto', str(app), str(volume / app.name)])
        (volume / 'Applications').symlink_to('/Applications', target_is_directory=True)
        image = temporary_dir / 'package.dmg'
        run([
            'hdiutil', 'create', '-srcfolder', str(volume),
            '-volname', 'Flutter Realtime Demo', '-format', 'UDZO',
            '-o', str(image),
        ])
        os.replace(image, destination)


def install_app(app: Path, bundle_id: str, applications: Path, *, replace: bool) -> Path:
    applications = applications.expanduser()
    if not applications.is_dir():
        raise PackagingError(f'Applications directory does not exist: {applications}')
    destination = applications / app.name
    if destination.is_symlink():
        raise PackagingError(f'Refusing to overwrite an application symlink: {destination}')
    if destination.exists():
        if app_metadata(destination).get('CFBundleIdentifier') != bundle_id:
            raise PackagingError(f'Existing app has a different bundle ID: {destination}')
        if not replace:
            raise PackagingError(f'{destination} exists; pass --replace to update the same application.')

    # Stage first so a failed copy does not damage an existing installation.
    staging_dir = Path(tempfile.mkdtemp(prefix=f'.{app.stem}-stage-', dir=applications))
    staged = staging_dir / app.name
    backup = applications / f'.{app.stem}-backup-{uuid.uuid4().hex}.app'
    try:
        run(['ditto', str(app), str(staged)])
        if app_metadata(staged).get('CFBundleIdentifier') != bundle_id:
            raise PackagingError('Staged application has an unexpected bundle ID.')
        moved_previous = False
        if destination.exists():
            destination.rename(backup)
            moved_previous = True
        try:
            staged.rename(destination)
        except Exception:
            if moved_previous:
                backup.rename(destination)
            raise
        if moved_previous:
            shutil.rmtree(backup)
    finally:
        shutil.rmtree(staging_dir, ignore_errors=True)
    return destination


def main(argv: list[str] | None = None, *, repository: Path = REPOSITORY) -> int:
    parser = argparse.ArgumentParser(description='Build the Flutter Demo macOS arm64 DMG.')
    parser.add_argument('--skip-build', action='store_true', help='Package a previously built Release app.')
    parser.add_argument('--install', action='store_true', help='Also copy the app to /Applications.')
    parser.add_argument('--replace', action='store_true', help='Replace a previous install with the same bundle ID.')
    parser.add_argument('--open', action='store_true', help='Launch the app after installing it.')
    parser.add_argument('--applications-dir', type=Path, default=Path('/Applications'),
                        help='Installation target (default: /Applications; supports ~/Applications).')
    options = parser.parse_args(argv)
    if options.open and not options.install:
        parser.error('--open requires --install')
    if options.replace and not options.install:
        parser.error('--replace requires --install')

    try:
        if platform.system() != 'Darwin' or platform.machine() != 'arm64':
            raise PackagingError('Build this Apple Silicon package on an arm64 Mac with Xcode installed.')
        app, bundle_id = release_app(repository)
        if not options.skip_build:
            run([
                sys.executable, str(repository / 'scripts/build_flutter_macos.py'),
                '--release', '--no-pub',
            ], cwd=repository)
        version = verify_arm64(app, bundle_id)
        dmg = repository / 'dist/macos' / f'{app.stem}-{version}-arm64.dmg'
        make_dmg(app, dmg)
        print(f'DMG: {dmg}')
        if options.install:
            try:
                installed = install_app(app, bundle_id, options.applications_dir, replace=options.replace)
            except PermissionError as error:
                raise PackagingError(
                    f'Cannot write to {options.applications_dir}. Grant access or choose '
                    '--applications-dir ~/Applications. The DMG was created successfully.'
                ) from error
            print(f'Installed: {installed}')
            if options.open:
                run(['open', '-a', str(installed)])
        return 0
    except (PackagingError, subprocess.CalledProcessError, OSError) as error:
        print(f'macOS packaging failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
