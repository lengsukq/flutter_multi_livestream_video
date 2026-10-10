import unittest
from verify_recording import evaluate_probe


class VerifyRecordingTest(unittest.TestCase):
    def test_real_video_passes_without_audio_requirement(self):
        payload = {
            "streams": [
                {"codec_type": "video", "codec_name": "h264", "width": 1280, "height": 720}
            ],
            "format": {"size": "45000", "duration": "4.5"},
        }
        self.assertTrue(evaluate_probe(payload)[0])
        self.assertFalse(evaluate_probe(payload, require_audio=True)[0])

    def test_text_disguised_as_mp4_fails(self):
        self.assertFalse(evaluate_probe({"streams": [], "format": {"size": 76}})[0])

    def test_incomplete_encoded_video_fails(self):
        payload = {
            "streams": [
                {"codec_type": "video", "codec_name": "unknown", "width": 0, "height": 0}
            ],
            "format": {"size": "1024", "duration": "0.1"},
        }
        passed, reasons = evaluate_probe(payload, min_seconds=1.0)
        self.assertFalse(passed)
        self.assertEqual(len(reasons), 2)


if __name__ == "__main__":
    unittest.main()
