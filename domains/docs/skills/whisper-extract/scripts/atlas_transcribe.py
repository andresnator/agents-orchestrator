#!/usr/bin/env python3
"""Transcribe audio with Atlas Cloud's Seed ASR 2.0 model."""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
from pathlib import Path
import sys
import time
from typing import Any, Callable
import urllib.error
import urllib.parse
import urllib.request


API_BASE = "https://api.atlascloud.ai"
MODEL = "bytedance/seed-asr-2.0"
GENERATE_PATH = "/api/v1/model/generateAudio"
PREDICTION_PATH = "/api/v1/model/prediction/{request_id}"
SUPPORTED_FORMATS = {"mp3", "wav", "ogg", "raw"}
MAX_LOCAL_BYTES = 512 * 1024 * 1024


class AtlasError(RuntimeError):
    """Raised for a failed Atlas request or invalid response."""


class HTTPTransport:
    """Small JSON transport that never retries requests."""

    def request(
        self,
        method: str,
        url: str,
        *,
        token: str | None = None,
        payload: dict[str, Any] | None = None,
    ) -> Any:
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https":
            raise AtlasError(f"Refusing non-HTTPS endpoint: {url}")
        if token and parsed.netloc != "api.atlascloud.ai":
            raise AtlasError("Refusing to send the API key outside api.atlascloud.ai")

        headers = {
            "Accept": "application/json",
            "User-Agent": "agents-orchestrator-whisper-extract/1.2.0",
        }
        body = None
        if token:
            headers["Authorization"] = f"Bearer {token}"
        if payload is not None:
            headers["Content-Type"] = "application/json"
            body = json.dumps(payload).encode("utf-8")

        request = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            raise AtlasError(f"Atlas returned HTTP {error.code} for {method} {parsed.path}") from error
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            raise AtlasError(f"Atlas request failed for {method} {parsed.path}: {error}") from error


def _catalog_items(response: Any) -> list[dict[str, Any]]:
    data = response.get("data", response) if isinstance(response, dict) else response
    if isinstance(data, dict):
        data = data.get("models", data.get("items"))
    if not isinstance(data, list):
        raise AtlasError("Model catalog response did not contain a model list")
    return [item for item in data if isinstance(item, dict)]


def _prediction(response: Any) -> dict[str, Any]:
    data = response.get("data", response) if isinstance(response, dict) else response
    if not isinstance(data, dict):
        raise AtlasError("Prediction response was not an object")
    return data


def _price_quote(model: dict[str, Any]) -> str:
    price = model.get("price")
    if isinstance(price, dict):
        actual = price.get("actual")
        if isinstance(actual, dict) and actual.get("base_price") is not None:
            return str(actual["base_price"])
    if model.get("base_price") is not None:
        return str(model["base_price"])
    return "not published"


def _validate_schema(schema: Any) -> None:
    try:
        paths = schema["paths"]
        input_schema = schema["components"]["schemas"]["Input"]
    except (KeyError, TypeError) as error:
        raise AtlasError("Model schema did not contain the expected OpenAPI contract") from error

    if GENERATE_PATH not in paths or PREDICTION_PATH not in paths:
        raise AtlasError("Model schema does not expose the expected generation and prediction routes")
    required = set(input_schema.get("required", []))
    if not {"model", "audio_url"}.issubset(required):
        raise AtlasError("Model schema no longer requires the expected input fields")


def _audio_format(source: str, explicit: str | None) -> str:
    if explicit:
        return explicit
    path = urllib.parse.urlparse(source).path if source.startswith("https://") else source
    suffix = Path(path).suffix.lower().lstrip(".")
    if suffix not in SUPPORTED_FORMATS:
        raise AtlasError("Cannot infer audio format; pass --format with mp3, wav, ogg, or raw")
    return suffix


def _validate_audio_source(source: str) -> Path | None:
    parsed = urllib.parse.urlparse(source)
    if parsed.scheme:
        if parsed.scheme != "https" or not parsed.netloc:
            raise AtlasError("Remote audio must use a public HTTPS URL")
        return None

    path = Path(source).expanduser()
    if not path.is_file():
        raise AtlasError(f"Audio file not found: {source}")
    if path.stat().st_size > MAX_LOCAL_BYTES:
        raise AtlasError("Local audio exceeds the Atlas model's 512 MB limit")
    return path


def _audio_value(source: str, audio_format: str) -> str:
    path = _validate_audio_source(source)
    if path is None:
        return source
    mime = mimetypes.guess_type(path.name)[0] or f"audio/{audio_format}"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def _find_model(transport: Any, token: str) -> dict[str, Any]:
    response = transport.request("GET", f"{API_BASE}/api/v1/models", token=token)
    for model in _catalog_items(response):
        if model.get("model") == MODEL:
            if model.get("display_console") is False:
                raise AtlasError(f"{MODEL} is not currently available in the Atlas catalog")
            return model
    raise AtlasError(f"{MODEL} was not found in the live Atlas catalog")


def _schema(transport: Any, model: dict[str, Any]) -> dict[str, Any]:
    schema_url = model.get("schema")
    if not isinstance(schema_url, str) or not schema_url:
        raise AtlasError("The live model catalog did not provide a schema URL")
    response = transport.request("GET", schema_url)
    if not isinstance(response, dict):
        raise AtlasError("Model schema response was not an object")
    _validate_schema(response)
    return response


