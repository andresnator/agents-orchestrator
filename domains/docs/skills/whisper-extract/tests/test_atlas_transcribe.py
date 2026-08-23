from __future__ import annotations

import io
from pathlib import Path
import sys
import tempfile
import unittest


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import atlas_transcribe  # noqa: E402


SCHEMA = {
    "paths": {
        atlas_transcribe.GENERATE_PATH: {"post": {}},
        atlas_transcribe.PREDICTION_PATH: {"get": {}},
    },
    "components": {
        "schemas": {"Input": {"required": ["model", "audio_url"]}}
    },
}


class FakeTransport:
    def __init__(self, predictions: list[object] | None = None):
        self.calls: list[tuple[str, str, object]] = []
        self.predictions = list(predictions or [])

    def request(self, method, url, *, token=None, payload=None):
        self.calls.append((method, url, payload))
        if url.endswith("/api/v1/models"):
            return {
                "data": [
                    {
                        "model": atlas_transcribe.MODEL,
                        "display_console": True,
                        "schema": "https://static.atlascloud.ai/model/schema/seed-asr.json",
                        "price": {"actual": {"base_price": "0.002"}},
                    }
                ]
            }
        if url.endswith("seed-asr.json"):
            return SCHEMA
        if method == "POST":
            return {"id": "prediction-1", "status": "created"}
        response = self.predictions.pop(0)
        if isinstance(response, Exception):
            raise response
        return response


class AtlasTranscribeTest(unittest.TestCase):
    def setUp(self):
        handle = tempfile.NamedTemporaryFile(suffix=".mp3", delete=False)
        handle.write(b"test audio")
        handle.close()
        self.audio = Path(handle.name)

    def tearDown(self):
        self.audio.unlink(missing_ok=True)

    def test_preflight_never_submits_without_yes(self):
        transport = FakeTransport()

        result = atlas_transcribe.transcribe(
            str(self.audio),
            token="test-token",
            confirmed=False,
            transport=transport,
            stderr=io.StringIO(),
        )

        self.assertFalse(result["submitted"])
        self.assertEqual([call[0] for call in transport.calls], ["GET", "GET"])

    def test_submits_once_and_polls_until_completed(self):
        transport = FakeTransport(
            [
                {"id": "prediction-1", "status": "processing"},
                {
                    "status": "completed",
                    "outputs": ["hello world"],
                    "stt_result": {"text": "hello world", "duration": 1.5},
                },
            ]
        )
        sleeps: list[float] = []

        result = atlas_transcribe.transcribe(
            str(self.audio),
            token="test-token",
            confirmed=True,
            enable_punc=True,
            poll_attempts=4,
            poll_interval=0.25,
            transport=transport,
            sleep=sleeps.append,
            stderr=io.StringIO(),
        )

        methods = [call[0] for call in transport.calls]
        self.assertEqual(methods.count("POST"), 1)
        self.assertEqual(methods.count("GET"), 4)  # catalog, schema, two polls
        self.assertEqual(result["text"], "hello world")
        self.assertEqual(result["prediction_id"], "prediction-1")
        self.assertEqual(sleeps, [0.25])

    def test_failed_prediction_stops_without_resubmitting(self):
        transport = FakeTransport(
            [{"id": "prediction-1", "status": "failed", "error": "bad audio"}]
        )

        with self.assertRaisesRegex(atlas_transcribe.AtlasError, "bad audio"):
            atlas_transcribe.transcribe(
                str(self.audio),
                token="test-token",
                confirmed=True,
                transport=transport,
                sleep=lambda _: None,
                stderr=io.StringIO(),
            )

        self.assertEqual([call[0] for call in transport.calls].count("POST"), 1)

    def test_prediction_get_errors_use_bounded_backoff(self):
        transport = FakeTransport(
            [
                atlas_transcribe.AtlasError("temporary GET failure"),
                atlas_transcribe.AtlasError("temporary GET failure"),
            ]
        )
        sleeps: list[float] = []

        with self.assertRaisesRegex(atlas_transcribe.AtlasError, "2 GET attempts"):
            atlas_transcribe.transcribe(
                str(self.audio),
                token="test-token",
                confirmed=True,
                poll_attempts=2,
                poll_interval=0.5,
                transport=transport,
                sleep=sleeps.append,
                stderr=io.StringIO(),
            )

        self.assertEqual(sleeps, [0.5])
        self.assertEqual([call[0] for call in transport.calls].count("POST"), 1)


if __name__ == "__main__":
    unittest.main()
