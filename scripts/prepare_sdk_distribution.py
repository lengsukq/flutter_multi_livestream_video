#!/usr/bin/env python3
"""Prepare LEGACY development-only multi-module Git-host manifests.

This is not the one-package pub.dev release assembler. New distributions must
follow scripts/assemble_single_sdk_candidate.py and the native plugin merge.
"""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INVENTORY = ROOT / 'scripts/sdk_packages.json'
DEFAULT_OUTPUT = ROOT / 'doc/distribution'
REPOSITORY = 'https://github.com/lengsukq/multi-video.git'
CANDIDATE = 'REPLACE_WITH_40_CHARACTER_RELEASE_COMMIT_SHA'
COMBINATIONS = {
    'media': ['flutter_realtime_sdk', 'flutter_realtime_provider_livekit'],
    'chat': ['flutter_realtime_sdk', 'flutter_realtime_provider_ivs_chat'],
    'room_ui': ['flutter_realtime_sdk', 'flutter_realtime_provider_livekit', 'flutter_realtime_room_ui'],
    'full': ['flutter_realtime_sdk', 'flutter_realtime_provider_livekit', 'flutter_realtime_provider_ivs_chat', 'flutter_realtime_sdk_ui', 'flutter_realtime_room_ui', 'flutter_realtime_video_effects', 'flutter_realtime_classroom_preset', 'flutter_realtime_shared_content_preset', 'flutter_realtime_screen_annotation', 'flutter_realtime_live_preset'],
}


def package_record(name: str) -> dict:
    folder = ROOT / 'packages' / name
    manifest = (folder / 'pubspec.yaml').read_text()
    version = re.search(r'^version:\s*([^\n]+)', manifest, re.M).group(1)
    if not (folder / 'LICENSE').is_file():
        raise ValueError(f'{name}: missing package license')
    resources = [p for prefix in ['assets', 'macos/Resources', 'ios/Resources'] for p in (folder / prefix).rglob('*') if p.is_file()]
    assets = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(resources)}
    # Every declared directory/file must exist before a Git consumer can use it.
    for asset in re.findall(r'^    - ([^\n]+)', manifest, re.M):
        if not (folder / asset.strip()).exists():
            raise ValueError(f'{name}: missing declared asset {asset}')
    return {'name': name, 'version': version, 'path': f'packages/{name}', 'license': f'packages/{name}/LICENSE', 'resourceSha256': assets}


def git_dependencies(names: list[str], git_ref: str) -> str:
    lines = [
        '# DEVELOPMENT/LEGACY MULTI-MODULE MANIFEST, NOT A pub.dev RELEASE.',
        '# Final public SDK target is ONE flutter_realtime_sdk package.',
        '# Replace every ref with the same reviewed immutable commit.',
        'dependencies:', '  flutter:', '    sdk: flutter',
    ]
    for name in names:
        lines += [f'  {name}:', '    git:', f'      url: {REPOSITORY}', f'      ref: {git_ref}', f'      path: packages/{name}']
    if 'flutter_realtime_provider_livekit' in names:
        lines += ['dependency_overrides:', '  flutter_webrtc:', '    git:', f'      url: {REPOSITORY}', f'      ref: {git_ref}', '      path: packages/flutter_webrtc']
    return '\n'.join(lines) + '\n'


