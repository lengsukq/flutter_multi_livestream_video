import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('distribution', Path(__file__).resolve().parents[1] / 'prepare_sdk_distribution.py')
distribution = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(distribution)

class DistributionTests(unittest.TestCase):
    def test_one_immutable_git_ref_covers_every_package_and_webrtc_hotfix(self):
        ref = 'a' * 40
        fragment = distribution.git_dependencies(distribution.COMBINATIONS['full'], ref)
        self.assertNotIn('path: /', fragment)
        self.assertIn('path: packages/flutter_webrtc', fragment)
        refs = [line.strip() for line in fragment.splitlines() if line.strip().startswith('ref:')]
        self.assertEqual(len(refs), len(distribution.COMBINATIONS['full']) + 1)
        self.assertEqual(set(refs), {f'ref: {ref}'})

    def test_missing_asset_and_changed_asset_are_distinct_release_failures(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder = root / 'packages/test_package'
            folder.mkdir(parents=True)
            (folder / 'LICENSE').write_text('MIT')
            (folder / 'pubspec.yaml').write_text('version: 1.2.3\nflutter:\n  assets:\n    - assets/bridge.js\n')
            with patch.object(distribution, 'ROOT', root):
                with self.assertRaisesRegex(ValueError, 'missing declared asset'):
                    distribution.package_record('test_package')
                (folder / 'assets').mkdir()
                asset = folder / 'assets/bridge.js'
                asset.write_text('first build')
                first = distribution.package_record('test_package')
                asset.write_text('second build')
                second = distribution.package_record('test_package')
                self.assertNotEqual(first['resourceSha256'], second['resourceSha256'])
                self.assertEqual(first['version'], second['version'])

    def test_full_host_registers_optional_features_and_lists_each_direct_import(self):
        with tempfile.TemporaryDirectory() as directory:
            host = distribution.create_host(Path(directory) / 'host', 'full')
            source = (host / 'lib/main.dart').read_text()
            manifest = (host / 'pubspec.yaml').read_text()
            for feature in ['ClassroomPreset()', 'SharedContentPreset()', 'SystemAnnotationPreset()', 'LivePreset()']:
                self.assertIn(feature, source)
            for line in source.splitlines():
                if "import 'package:flutter_realtime_" in line:
                    name = line.split("package:")[1].split('/')[0]
                    self.assertIn(f'  {name}:', manifest)
            self.assertNotIn('example/', manifest)
            self.assertNotIn('demo-server', source)

if __name__ == '__main__':
    unittest.main()
