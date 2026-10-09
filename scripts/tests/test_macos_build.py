import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('macos_build', Path(__file__).parents[1] / 'build_flutter_macos.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class MacosBuildTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name)
        self.manifest = self.project / 'pubspec.yaml'
        self.original = 'name: demo\nflutter:\n  config:\n    enable-swift-package-manager: true\n'
        self.manifest.write_text(self.original)
        self.swift = self.project / 'macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift'
        self.swift.parent.mkdir(parents=True)
        self.swift.write_text('original generated dependencies')

    def test_failed_build_restores_both_manifests(self):
        def run(command, cwd):
            self.assertEqual(cwd, self.project)
            self.assertIn('false', self.manifest.read_text())
            self.assertEqual(self.swift.read_text(), helper.SWIFT_STUB)
            return subprocess.CompletedProcess(command, 1)
        self.assertEqual(helper.build(self.project, ['--release', '--no-pub'], run), 1)
        self.assertEqual(self.manifest.read_text(), self.original)
        self.assertEqual(self.swift.read_text(), 'original generated dependencies')

    def test_interruption_restores_manifests(self):
        def run(*args, **kwargs):
            raise KeyboardInterrupt
        with self.assertRaises(KeyboardInterrupt):
            helper.build(self.project, [], run)
        self.assertEqual(self.manifest.read_text(), self.original)
        self.assertEqual(self.swift.read_text(), 'original generated dependencies')

    def test_newer_edits_are_preserved(self):
        def run(command, cwd):
            self.manifest.write_text('concurrent user edit')
            self.swift.write_text('new generated dependencies')
            return subprocess.CompletedProcess(command, 0)
        self.assertEqual(helper.build(self.project, [], run), 0)
        self.assertEqual(self.manifest.read_text(), 'concurrent user edit')
        self.assertEqual(self.swift.read_text(), 'new generated dependencies')

    def test_unknown_configuration_is_rejected_before_mutation(self):
        self.manifest.write_text('name: unknown\n')
        with self.assertRaises(ValueError):
            helper.build(self.project, [], lambda *args, **kwargs: self.fail('must not run'))
        self.assertEqual(self.manifest.read_text(), 'name: unknown\n')
        self.assertEqual(self.swift.read_text(), 'original generated dependencies')
