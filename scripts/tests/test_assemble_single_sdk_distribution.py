"""Release-candidate generation and integration wiring regression tests.

These tests never publish or access vendor cloud credentials.
"""

import pathlib
import sys
import unittest

SCRIPTS = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))

from assemble_single_sdk_distribution import build


class SingleSdkDistributionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = build()
        cls.root = pathlib.Path(cls.report["target"])

    def test_one_hosted_dependency_surface(self):
        pubspec = (self.root / "pubspec.yaml").read_text()
        # Additional public SDK UI components may increase the number of
        # bundled libraries; the release must not silently drop old modules.
        self.assertGreaterEqual(self.report["dartLibraries"], 612)
        self.assertIn("publish_to: none", pubspec)
        self.assertIn("repository: https://github.com/", pubspec)
        self.assertNotIn("    path:", pubspec)
        self.assertNotIn("    git:", pubspec)
        self.assertTrue((self.root / "LICENSE").is_file())
        self.assertTrue((self.root / "CHANGELOG.md").is_file())
        self.assertTrue((self.root / ".git").is_dir())
        self.assertTrue((self.root / ".pubignore").is_file())
        self.assertFalse(self.report["publishable"])

    def test_single_public_entry_supports_headless_video_effects(self):
        entry = (self.root / "lib/flutter_realtime_sdk.dart").read_text()
        self.assertIn("show DefaultRealtimeVideoEffects;", entry)
        smoke = (self.root / "tool/single_import_smoke.dart").read_text()
        self.assertIn("DefaultRealtimeVideoEffects.new", smoke)
        room = (self.root / "lib/src/_bundled/flutter_realtime_sdk_runtime/src/realtime_room.dart").read_text()
        self.assertIn("Future<void> setCameraEnabled(bool enabled)", room)

    def test_ios_resolves_official_binaries_without_nonexistent_pods(self):
        import json
        from assemble_single_sdk_ios import ivs_frameworks

        spec = (self.root / "ios/flutter_realtime_sdk.podspec").read_text()
        self.assertNotIn("s.dependency 'AmazonIVS", spec)
        self.assertIn("VendorFrameworks.install!(__dir__)", spec)
        self.assertIn("s.vendored_frameworks = 'Frameworks/*.xcframework'", spec)
        manifest = json.loads((self.root / "ios/vendor_frameworks.json").read_text())
        self.assertEqual(manifest["frameworks"], ivs_frameworks())
        self.assertEqual({item["name"] for item in manifest["frameworks"]},
                         {"AmazonIVSBroadcast", "AmazonIVSChatMessaging"})
        self.assertIn("/ios/Frameworks/", (self.root / ".pubignore").read_text())
        self.assertFalse((self.root / "ios/Frameworks").exists())

    def test_all_platform_registration_entries_are_present(self):
        pubspec = (self.root / "pubspec.yaml").read_text()
        self.assertEqual(self.report["native"]["android"]["registrations"], 10)
        self.assertEqual(self.report["native"]["macos"]["registrations"], 10)
        self.assertEqual(self.report["native"]["ios"]["registrations"], 4)
        for platform in ("android", "ios", "macos", "windows", "linux", "web"):
            self.assertIn(f"      {platform}:", pubspec)
        self.assertIn(
            "src/_bundled/flutter_realtime_video_effects/flutter_realtime_video_effects_web.dart",
            pubspec,
        )

    def test_android_merged_plugin_keeps_plugin_channels_and_jni(self):
        plugin = (
            self.root / "android/src/main/java/com/oneplusdream/"
            "flutter_realtime_sdk/FlutterRealtimeSdkPlugin.java"
        ).read_text()
        self.assertEqual(plugin.count("children.add(new "), 10)
        self.assertIn("onReattachedToActivityForConfigChanges", plugin)
        gradle = (self.root / "android/build.gradle").read_text()
        self.assertIn("hyphenate-chat-", gradle)
        self.assertIn("libaosl", gradle)
        self.assertIn("ivs-broadcast", gradle)
        self.assertIn("JVM_17", gradle)
        self.assertNotIn("pickFirst", gradle)

    def test_apple_and_desktop_registration_bridges(self):
        ios = (self.root / "ios/Classes/FlutterRealtimeSdkPlugin.swift").read_text()
        self.assertEqual(ios.count(".register(with: registrar)"), 4)
        mac = (self.root / "macos/Classes/FlutterRealtimeSdkPlugin.m").read_text()
        self.assertEqual(mac.count('@"FlutterRealtime'), 10)
        self.assertIn("FlutterRealtimeMediaAwsDesktopPlugin", mac)
        self.assertTrue((self.root / "windows/sdk_plugin_c_api.cpp").exists())
        self.assertTrue((self.root / "linux/sdk_plugin.cc").exists())

    def test_known_generated_vendor_false_positive_is_precisely_scoped(self):
        expected = (
            "assets/bundled/flutter_realtime_provider_trtc/"
            "trtc-assets/audioProcessor-wasm.js"
        )
        self.assertTrue((self.root / expected).exists())
        pubspec = (self.root / "pubspec.yaml").read_text()
        self.assertIn(f"  - /{expected}", pubspec)


if __name__ == "__main__":
    unittest.main()