def _request_id(prediction: dict[str, Any]) -> str:
    value = prediction.get("id") or prediction.get("request_id")
    if not isinstance(value, str) or not value:
        raise AtlasError("Generation response did not contain a prediction ID")
    return value


def _completed_result(
    prediction: dict[str, Any], quote: str, request_id: str | None = None
) -> dict[str, Any]:
    stt_result = prediction.get("stt_result")
    text = stt_result.get("text") if isinstance(stt_result, dict) else None
    outputs = prediction.get("outputs")
    if not text and isinstance(outputs, list) and outputs:
        text = outputs[0]
    if not isinstance(text, str):
        raise AtlasError("Completed prediction did not contain transcript text")
    return {
        "submitted": True,
        "model": MODEL,
        "prediction_id": request_id or _request_id(prediction),
        "status": prediction.get("status"),
        "text": text,
        "stt_result": stt_result,
        "catalog_price": quote,
    }


def transcribe(
    source: str,
    *,
    token: str,
    confirmed: bool,
    audio_format: str | None = None,
    language: str | None = None,
    enable_punc: bool = False,
    enable_speaker_info: bool = False,
    show_utterances: bool = False,
    poll_attempts: int = 8,
    poll_interval: float = 2.0,
    transport: Any | None = None,
    sleep: Callable[[float], None] = time.sleep,
    stderr: Any = sys.stderr,
) -> dict[str, Any]:
    """Preflight the live contract, submit once, then poll with bounded GET retries."""
    if not token:
        raise AtlasError("Set ATLASCLOUD_API_KEY before using the Atlas backend")
    if poll_attempts < 1:
        raise AtlasError("--poll-attempts must be at least 1")
    if poll_interval < 0:
        raise AtlasError("--poll-interval cannot be negative")

    transport = transport or HTTPTransport()
    model = _find_model(transport, token)
    _schema(transport, model)
    quote = _price_quote(model)
    print(f"Live Atlas catalog price for {MODEL}: {quote}", file=stderr)

    fmt = _audio_format(source, audio_format)
    _validate_audio_source(source)
    if not confirmed:
        return {
            "submitted": False,
            "model": MODEL,
            "catalog_price": quote,
            "message": "Preflight complete. Re-run with --yes only after explicit cost approval.",
        }

    audio = _audio_value(source, fmt)
    payload: dict[str, Any] = {
        "model": MODEL,
        "audio_url": audio,
        "format": fmt,
        "enable_punc": enable_punc,
        "enable_speaker_info": enable_speaker_info,
        "show_utterances": show_utterances,
    }
    if language:
        payload["language"] = language

    submitted = _prediction(
        transport.request(
            "POST",
            f"{API_BASE}{GENERATE_PATH}",
            token=token,
            payload=payload,
        )
    )
    request_id = _request_id(submitted)
    if str(submitted.get("status", "")).lower() == "completed":
        return _completed_result(submitted, quote, request_id)

    last_error: AtlasError | None = None
    for attempt in range(poll_attempts):
        try:
            current = _prediction(
                transport.request(
                    "GET",
                    f"{API_BASE}{PREDICTION_PATH.format(request_id=request_id)}",
                    token=token,
                )
            )
            last_error = None
        except AtlasError as error:
            last_error = error
            current = {}

        status = str(current.get("status", "")).lower()
        if status == "completed":
            return _completed_result(current, quote, request_id)
        if status in {"failed", "canceled", "cancelled"}:
            detail = current.get("error") or current.get("message") or "no error detail"
            raise AtlasError(f"Prediction {request_id} ended with {status}: {detail}")
        if attempt + 1 < poll_attempts:
            sleep(poll_interval * min(2**attempt, 8))

    if last_error:
        raise AtlasError(f"Prediction polling exhausted after {poll_attempts} GET attempts: {last_error}")
    raise AtlasError(f"Prediction {request_id} did not complete after {poll_attempts} GET attempts")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Transcribe audio with optional Atlas Cloud Seed ASR 2.0."
    )
    parser.add_argument("audio", help="Local audio path or public HTTPS URL")
    parser.add_argument("--format", choices=sorted(SUPPORTED_FORMATS))
    parser.add_argument("--language", help="Language code such as en-US, zh-CN, or es-MX")
    parser.add_argument("--enable-punc", action="store_true", help="Add punctuation")
    parser.add_argument("--enable-speaker-info", action="store_true", help="Enable diarization")
    parser.add_argument("--show-utterances", action="store_true", help="Return timestamped segments")
    parser.add_argument("--poll-attempts", type=int, default=8)
    parser.add_argument("--poll-interval", type=float, default=2.0)
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Confirm the live catalog quote and allow exactly one paid generation POST",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    token = os.environ.get("ATLASCLOUD_API_KEY") or os.environ.get("ATLAS_CLOUD_API_KEY", "")
    try:
        result = transcribe(
            args.audio,
            token=token,
            confirmed=args.yes,
            audio_format=args.format,
            language=args.language,
            enable_punc=args.enable_punc,
            enable_speaker_info=args.enable_speaker_info,
            show_utterances=args.show_utterances,
            poll_attempts=args.poll_attempts,
            poll_interval=args.poll_interval,
        )
    except AtlasError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
