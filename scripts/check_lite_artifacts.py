#!/usr/bin/env python3
"""Check actual dependency graphs and release assets, without network access."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

for sample, allowed in [('lite_media', {'livekit'}), ('lite_media_chat', {'livekit', 'ivs_chat'})]:
    app = ROOT / 'examples' / sample
    config = json.loads((app / '.dart_tool/package_config.json').read_text())
    names = {p['name'] for p in config['packages']}
    assert not names.intersection({'flutter_realtime_sdk_ui', 'flutter_realtime_video_effects', 'flutter_realtime_classroom_preset', 'flutter_realtime_live_preset', 'flutter_realtime_shared_content_preset', 'flutter_realtime_screen_annotation'}), 'Optional processing/business must not enter the lite graph'
    for name in names:
        if name.startswith('flutter_realtime_provider_'):
            assert name.removeprefix('flutter_realtime_provider_') in allowed, name
        if name.startswith('flutter_realtime_media_') and name not in {
            'flutter_realtime_media_core', 'flutter_realtime_media_ui', 'flutter_realtime_media_livekit',
            # IVS Chat uses the native desktop transport; its CocoaPods resources
            # are not Flutter Web assets and do not import other Dart adapters.
            'flutter_realtime_media_aws_desktop',
        }:
            raise AssertionError(f'Unselected adapter: {name}')
        if name.startswith('flutter_realtime_chat_') and name not in {
            'flutter_realtime_chat_core', 'flutter_realtime_chat_rtc', 'flutter_realtime_chat_ui',
            *({'flutter_realtime_chat_ivs'} if 'ivs_chat' in allowed else set()),
        }:
            raise AssertionError(f'Unselected chat: {name}')
    output = app / 'build/web'
    files = [p for p in output.rglob('*') if p.is_file()]
    assert files, 'Build the release Web example first'
    paths = [p.relative_to(output).as_posix() for p in files]
    forbidden = ['agora-rtc-sdk.js', 'trtc.js', 'aliyun-rtc-sdk.js', 'chime-sdk.js',
                 'amazon-ivs-web-broadcast.js', 'agora-chat-provider.js', 'tencent-chat-provider.js',
                 'realtime-chat-provider-bridge.js', 'flutter_realtime_sdk/assets/', 'flutter_realtime_video_effects/', 'selfie_segmenter_landscape.tflite', 'blaze_face_short_range.tflite']
    assert not [p for p in paths if any(token in p for token in forbidden)], 'Unselected vendor assets found'
    ivs_files = [p for p in paths if p.endswith('/ivs-chat-provider.js')]
    assert bool(ivs_files) == ('ivs_chat' in allowed), 'IVS Chat asset composition mismatch'
    print(f'{sample}: {len(names)} dependency entries, {len(files)} files, {sum(p.stat().st_size for p in files)} release bytes; provider pruning passed')
