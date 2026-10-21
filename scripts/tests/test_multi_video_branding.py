"""Cross-platform Demo identity checks; SDK package names must remain stable."""

import json
import plistlib
import re
import unittest
from pathlib import Path
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parents[2]
DEMO = ROOT / "example"
LABEL = "multi-video"
ANDROID_ID = "com.oneplusdream.multi_video"
APPLE_ID = "com.oneplusdream.multi-video"


class BrandingTests(unittest.TestCase):
    def test_android(self):
        gradle = (DEMO / "android/app/build.gradle").read_text()
        self.assertIn('applicationId "' + ANDROID_ID + '"', gradle)
        self.assertIn('namespace "' + ANDROID_ID + '"', gradle)
        manifest = ElementTree.parse(DEMO / "android/app/src/main/AndroidManifest.xml")
        self.assertEqual(
            manifest.getroot().find("application").attrib[
                "{http://schemas.android.com/apk/res/android}label"
            ], LABEL)
        activity = DEMO / "android/app/src/main/kotlin/com/oneplusdream/multi_video/MainActivity.kt"
        self.assertIn("package " + ANDROID_ID, activity.read_text())
        self.assertFalse((DEMO / "android/app/src/main/kotlin/com/oneplusdream/flutter_aws_chime_example/MainActivity.kt").exists())

    def test_ios(self):
        with (DEMO / "ios/Runner/Info.plist").open("rb") as f:
            info = plistlib.load(f)
        self.assertEqual(info["CFBundleDisplayName"], LABEL)
        self.assertEqual(info["CFBundleName"], LABEL)
        project = (DEMO / "ios/Runner.xcodeproj/project.pbxproj").read_text()
        identifiers = re.findall(r"\bPRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);", project)
        self.assertCountEqual(identifiers, [APPLE_ID] * 3 + [APPLE_ID + ".RunnerTests"] * 3)

    def test_macos(self):
        config = (DEMO / "macos/Runner/Configs/AppInfo.xcconfig").read_text()
        self.assertIn("PRODUCT_NAME = " + LABEL, config)
        self.assertIn("PRODUCT_BUNDLE_IDENTIFIER = " + APPLE_ID, config)
        with (DEMO / "macos/Runner/Info.plist").open("rb") as f:
            self.assertEqual(plistlib.load(f)["CFBundleDisplayName"], LABEL)
        scheme = (DEMO / "macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme").read_text()
        self.assertIn('BuildableName = "multi-video.app"', scheme)

    def test_web(self):
        manifest = json.loads((DEMO / "web/manifest.json").read_text())
        self.assertEqual(manifest["name"], LABEL)
        self.assertEqual(manifest["short_name"], LABEL)
        html = (DEMO / "web/index.html").read_text()
        self.assertIn("<title>multi-video</title>", html)

    def test_windows_and_linux(self):
        windows = (DEMO / "windows/CMakeLists.txt").read_text()
        linux = (DEMO / "linux/CMakeLists.txt").read_text()
        self.assertIn('set(BINARY_NAME "multi-video")', windows)
        self.assertIn('set(BINARY_NAME "multi-video")', linux)
        self.assertIn('VALUE "ProductName", "multi-video"', (DEMO / "windows/runner/Runner.rc").read_text())
        self.assertIn('L"multi-video"', (DEMO / "windows/runner/main.cpp").read_text())
        self.assertIn('"multi-video"', (DEMO / "linux/my_application.cc").read_text())

    def test_demo_and_sdk_are_distinct(self):
        self.assertIn("name: multi_video\n", (DEMO / "pubspec.yaml").read_text())
        self.assertIn("title: 'multi-video'", (DEMO / "lib/main.dart").read_text())
        self.assertIn("'multi-video'", (DEMO / "lib/demo_join_screen.dart").read_text())
        self.assertIn("name: flutter_realtime_sdk\n", (ROOT / "packages/flutter_realtime_sdk/pubspec.yaml").read_text())
        self.assertIn("name: flutter_aws_chime\n", (ROOT / "packages/flutter_aws_chime/pubspec.yaml").read_text())
        self.assertIn("https://github.com/lengsukq/multi-video", (ROOT / "packages/flutter_realtime_sdk/pubspec.yaml").read_text())


if __name__ == "__main__":
    unittest.main()
