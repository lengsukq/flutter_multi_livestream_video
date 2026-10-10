#!/usr/bin/env python3
"""Generate declaration evidence locally; never executes or joins a provider."""
import argparse
import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'doc/generated/SDK_DECLARATIONS.md'

def drivers(source):
    pos = 0
    while True:
        start = source.find('RealtimeProviderDriver(', pos)
        if start < 0:
            return
        cursor = start + len('RealtimeProviderDriver')
        depth = 0
        while cursor < len(source):
            if source[cursor] == '(':
                depth += 1
            elif source[cursor] == ')':
                depth -= 1
                if depth == 0:
                    break
            cursor += 1
        yield source[start:cursor + 1]
        pos = cursor + 1

def generate():
    rows = []
    evidence = []
    for package in sorted((ROOT / 'packages').glob('flutter_realtime_provider_*')):
        for target in ['native', 'web']:
            path = package / f'lib/src/drivers_{target}.dart'
            text = path.read_text()
            evidence.append((path.relative_to(ROOT).as_posix(), text))
            for block in drivers(text):
                engine = re.search(r"\bid: '([^']+)'", block).group(1)
                public = re.search(r"publicProviderId: '([^']+)'", block)
                platforms = re.search(r'platforms: ([\s\S]*?),\s*(?:publicProviderId|mediaRoomModes|plugin):', block).group(1).strip()
                for name in ['_mobileAndDesktop', '_mobileAndMac', '_web']:
                    definition = re.search(r'const ' + name + r' = ([\s\S]*?);', text)
                    if definition:
                        platforms = platforms.replace(name, definition.group(1))
                platforms = ', '.join(dict.fromkeys(re.findall(r'RealtimeRuntimePlatform\.(\w+)', platforms)))
                kind = 'chat' if 'chatFactory:' in block else 'media'
                adapter = ('flutter_realtime_chat_' if kind == 'chat' else 'flutter_realtime_media_') + engine.replace('-chat', '')
                if kind == 'chat':
                    role_path = ROOT / 'packages/flutter_realtime_chat_core/lib/src/model/chat_role.dart'
                    role_source = role_path.read_text()
                    evidence.append((role_path.relative_to(ROOT).as_posix(), role_source))
                    join_path = ROOT / f'packages/{adapter}/lib/src/{engine.replace("-chat", "")}_chat_join_info.dart'
                    evidence.append((join_path.relative_to(ROOT).as_posix(), join_path.read_text()))
                    role_names = re.findall(r'^\s+(\w+)[,;]', role_source, re.MULTILINE)
                    roles = ', '.join(role_names) + ' (credential-dependent)'
                else:
                    factory = ROOT / f'packages/{adapter}/lib/src/{engine}_session_factory.dart'
                    source = factory.read_text()
                    evidence.append((factory.relative_to(ROOT).as_posix(), source))
                    role_block = re.search(r'get supportedRoles[\s\S]*?;', source).group(0)
                    roles = ', '.join(dict.fromkeys(re.findall(r'MediaRole\.(\w+)', role_block)))
                rows.append((public.group(1) if public else engine, engine, target, platforms, roles))
    lines = ['# Generated SDK declarations', '',
             'Generated from optional driver registrations and adapter declarations. This is implementation evidence, not build or real-call acceptance.', '',
             '| Provider | Engine | Driver | Platforms | Declared roles |',
             '| --- | --- | --- | --- | --- |']
    lines.extend('| ' + ' | '.join(row) + ' |' for row in rows)
    lines += ['', '## Background and media feature declarations', '',
              'Expressions below are copied from source. Runtime probes, role conditions and platform restrictions remain part of the declaration; an implemented sink does not prove a successful remote call.', '']
    for engine in ['livekit', 'agora', 'trtc', 'artc', 'chime', 'ivs']:
        path = ROOT / f'packages/flutter_realtime_media_{engine}/lib/src/{engine}_media_session.dart'
        source = path.read_text()
        evidence.append((path.relative_to(ROOT).as_posix(), source))
        lines += [f'### {engine}', '', f'Processed-video sink in adapter source: **{"yes" if "ProcessedVideoSink" in source else "no"}**.', '']
        for feature in ['canBlurBackground', 'canReplaceBackgroundImage', 'canScreenShare', 'canReportNetworkStats']:
            match = re.search(r'\b' + feature + r':\s*([\s\S]*?)(?=,\s*(?:can\w+|max\w+|management)\s*:|,\s*\n\s*\))', source)
            expression = ' '.join(match.group(1).split()) if match else '(not explicitly declared here; inspect factory/profile defaults)'
            lines.append(f'- `{feature}`: `{expression}`')
        lines.append('')
    # The public SDK has no built-in all-vendor catalog. Fingerprint the
    # lightweight entry and optional provider asset registration instead.
    for path in [ROOT / 'packages/flutter_realtime_media_web/lib/src/provider_web_profile.dart', ROOT / 'packages/flutter_realtime_media_web/lib/src/provider_web_session_factory.dart', ROOT / 'packages/flutter_realtime_video_effects/pubspec.yaml', ROOT / 'packages/flutter_realtime_sdk/pubspec.yaml', ROOT / 'packages/flutter_realtime_sdk_runtime/lib/src/provider_web_session_wrapper.dart']:
        evidence.append((path.relative_to(ROOT).as_posix(), path.read_text()))
    lines += ['## Source fingerprints', '', 'These fingerprints make CI reject stale declarations, including changes to the explicit provider registrations, SDK dependency boundary and conditional Web features.', '']
    for path, source in sorted(set(evidence)):
        lines.append(f'- `{path}`: `{hashlib.sha256(source.encode()).hexdigest()[:16]}`')
    return '\n'.join(lines) + '\n'

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    expected = generate()
    if args.check:
        if not OUT.exists() or OUT.read_text() != expected:
            raise SystemExit('SDK declarations are stale. Run python3 scripts/generate_capability_matrix.py')
        print('SDK declarations are current.')
    else:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(expected)
        print(OUT.relative_to(ROOT))
