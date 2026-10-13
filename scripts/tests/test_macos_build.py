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
        self.runner = self.project / 'macos/Runner.xcodeproj/project.pbxproj'
        self.runner.parent.mkdir(parents=True)
        self.original_runner = '''/* Begin PBXBuildFile section */
\t\t78A318202AECB46A00862997 /* FlutterGeneratedPluginSwiftPackage in Frameworks */ = {isa = PBXBuildFile; productRef = 78A3181F2AECB46A00862997; };
\t\tAAAABBBBCCCCDDDDEEEEFFFF /* Real code */ = {isa = PBXBuildFile; };
/* End PBXBuildFile section */
\t\t78E0A7A72DC9AD7400C4905E /* FlutterGeneratedPluginSwiftPackage */ = {isa = PBXFileReference; path = ephemeral/Packages/FlutterGeneratedPluginSwiftPackage; };
\t\t\t\t78A318202AECB46A00862997 /* FlutterGeneratedPluginSwiftPackage */,
\t\t\t\t78E0A7A72DC9AD7400C4905E /* FlutterGeneratedPluginSwiftPackage */,
\t\t\t\t781AD8BC2B33823900A9FFBB /* FlutterGeneratedPluginSwiftPackage */,
\t\t781AD8BC2B33823900A9FFBB /* FlutterGeneratedPluginSwiftPackage */ = {
\t\t\tisa = XCLocalSwiftPackageReference;
\t\t\trelativePath = Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage;
\t\t};
\t\t78A3181F2AECB46A00862997 /* FlutterGeneratedPluginSwiftPackage */ = {
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tproductName = FlutterGeneratedPluginSwiftPackage;
\t\t};
'''
        self.runner.write_text(self.original_runner)

    def test_failed_build_restores_both_manifests(self):
        def run(command, cwd):
            self.assertEqual(cwd, self.project)
            self.assertIn('false', self.manifest.read_text())
            self.assertEqual(self.swift.read_text(), helper.SWIFT_STUB)
            self.assertNotIn('FlutterGeneratedPluginSwiftPackage', self.runner.read_text())
            self.assertIn('AAAABBBBCCCCDDDDEEEEFFFF', self.runner.read_text())
            return subprocess.CompletedProcess(command, 1)
        self.assertEqual(helper.build(self.project, ['--release', '--no-pub'], run), 1)
        self.assertEqual(self.manifest.read_text(), self.original)
        self.assertEqual(self.swift.read_text(), 'original generated dependencies')
        self.assertNotIn('FlutterGeneratedPluginSwiftPackage', self.runner.read_text())

    def test_generated_runner_cleanup_is_idempotent(self):
        fixed = helper.without_generated_swiftpm_dependency(self.original_runner)
        self.assertNotIn('FlutterGeneratedPluginSwiftPackage', fixed)
        self.assertIn('AAAABBBBCCCCDDDDEEEEFFFF', fixed)
        self.assertEqual(fixed, helper.without_generated_swiftpm_dependency(fixed))

    def test_partial_runner_swiftpm_wiring_is_rejected(self):
        with self.assertRaises(ValueError):
            helper.without_generated_swiftpm_dependency('78A3181F2AECB46A00862997')
        self.assertEqual(self.runner.read_text(), self.original_runner)

    def test_interruption_restores_manifests(self):
        def run(*args, **kwargs):
            raise KeyboardInterrupt
        with self.assertRaises(KeyboardInterrupt):
            helper.build(self.project, [], run)
        self.assertEqual(self.manifest.read_text(), self.original)
        self.assertEqual(self.swift.read_text(), 'original generated dependencies')
        self.assertNotIn('FlutterGeneratedPluginSwiftPackage', self.runner.read_text())

    def test_newer_edits_are_preserved(self):
        def run(command, cwd):
            self.manifest.write_text('concurrent user edit')
            self.swift.write_text('new generated dependencies')
            return subprocess.CompletedProcess(command, 0)
        self.assertEqual(helper.build(self.project, [], run), 0)
        self.assertEqual(self.manifest.read_text(), 'concurrent user edit')
        self.assertEqual(self.swift.read_text(), 'new generated dependencies')
        self.assertNotIn('FlutterGeneratedPluginSwiftPackage', self.runner.read_text())

    def test_unknown_configuration_is_rejected_before_mutation(self):
        self.manifest.write_text('name: unknown\n')
        with self.assertRaises(ValueError):
            helper.build(self.project, [], lambda *args, **kwargs: self.fail('must not run'))
        self.assertEqual(self.manifest.read_text(), 'name: unknown\n')
        self.assertEqual(self.swift.read_text(), 'original generated dependencies')
