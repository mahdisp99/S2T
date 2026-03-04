from __future__ import annotations

import base64
import json
import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

APP_DIR_NAME = "SpeechToTextWindows"
CONFIG_FILE_NAME = "config.json"
DATABASE_FILE_NAME = "transcriptions.db"
DEFAULT_HOTKEY = "ctrl+shift+space"
DEFAULT_PASTE_LANGUAGE = "fa"
VALID_PASTE_LANGUAGES = {"fa", "en"}


def app_dir_path() -> Path:
    base_path = Path(os.getenv("APPDATA") or Path.home())
    app_path = base_path / APP_DIR_NAME
    app_path.mkdir(parents=True, exist_ok=True)
    return app_path


def config_file_path() -> Path:
    return app_dir_path() / CONFIG_FILE_NAME


def database_file_path() -> Path:
    return app_dir_path() / DATABASE_FILE_NAME


def _obfuscate(value: str) -> str:
    return base64.b64encode(value.encode("utf-8")).decode("utf-8")


def _deobfuscate(value: str) -> str:
    if not value:
        return ""
    try:
        return base64.b64decode(value.encode("utf-8")).decode("utf-8")
    except Exception:
        return ""


@dataclass
class AppConfig:
    api_key: str = ""
    hotkey: str = DEFAULT_HOTKEY
    paste_language: str = DEFAULT_PASTE_LANGUAGE

    @property
    def has_api_key(self) -> bool:
        return bool(self.api_key.strip())


def load_config() -> AppConfig:
    load_dotenv()

    config_path = config_file_path()
    payload: dict[str, str] = {}

    if config_path.exists():
        try:
            payload = json.loads(config_path.read_text(encoding="utf-8"))
        except Exception:
            payload = {}

    env_api_key = os.getenv("SONIOX_API_KEY", "").strip()
    stored_api_key = _deobfuscate(payload.get("api_key", ""))
    api_key = env_api_key or stored_api_key

    hotkey = payload.get("hotkey", DEFAULT_HOTKEY).strip().lower() or DEFAULT_HOTKEY
    paste_language = payload.get("paste_language", DEFAULT_PASTE_LANGUAGE).strip().lower()
    if paste_language not in VALID_PASTE_LANGUAGES:
        paste_language = DEFAULT_PASTE_LANGUAGE

    return AppConfig(api_key=api_key, hotkey=hotkey, paste_language=paste_language)


def save_config(config: AppConfig) -> Path:
    payload = {
        "api_key": _obfuscate(config.api_key.strip()) if config.api_key.strip() else "",
        "hotkey": config.hotkey.strip().lower() or DEFAULT_HOTKEY,
        "paste_language": (
            config.paste_language.strip().lower()
            if config.paste_language.strip().lower() in VALID_PASTE_LANGUAGES
            else DEFAULT_PASTE_LANGUAGE
        ),
    }

    path = config_file_path()
    path.write_text(json.dumps(payload, ensure_ascii=True, indent=2), encoding="utf-8")
    return path

