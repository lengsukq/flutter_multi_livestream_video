#!/usr/bin/env python3
"""Validate dependency direction, source ownership and public import boundaries."""
import json, re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
names = json.loads((ROOT/'scripts/sdk_packages.json').read_text())
actual={p.name for p in (ROOT/'packages').iterdir() if (p/'pubspec.yaml').exists() and p.name != 'flutter_webrtc'}
assert len(names) == len(set(names)) and set(names) == actual, 'Package inventory must include all owned packages exactly once'
assert not (ROOT/'packages/flutter_realtime_sdk_runtime/assets/media-provider-bridge.js').exists(), 'Provider bridge belongs to the Web adapter'
graph = {}
for name in names:
    manifest=(ROOT/'packages'/name/'pubspec.yaml').read_text()
    dependencies=manifest.split('\ndependencies:\n',1)[-1].split('\ndev_dependencies:',1)[0]
    graph[name]={n for n in re.findall(r'^  (flutter_\w+):',dependencies,re.M) if n in names}
active=set(); done=set()
def visit(name):
    assert name not in active, f'Dependency cycle at {name}'
    if name in done: return
    active.add(name)
    for dep in graph[name]: visit(dep)
    active.remove(name);done.add(name)
for name in names: visit(name)
def closure(name):
    result=set(); pending=[name]
    while pending:
        for dep in graph[pending.pop()]:
            if dep not in result:result.add(dep);pending.append(dep)
    return result
runtime=closure('flutter_realtime_sdk_runtime')
assert not [n for n in runtime if n.endswith('_ui') or n.startswith('flutter_realtime_provider_') or (n.startswith('flutter_realtime_media_') and n != 'flutter_realtime_media_core')], runtime
optional_business = {
    'flutter_realtime_classroom_core',
    'flutter_realtime_live_core',
    'flutter_realtime_whiteboard_core',
    'flutter_realtime_screen_annotation',
    'flutter_realtime_classroom_preset',
    'flutter_realtime_live_preset',
    'flutter_realtime_shared_content_preset',
    'flutter_realtime_video_effects',
}
assert not runtime.intersection(optional_business), f'Runtime must not require optional business packages: {runtime.intersection(optional_business)}'
assert not closure('flutter_realtime_classroom_preset').intersection({'flutter_realtime_screen_annotation', 'flutter_realtime_shared_content_preset'}), 'Classroom must not acquire shared content or system permissions'
assert not closure('flutter_realtime_room_ui').intersection(optional_business), 'Lean room UI must not acquire business presets or processing'
assert not closure('flutter_realtime_processed_video').intersection(optional_business), 'Frame bridge must remain independent from processing and business'
for preset in ('flutter_realtime_classroom_preset', 'flutter_realtime_live_preset'):
    assert 'flutter_realtime_sdk_runtime' in closure(preset), f'{preset} must adapt the generic runtime'
sdk=closure('flutter_realtime_sdk')
assert 'flutter_realtime_sdk_runtime' in sdk, 'SDK entry must retain Runtime'
assert not [n for n in sdk if n.endswith('_ui') or n.startswith('flutter_realtime_provider_') or (n.startswith('flutter_realtime_media_') and n != 'flutter_realtime_media_core')], sdk
assert not sdk.intersection(optional_business), f'Core SDK must not force business presets: {sdk.intersection(optional_business)}'
assert not [n for n in graph['flutter_realtime_sdk'] if n != 'flutter_realtime_sdk_runtime'], graph['flutter_realtime_sdk']
assert (ROOT/'packages/flutter_realtime_sdk_runtime/lib/src/members/room_members_controller.dart').exists(), 'Member management must be owned by Runtime'
assert not any('class RoomMembersController' in src.read_text() for src in (ROOT/'packages').glob('flutter_realtime_*_ui/lib/**/*.dart')), 'UI must not reimplement Runtime member management'
for name in names:
    if name.endswith('_core'):
        assert not [n for n in closure(name) if n.endswith('_ui') or n.startswith('flutter_realtime_provider_') or n == 'flutter_realtime_sdk_runtime' or n == 'flutter_webrtc' or (n.startswith('flutter_realtime_media_') and n != 'flutter_realtime_media_core')], name
        dependencies = (ROOT/'packages'/name/'pubspec.yaml').read_text().split('\ndependencies:\n',1)[-1].split('\ndev_dependencies:',1)[0]
        assert not re.search(r'^  (agora_rtc_engine|livekit_client|tencent_rtc_sdk|tencent_cloud_chat_sdk|aliyun_rtc|flutter_aws_chime|flutter_webrtc):', dependencies, re.M), name
assert not (ROOT/'lib/flutter_aws_chime.dart').exists(), 'Root Chime implementation still exists'
assert not (ROOT/'packages/flutter_realtime_sdk_base').exists(), 'Obsolete base package still exists'
allowed={'flutter_realtime_media_livekit/lib/src/livekit_processed_video_native.dart'}
for name in names:
    for source in (ROOT/'packages'/name/'lib').rglob('*.dart'):
        text=source.read_text()
        for match in re.finditer(r"(?:import|export) 'package:([^/]+)/src/",text):
            assert match[1] == name or source.relative_to(ROOT/'packages').as_posix() in allowed, source
print(f'{len(names)} packages: acyclic graph, lean SDK, UI/provider-free Runtime, Runtime-owned members, public boundaries passed')