def prepare(output: Path, git_ref: str = CANDIDATE) -> dict:
    names = json.loads(INVENTORY.read_text())
    manifest = {
        'schemaVersion': 1,
        'releaseRef': None if git_ref == CANDIDATE else git_ref,
        'gitFetchVerified': False,
        'preparedFromHead': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'workingTreeSnapshot': True,
        'packages': [package_record(name) for name in names],
        'webVendorVersions': json.loads((ROOT / 'tool/provider_web_assets/package.json').read_text())['dependencies'],
        'webRtcHotfix': {'path': 'packages/flutter_webrtc', 'mustUseSameRef': True, 'license': 'packages/flutter_webrtc/LICENSE', 'notice': 'packages/flutter_webrtc/NOTICE'},
    }
    output.mkdir(parents=True, exist_ok=True)
    (output / 'sdk-version-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    for combo, packages in COMBINATIONS.items():
        (output / f'{combo}.pubspec.fragment.yaml').write_text(git_dependencies(packages, git_ref))
    return manifest


def check(output: Path) -> None:
    manifest = json.loads((output / 'sdk-version-manifest.json').read_text())
    actual = [package_record(name) for name in json.loads(INVENTORY.read_text())]
    if manifest['packages'] != actual:
        raise ValueError('Distribution package/resource manifest is stale.')
    vendors = json.loads((ROOT / 'tool/provider_web_assets/package.json').read_text())['dependencies']
    if manifest['webVendorVersions'] != vendors:
        raise ValueError('Pinned Web vendor versions differ.')
    print(f'{len(actual)} packages: licenses, declared assets and resource hashes verified. Git availability remains unverified.')


def create_host(destination: Path, combo: str) -> Path:
    destination.mkdir(parents=True, exist_ok=False)
    names = COMBINATIONS[combo]
    yaml = ['name: external_sdk_host', 'publish_to: none', 'environment:', '  sdk: ^3.12.0', 'dependencies:', '  flutter:', '    sdk: flutter']
    for name in names:
        yaml += [f'  {name}:', f'    path: {ROOT / "packages" / name}']
    if 'flutter_realtime_provider_livekit' in names:
        yaml += ['dependency_overrides:', '  flutter_webrtc:', f'    path: {ROOT / "packages/flutter_webrtc"}']
    yaml += ['flutter:', '  uses-material-design: true']
    (destination / 'pubspec.yaml').write_text('\n'.join(yaml) + '\n')
    imports = ["import 'package:flutter/material.dart';", "import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';"]
    providers = []
    for name, constructor in [('flutter_realtime_provider_livekit','createLivekitProvider'), ('flutter_realtime_provider_ivs_chat','createIvsChatProvider')]:
        if name in names:
            imports += [f"import 'package:{name}/{name}.dart';"]
            providers += [f'{constructor}()']
    effects = ''
    if combo == 'full':
        imports += ["import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';"]
        imports += [f"import 'package:{name}/{name}.dart';" for name in ['flutter_realtime_classroom_preset', 'flutter_realtime_shared_content_preset', 'flutter_realtime_screen_annotation', 'flutter_realtime_live_preset']]
        effects = ', services: RealtimeRoomServices(videoEffectsFactory: () => DefaultRealtimeVideoEffects()), featurePlugins: const [ClassroomPreset(), SharedContentPreset(), SystemAnnotationPreset(), LivePreset()]'
    widgets = ''
    if combo in ['full','room_ui']:
        imports += ["import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart';"]
        # Compile the actual composable UI surface even with no backend connection.
        widgets = '\nWidget buildRoom(RealtimeRoom room) => RealtimeRoomUiScope(room: room, child: const RealtimeVideoGrid());'
    (destination / 'lib').mkdir()
    (destination / 'lib/main.dart').write_text('\n'.join(imports)+f'\nfinal realtime = Realtime(providers: [{", ".join(providers)}]{effects});\nvoid main() {{ runApp(MaterialApp(home: Text(realtime.sdk.supportedProviderIds.join(",")))); }}\n'+widgets)
    (destination / 'web').mkdir()
    (destination / 'web/index.html').write_text('<!doctype html><html><head><base href="$FLUTTER_BASE_HREF"><meta charset="utf-8"></head><body><script src="flutter_bootstrap.js" async></script></body></html>')
    return destination


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument('--ref', default=CANDIDATE)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--host', choices=COMBINATIONS)
    parser.add_argument('--host-directory', type=Path)
    arguments = parser.parse_args()
    if arguments.host:
        if arguments.host_directory is None:
            parser.error('--host-directory is required')
        create_host(arguments.host_directory, arguments.host)
    elif arguments.check:
        check(arguments.output)
    else:
        if arguments.ref != CANDIDATE and not re.fullmatch('[0-9a-f]{40}', arguments.ref):
            parser.error('--ref must be a full immutable commit SHA')
        prepare(arguments.output, arguments.ref)
