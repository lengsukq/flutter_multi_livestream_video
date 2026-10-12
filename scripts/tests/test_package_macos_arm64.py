"""Tests for macOS DMG packaging without running Xcode or writing to /Applications."""

import plistlib
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts import package_macos_arm64 as packager


class PackageMacosArm64Test(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.app = self.root / 'flutter_aws_chime_example.app'
        self.bundle_id = 'com.oneplusdream.flutterAwsChimeExample'
        self.create_app(self.app, self.bundle_id)

    def create_app(self, location: Path, bundle_id: str):
        (location / 'Contents/MacOS').mkdir(parents=True)
        (location / 'Contents/MacOS/flutter_aws_chime_example').write_bytes(b'fake-mach-o')
        with (location / 'Contents/Info.plist').open('wb') as destination:
            plistlib.dump({
                'CFBundleIdentifier': bundle_id,
                'CFBundleExecutable': 'flutter_aws_chime_example',
                'CFBundleShortVersionString': '1.2.3',
            }, destination)

    @patch.object(packager.subprocess, 'run')
    def test_checks_arm64_architecture(self, run):
        run.return_value = subprocess.CompletedProcess([], 0, stdout='x86_64 arm64\n')
        self.assertEqual(packager.verify_arm64(self.app, self.bundle_id), '1.2.3')
        run.assert_called_once()
        self.assertEqual(run.call_args.args[0][0:2], ['lipo', '-archs'])

    @patch.object(packager.subprocess, 'run')
    def test_rejects_x86_only_executable(self, run):
        run.return_value = subprocess.CompletedProcess([], 0, stdout='x86_64\n')
        with self.assertRaisesRegex(packager.PackagingError, 'lacks arm64'):
            packager.verify_arm64(self.app, self.bundle_id)

    @patch.object(packager.subprocess, 'run')
    def test_rejects_wrong_app_bundle(self, run):
        with self.assertRaisesRegex(packager.PackagingError, 'bundle ID differs'):
            packager.verify_arm64(self.app, 'com.example.another')
        run.assert_not_called()

    def test_creates_dmg_containing_app_and_applications_alias(self):
        destination = self.root / 'dist/macos/demo-arm64.dmg'
        observed = []

        def fake_run(command, **_kwargs):
            observed.append(command[0])
            if command[0] == 'ditto':
                shutil.copytree(command[1], command[2], symlinks=True)
            if command[0] == 'hdiutil':
                volume = Path(command[command.index('-srcfolder') + 1])
                self.assertTrue((volume / self.app.name / 'Contents/Info.plist').exists())
                self.assertEqual((volume / 'Applications').readlink(), Path('/Applications'))
                Path(command[command.index('-o') + 1]).write_bytes(b'disk-image')

        with patch.object(packager, 'run', side_effect=fake_run):
            packager.make_dmg(self.app, destination)
        self.assertEqual(destination.read_bytes(), b'disk-image')
        self.assertEqual(observed, ['ditto', 'hdiutil'])

    def test_install_requires_replace_and_same_bundle_id(self):
        applications = self.root / 'Applications'
        applications.mkdir()

        def fake_run(command, **_kwargs):
            shutil.copytree(command[1], command[2])

        with patch.object(packager, 'run', side_effect=fake_run):
            installed = packager.install_app(self.app, self.bundle_id, applications, replace=False)
            self.assertEqual(packager.app_metadata(installed)['CFBundleIdentifier'], self.bundle_id)
            with self.assertRaisesRegex(packager.PackagingError, 'pass --replace'):
                packager.install_app(self.app, self.bundle_id, applications, replace=False)
            (installed / 'Contents/old-file').write_text('obsolete')
            packager.install_app(self.app, self.bundle_id, applications, replace=True)
            self.assertFalse((installed / 'Contents/old-file').exists())
            self.assertEqual(list(applications.iterdir()), [installed])

            shutil.rmtree(installed)
            self.create_app(installed, 'com.example.different')
            with self.assertRaisesRegex(packager.PackagingError, 'different bundle ID'):
                packager.install_app(self.app, self.bundle_id, applications, replace=True)

    def test_install_refuses_symlink_destination(self):
        applications = self.root / 'Applications'
        applications.mkdir()
        (applications / self.app.name).symlink_to(self.app, target_is_directory=True)
        with self.assertRaisesRegex(packager.PackagingError, 'symlink'):
            packager.install_app(self.app, self.bundle_id, applications, replace=True)

    def test_open_requires_install(self):
        with self.assertRaises(SystemExit) as result:
            packager.main(['--open'], repository=self.root)
        self.assertEqual(result.exception.code, 2)


if __name__ == '__main__':
    unittest.main()
