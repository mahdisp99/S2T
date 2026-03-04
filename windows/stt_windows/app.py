from __future__ import annotations

import threading
import time
import uuid
from datetime import datetime, timezone

import keyboard

from .audio import AudioRecorder
from .config import AppConfig
from .paste import paste_text
from .soniox import SonioxClient
from .storage import TranscriptStorage


class SpeechToTextWindowsApp:
    def __init__(self, config: AppConfig) -> None:
        self.config = config
        self.storage = TranscriptStorage()
        self.audio = AudioRecorder(target_sample_rate=16000)
        self.soniox = SonioxClient(api_key=config.api_key, sample_rate=16000)

        self._state_lock = threading.Lock()
        self._is_recording = False
        self._session_id: str | None = None
        self._started_at: datetime | None = None
        self._chunk_counter = 0
        self._accumulated_persian = ""
        self._accumulated_english = ""

    def run(self) -> int:
        if not self.config.has_api_key:
            print("No API key found. Configure it first:")
            print("python windows/cli.py --set-api-key <SONIOX_API_KEY> --configure-only")
            return 1

        print("Speech-to-Text (Windows preview)")
        print(f"Hotkey: {self.config.hotkey}")
        print("Press hotkey once to start recording, again to stop.")
        print("Press Ctrl+C to exit.")

        keyboard.add_hotkey(
            self.config.hotkey,
            self.toggle_recording,
            suppress=False,
            trigger_on_release=True,
        )

        try:
            while True:
                time.sleep(0.25)
        except KeyboardInterrupt:
            print("\nExit requested by user")
        finally:
            keyboard.unhook_all_hotkeys()
            self.stop_recording()
            self.storage.close()

        return 0

    def toggle_recording(self) -> None:
        with self._state_lock:
            is_recording = self._is_recording
        if is_recording:
            self.stop_recording()
        else:
            self.start_recording()

    def start_recording(self) -> None:
        with self._state_lock:
            if self._is_recording:
                return
            self._is_recording = True
            self._session_id = str(uuid.uuid4())
            self._started_at = datetime.now(timezone.utc)
            self._chunk_counter = 0
            self._accumulated_persian = ""
            self._accumulated_english = ""

        print(f"[session:{self._session_id}] recording started")

        self.soniox.connect(
            on_text=self._on_persian_text,
            on_translation=self._on_english_text,
        )

        try:
            self.audio.start(on_audio_data=self.soniox.send_audio, on_level=self._on_level)
        except Exception as exc:
            print(f"Failed to start microphone capture: {exc}")
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
            print(
                f"[session:{session_id}] saved "
                f"(fa chars: {len(persian_text)}, en chars: {len(english_text)})"
            )
        else:
            print("[session] stopped without transcript")

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
            print(f"[{log_tag} final] {clean_text}")
            if paste_now:
                try:
                    paste_text(clean_text + " ")
                except Exception as exc:
                    print(f"[paste] failed: {exc}")


def _append_text(existing: str, addition: str) -> str:
    if not existing:
        return addition
    return f"{existing} {addition}"

