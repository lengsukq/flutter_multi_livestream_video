"""Prevent the iOS example identity from drifting away from Android."""

import plistlib
import re
import unittest
from pathlib import Path
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parents[2] / "example"


class DemoIosIdentityTests(unittest.TestCase):
    def test_display_name_matches_android(self):
        manifest = ElementTree.parse(ROOT / "android/app/src/main/AndroidManifest.xml")
        android_name = manifest.getroot().find("application").attrib[
            "{http://schemas.android.com/apk/res/android}label"
        ]
        with (ROOT / "ios/Runner/Info.plist").open("rb") as f:
            ios_info = plistlib.load(f)
        self.assertEqual(ios_info["CFBundleDisplayName"], android_name)
        self.assertEqual(ios_info["CFBundleName"], android_name)

    def test_ios_bundle_ids_derive_from_android_and_are_apple_valid(self):
        android_gradle = (ROOT / "android/app/build.gradle").read_text()
        android_id = re.search(r'\bapplicationId\s+"([^"]+)"', android_gradle).group(1)
        # CFBundleIdentifier allows hyphens, but not Android's underscores.
        ios_id = android_id.replace("_", "-")
        self.assertRegex(ios_id, r"^[A-Za-z0-9.-]+$")
        project = (ROOT / "ios/Runner.xcodeproj/project.pbxproj").read_text()
        ids = re.findall(r"\bPRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);", project)
        self.assertCountEqual(ids, [ios_id] * 3 + [ios_id + ".RunnerTests"] * 3)


if __name__ == "__main__":
    unittest.main()
