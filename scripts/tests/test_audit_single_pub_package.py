"""Regression tests for the one-package release blocker audit."""

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from audit_single_pub_package import (
    audit,
    dependency_names,
    path_dependencies,
    platforms,
    plugin_entrypoints,
)
from assemble_single_sdk_candidate import hosted_dependencies, merge_constraint


class SinglePackageAuditTest(unittest.TestCase):
    def test_compatible_dependency_ranges_are_combined(self):
        self.assertEqual(merge_constraint("http", "^1.4.0", "^1.6.0"), "^1.6.0")
        self.assertEqual(merge_constraint("sdk", "^0.3.1", "^0.3.7"), "^0.3.7")
        with self.assertRaises(ValueError):
            merge_constraint("http", "^1.6.0", "^2.0.0")

    def test_dependency_scopes_do_not_confuse_sdk_and_dev_dependencies(self):
        manifest = (
            "name: example\n"
            "dependencies:\n"
            "  flutter:\n"
            "    sdk: flutter\n"
            "  internal:\n"
            "    path: ../internal\n"
            "dev_dependencies:\n"
            "  fake_test:\n"
            "    git: https://example.test/repo\n"
            "flutter:\n"
            "  plugin:\n"
            "    platforms:\n"
            "      macos:\n"
            "        pluginClass: Test\n"
        )
        self.assertEqual(dependency_names(manifest), {"flutter", "internal"})
        self.assertEqual(path_dependencies(manifest), ["dependencies/internal", "dev_dependencies/fake_test"])
        self.assertEqual(platforms(manifest), ["macos"])
        self.assertEqual(
            plugin_entrypoints(manifest),
            {"macos": {"pluginClass": "Test"}},
        )

    def test_repository_has_native_plugins_and_requires_real_merge(self):
        report = audit()
        self.assertEqual(report["target"], "ONE hosted pub.dev package named flutter_realtime_sdk")
        self.assertEqual(report["internalModules"], 44)
        self.assertGreater(report["internalPackageImports"], 0)
        self.assertGreater(report["pathOrGitDependencyPackages"], 0)
        self.assertIn("android", report["pluginRegistrations"])
        self.assertIn("macos", report["pluginRegistrations"])
        self.assertIn("pluginClass", next(iter(report["nativePluginEntrypoints"]["android"].values())))
        self.assertFalse(report["publishableNow"])

    def test_generated_dependency_list_is_hosted_only(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        imports = hosted_dependencies(
            root, __import__("json").loads((root / "scripts/sdk_packages.json").read_text())
        )
        self.assertIn("flutter", imports)
        self.assertIn("agora_rtc_engine", imports)
        self.assertIn("livekit_client", imports)
        self.assertNotIn("flutter_realtime_sdk_runtime", imports)
        self.assertTrue(all("path:" not in spec and "git:" not in spec for spec in imports.values()))


if __name__ == "__main__":
    unittest.main()
