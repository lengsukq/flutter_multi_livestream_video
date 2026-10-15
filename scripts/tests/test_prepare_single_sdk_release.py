"""Ensure staging never uploads vendor frameworks or changes source modules."""
import json
import pathlib
import sys
import tempfile
import unittest

SCRIPTS = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
from prepare_single_sdk_release import prepare


class ReleasePreparationTest(unittest.TestCase):
    def test_preview_excludes_local_artifacts_and_preserves_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            candidate = root / "build/single_sdk_candidate"
            files = {
                "pubspec.yaml": "name: flutter_realtime_sdk\nversion: 0.1.0\npublish_to: none\n",
                "ios/vendor_frameworks.json": '{"frameworks": []}',
                "ios/vendor_frameworks.rb": "# resolver",
                "ios/podfile.rb": "# integration",
                "ios/flutter_realtime_sdk.podspec": "s.version = '0.1.0'",
                "macos/flutter_realtime_sdk.podspec": "s.version = '0.1.0'",
                "LICENSE": "MIT",
                ".pubignore": "/ios/Frameworks/\n.dart_tool/\n",
                "lib/flutter_realtime_sdk.dart": "// entry",
                "ios/Frameworks/AmazonIVS.xcframework/Info.plist": "vendor binary metadata",
                ".dart_tool/package_config.json": "local paths",
                ".git/config": "local repository",
                "tool/smoke.dart": "// local tooling",
                "pubspec.lock": "local resolution",
            }
            for name, contents in files.items():
                path = candidate / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(contents)
            template = root / "scripts/templates/single_sdk_README.md"
            template.parent.mkdir(parents=True)
            template.write_text("Preview @VERSION@")

            release = prepare("0.1.0-dev.1", root)
            self.assertEqual((candidate / "pubspec.yaml").read_text(), files["pubspec.yaml"])
            self.assertNotIn("publish_to:", (release / "pubspec.yaml").read_text())
            self.assertIn("version: 0.1.0-dev.1", (release / "pubspec.yaml").read_text())
            self.assertEqual((release / "README.md").read_text(), "Preview 0.1.0-dev.1")
            for excluded in ("ios/Frameworks", ".dart_tool", "tool", "pubspec.lock"):
                self.assertFalse((release / excluded).exists(), excluded)
            inventory = json.loads((release.parent / "FILES.sha256.json").read_text())
            self.assertIn("ios/vendor_frameworks.json", inventory)
            self.assertNotIn(".git/config", inventory)
            self.assertFalse(any(name.startswith("ios/Frameworks/") for name in inventory))
            with self.assertRaises(FileExistsError):
                prepare("0.1.0-dev.1", root)

    def test_stable_release_requires_a_separate_acceptance_decision(self):
        with self.assertRaises(ValueError):
            prepare("0.1.0")


if __name__ == "__main__":
    unittest.main()
