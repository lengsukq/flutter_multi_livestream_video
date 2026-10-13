#!/usr/bin/env python3
"""Run SDK package checks from one audited package inventory."""
import argparse, json, os, pathlib, shutil, signal, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--resolve', action='store_true')
p.add_argument('--online', action='store_true')
p.add_argument('--test', action='store_true')
p.add_argument('--analyze', action='store_true')
p.add_argument('--package', action='append')
p.add_argument('--timeout', type=float, default=600, help='Maximum seconds per package check')
a=p.parse_args()
if a.timeout <= 0: p.error('--timeout must be positive')
names=json.loads((ROOT/'scripts/sdk_packages.json').read_text())
actual={p.name for p in (ROOT/'packages').iterdir() if (p/'pubspec.yaml').is_file() and p.name != 'flutter_webrtc'}
if set(names) != actual: sys.exit(f'Package inventory mismatch: {set(names)^actual}')
flutter=shutil.which('flutter')
dart=str(pathlib.Path(flutter).resolve().parent/'cache/dart-sdk/bin/dart')
logs=ROOT/'build/quality'; logs.mkdir(parents=True,exist_ok=True)
failed=[]
for name in a.package or names:
    folder=ROOT/'packages'/name
    for kind,command in [
        ('resolve',[flutter,'pub','get']+([] if a.online else ['--offline']) if a.resolve else None),
        ('analysis',[dart,'analyze','--fatal-infos','--format','machine','lib','test'] if a.analyze and (folder/'test').is_dir() else [dart,'analyze','--fatal-infos','--format','machine','lib'] if a.analyze else None),
        ('tests',[flutter,'test','--no-pub','--reporter','expanded'] if a.test and any((folder/'test').rglob('*_test.dart')) and 'sdk: flutter' in (folder/'pubspec.yaml').read_text() else [dart,'test','--reporter','expanded'] if a.test and any((folder/'test').rglob('*_test.dart')) else None),
    ]:
        if command is None: continue
        process=subprocess.Popen(command,cwd=folder,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,start_new_session=True)
        try:
            output,_=process.communicate(timeout=a.timeout)
            code=process.returncode
        except subprocess.TimeoutExpired:
            # End only this check's process group, including its test runner.
            os.killpg(process.pid, signal.SIGTERM)
            try:
                output,_=process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                output,_=process.communicate()
            output += f'\nCheck exceeded {a.timeout:g} seconds.\n'
            code=124
        (logs/f'{name}.{kind}.txt').write_text(output)
        print(f'{name} {kind}: {code}',flush=True)
        if code: failed.append(f'{name}:{kind}')
print('Failures: '+', '.join(failed),flush=True)
sys.exit(bool(failed))
