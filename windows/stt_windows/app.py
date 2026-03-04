from __future__ import annotations

import threading
import time
import uuid
from datetime import datetime, timezone
from typing import Callable

import keyboard

from .audio import AudioRecorder
from .config import AppConfig
from .paste import paste_text
from .soniox import SonioxClient
from .storage import TranscriptStorage


StateChangeCallback = Callable[[bool], None]
MessageCallback = Callable[[str], None]
FinalTextCallback = Callable[[str, str], None]


class SpeechToTextService:
    def __init__(
        self,
        config: AppConfig,
        on_state_change: StateChangeCallback | None = None,
        on_status: MessageCallback | None = None,
        on_error: MessageCallback | None = None,
        on_final_text: FinalTextCallback | None = None,
    ) -> None:
        self.config = config
        self.storage = TranscriptStorage()
        self.audio = AudioRecorder(target_sample_rate=16000)
        self.soniox = SonioxClient(api_key=config.api_key, sample_rate=16000)
        self._on_state_change = on_state_change
        self._on_status = on_status
        self._on_error = on_error
        self._on_final_text = on_final_text

        self._state_lock = threading.Lock()
        self._hotkey_handle: int | str | None = None
        self._is_recording = False
        self._session_id: str | None = None
        self._started_at: datetime | None = None
        self._chunk_counter = 0
        self._accumulated_persian = ""
        self._accumulated_english = ""

    @property
    def is_recording(self) -> bool:
        with self._state_lock:
            return self._is_recording

    def register_hotkey(self) -> bool:
        self.unregister_hotkey()

        hotkey = self.config.hotkey.strip().lower()
        if not hotkey:
            self._emit_error("Hotkey is empty and cannot be registered.")
            return False

        try:
            self._hotkey_handle = keyboard.add_hotkey(
                hotkey,
                self.toggle_recording,
                suppress=False,
                trigger_on_release=True,
            )
            self._emit_status(f"[hotkey] registered: {hotkey}")
            return True
        except Exception as exc:
            self._hotkey_handle = None
            self._emit_error(f"Failed to register hotkey '{hotkey}': {exc}")
            return False

    def unregister_hotkey(self) -> None:
        if self._hotkey_handle is None:
            return

        try:
            keyboard.remove_hotkey(self._hotkey_handle)
        except Exception:
            pass
        finally:
            self._hotkey_handle = None

    def apply_config(self, config: AppConfig) -> None:
        with self._state_lock:
            previous_hotkey = self.config.hotkey
            previous_api_key = self.config.api_key
            self.config = config

        if previous_api_key != config.api_key:
            if self.is_recording:
                self.stop_recording()
            self.soniox = SonioxClient(api_key=config.api_key, sample_rate=16000)
            self._emit_status("[config] API key updated")

        if previous_hotkey != config.hotkey:
            self.register_hotkey()

    def toggle_recording(self) -> None:
        if self.is_recording:
            self.stop_recording()
        else:
            self.start_recording()

    def start_recording(self) -> None:
        with self._state_lock:
            if self._is_recording:
                return
            if not self.config.has_api_key:
                self._emit_error("No API key configured. Open settings and save API key first.")
                return
            self._is_recording = True
            self._session_id = str(uuid.uuid4())
            self._started_at = datetime.now(timezone.utc)
            self._chunk_counter = 0
            self._accumulated_persian = ""
            self._accumulated_english = ""

        self._emit_state_change(True)
        self._emit_status(f"[session:{self._session_id}] recording started")

        self.soniox.connect(
            on_text=self._on_persian_text,
            on_translation=self._on_english_text,
        )

        try:
            self.audio.start(on_audio_data=self.soniox.send_audio, on_level=self._on_level)
        except Exception as exc:
            self._emit_error(f"Failed to start microphone capture: {exc}")
            self.stop_recording()

    def stop_recording(self) -> None:
        with self._state_lock:
            if not self._is_recording:
                return
            self._is_recording = False
            session_id = self._session_id
            started_at = self._started_at
            persian_text = self._accumulated_persian.strip()
            english_text = self._accumulated_english.strip()
            self._session_id = None
            self._started_at = None

        self.audio.stop()
        self.soniox.disconnect()
        self._emit_state_change(False)

        ended_at = datetime.now(timezone.utc)
        if session_id and started_at and persian_text:
            self.storage.save_session(
                session_id=session_id,
                full_persian_text=persian_text,
                full_english_text=english_text,
                language_pasted=self.config.paste_language,
                started_at=started_at,
                ended_at=ended_at,
                hotkey_used=self.config.hotkey,
            )
            self._emit_status(
                f"[session:{session_id}] saved "
                f"(fa chars: {len(persian_text)}, en chars: {len(english_text)})"
            )
        else:
            self._emit_status("[session] stopped without transcript")

    def _on_level(self, level: float) -> None:
        _ = level

    def _on_persian_text(self, text: str, is_final: bool) -> None:
        self._handle_text(text=text, is_final=is_final, translation_status="original")

    def _on_english_text(self, text: str, is_final: bool) -> None:
        self._handle_text(text=text, is_final=is_final, translation_status="translation")

    def _handle_text(self, text: str, is_final: bool, translation_status: str) -> None:
        clean_text = text.replace("<end>", "").strip()
        if not clean_text:
            return

        paste_now = False
        log_tag = "FA" if translation_status == "original" else "EN"

        with self._state_lock:
            if not self._is_recording or not self._session_id:
                return

            session_id = self._session_id
            self._chunk_counter += 1
            chunk_order = self._chunk_counter

            if is_final:
                if translation_status == "original":
                    self._accumulated_persian = _append_text(self._accumulated_persian, clean_text)
                    paste_now = self.config.paste_language == "fa"
                else:
                    self._accumulated_english = _append_text(self._accumulated_english, clean_text)
                    paste_now = self.config.paste_language == "en"

        self.storage.save_chunk(
            session_id=session_id,
            chunk_text=clean_text,
            chunk_order=chunk_order,
            is_final=is_final,
            translation_status=translation_status,
        )

        if is_final:
            self._emit_status(f"[{log_tag} final] {clean_text}")
            if self._on_final_text is not None:
                language = "fa" if translation_status == "original" else "en"
                self._on_final_text(language, clean_text)
            if paste_now:
                try:
                    paste_text(clean_text + " ")
                except Exception as exc:
                    self._emit_error(f"[paste] failed: {exc}")

    def shutdown(self) -> None:
        self.unregister_hotkey()
        self.stop_recording()
        self.storage.close()

    def _emit_state_change(self, is_recording: bool) -> None:
        if self._on_state_change is not None:
            self._on_state_change(is_recording)

    def _emit_status(self, message: str) -> None:
        if self._on_status is not None:
            self._on_status(message)
        else:
            print(message)

    def _emit_error(self, message: str) -> None:
        if self._on_error is not None:
            self._on_error(message)
        else:
            print(f"[error] {message}")


class SpeechToTextWindowsApp:
    def __init__(self, config: AppConfig) -> None:
        self.config = config
        self.service = SpeechToTextService(
            config=config,
            on_status=lambda message: print(message),
            on_error=lambda message: print(f"[error] {message}"),
        )

    def run(self) -> int:
        if not self.config.has_api_key:
            print("No API key found. Configure it first:")
            print("python windows/cli.py --set-api-key <SONIOX_API_KEY> --configure-only")
            return 1

        print("Speech-to-Text (Windows preview)")
        print(f"Hotkey: {self.config.hotkey}")
        print("Press hotkey once to start recording, again to stop.")
        print("Press Ctrl+C to exit.")

        self.service.register_hotkey()

        try:
            while True:
                time.sleep(0.25)
        except KeyboardInterrupt:
            print("\nExit requested by user")
        finally:
            self.service.shutdown()

        return 0


def _append_text(existing: str, addition: str) -> str:
    if not existing:
        return addition
    return f"{existing} {addition}"
