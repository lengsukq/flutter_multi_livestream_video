#!/usr/bin/env python3
"""Format only repository-owned Dart sources, excluding vendor and generated files."""
import argparse, pathlib, shutil, subprocess
root=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
paths=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard'],cwd=root,text=True).splitlines()
paths=sorted({s for s in paths if s.endswith('.dart') and (root/s).is_file() and not s.startswith(('packages/flutter_webrtc/', 'packages/flutter_aws_chime/')) and not any(x in pathlib.Path(s).parts for x in ['build','.dart_tool','node_modules'])})
dart=str(pathlib.Path(shutil.which('flutter')).resolve().parent/'cache/dart-sdk/bin/dart')
command=[dart,'format']+(['--output=none','--set-exit-if-changed'] if args.check else [])+paths
raise SystemExit(subprocess.run(command,cwd=root).returncode)
