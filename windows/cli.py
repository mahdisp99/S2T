from __future__ import annotations

import argparse
import sys

from stt_windows.config import (
    AppConfig,
    config_file_path,
    load_config,
    save_config,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Speech-to-Text Windows preview")
    parser.add_argument("--set-api-key", type=str, help="Persist Soniox API key to local config")
    parser.add_argument(
        "--hotkey",
        type=str,
        help="Global hotkey format for keyboard package (default: ctrl+shift+space)",
    )
    parser.add_argument(
        "--paste-language",
        choices=["fa", "en"],
        help="Language to paste automatically for final chunks",
    )
    parser.add_argument(
        "--show-config",
        action="store_true",
        help="Print effective runtime config and exit",
    )
    parser.add_argument(
        "--configure-only",
        action="store_true",
        help="Only save config and exit without running the app",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    config = load_config()
    changed = False

    if args.set_api_key is not None:
        config.api_key = args.set_api_key.strip()
        changed = True

    if args.hotkey is not None:
        config.hotkey = args.hotkey.strip().lower()
        changed = True

    if args.paste_language is not None:
        config.paste_language = args.paste_language
        changed = True

    if changed:
        path = save_config(config)
        print(f"Config saved at: {path}")

    if args.show_config:
        _print_config(config)
        return 0

    if args.configure_only:
        return 0

    from stt_windows.app import SpeechToTextWindowsApp

    app = SpeechToTextWindowsApp(config=config)
    return app.run()


def _print_config(config: AppConfig) -> None:
    print(f"config file: {config_file_path()}")
    print(f"api_key configured: {config.has_api_key}")
    print(f"hotkey: {config.hotkey}")
    print(f"paste_language: {config.paste_language}")


if __name__ == "__main__":
    sys.exit(main())
