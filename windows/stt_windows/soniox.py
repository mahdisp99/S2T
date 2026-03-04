from __future__ import annotations

import json
import threading
from collections.abc import Callable

import websocket

SONIOX_URL = "wss://stt-rt.soniox.com/transcribe-websocket"


class SonioxClient:
    def __init__(self, api_key: str, sample_rate: int = 16000) -> None:
        self.api_key = api_key
        self.sample_rate = sample_rate
        self._ws: websocket.WebSocketApp | None = None
        self._thread: threading.Thread | None = None
        self._connected = threading.Event()
        self._ws_lock = threading.Lock()
        self._on_text: Callable[[str, bool], None] | None = None
        self._on_translation: Callable[[str, bool], None] | None = None

    def connect(
        self,
        on_text: Callable[[str, bool], None],
        on_translation: Callable[[str, bool], None],
    ) -> None:
        self.disconnect()
        self._on_text = on_text
        self._on_translation = on_translation
        self._connected.clear()

        self._ws = websocket.WebSocketApp(
            SONIOX_URL,
            on_open=self._on_open,
            on_message=self._on_message,
            on_error=self._on_error,
            on_close=self._on_close,
        )

        self._thread = threading.Thread(target=self._run_forever, daemon=True)
        self._thread.start()

        if not self._connected.wait(timeout=7):
            print("[soniox] websocket did not become ready in time")

    def send_audio(self, chunk: bytes) -> None:
        if not chunk:
            return

        if not self._connected.is_set():
            return

        with self._ws_lock:
            if self._ws is None:
                return
            try:
                self._ws.send(chunk, opcode=websocket.ABNF.OPCODE_BINARY)
            except Exception as exc:
                print(f"[soniox] send audio failed: {exc}")

    def disconnect(self) -> None:
        with self._ws_lock:
            ws = self._ws
            self._ws = None

        if ws is not None:
            try:
                ws.send(b"", opcode=websocket.ABNF.OPCODE_BINARY)
            except Exception:
                pass
            try:
                ws.close()
            except Exception:
                pass

        self._connected.clear()

        if self._thread is not None and self._thread.is_alive():
            self._thread.join(timeout=1.0)
        self._thread = None

    def _run_forever(self) -> None:
        with self._ws_lock:
            ws = self._ws
        if ws is None:
            return

        ws.run_forever(
            ping_interval=30,
            ping_timeout=10,
            skip_utf8_validation=True,
        )

    def _on_open(self, ws: websocket.WebSocketApp) -> None:
        self._connected.set()
        config_payload = {
            "api_key": self.api_key,
            "model": "stt-rt-preview",
            "audio_format": "pcm_s16le",
            "sample_rate": self.sample_rate,
            "num_channels": 1,
            "enable_endpoint_detection": True,
            "enable_streaming": True,
            "translation": {"type": "one_way", "target_language": "en"},
        }
        ws.send(json.dumps(config_payload))
        print("[soniox] websocket connected")

    def _on_message(self, ws: websocket.WebSocketApp, message: str | bytes) -> None:
        if isinstance(message, bytes):
            text_message = message.decode("utf-8", errors="ignore")
        else:
            text_message = message

        try:
            payload = json.loads(text_message)
        except json.JSONDecodeError:
            return

        tokens = payload.get("tokens", [])
        if not isinstance(tokens, list) or not tokens:
            return

        final_original = []
        partial_original = []
        final_translation = []
        partial_translation = []

        for token in tokens:
            if not isinstance(token, dict):
                continue
            text = str(token.get("text", ""))
            if not text:
                continue
            is_final = bool(token.get("is_final", False))
            translation_status = str(token.get("translation_status", "original"))

            if translation_status == "translation":
                if is_final:
                    final_translation.append(text)
                else:
                    partial_translation.append(text)
            else:
                if is_final:
                    final_original.append(text)
                else:
                    partial_original.append(text)

        if final_original and self._on_text is not None:
            self._on_text("".join(final_original), True)
        elif partial_original and self._on_text is not None:
            self._on_text("".join(partial_original), False)

        if final_translation and self._on_translation is not None:
            self._on_translation("".join(final_translation), True)
        elif partial_translation and self._on_translation is not None:
            self._on_translation("".join(partial_translation), False)

    def _on_error(self, ws: websocket.WebSocketApp, error: object) -> None:
        self._connected.clear()
        print(f"[soniox] websocket error: {error}")

    def _on_close(
        self,
        ws: websocket.WebSocketApp,
        status_code: int | None,
        message: str | None,
    ) -> None:
        self._connected.clear()
        print(f"[soniox] websocket closed: code={status_code}, reason={message}")

