from __future__ import annotations

import time

import keyboard
import pyperclip


def paste_text(text: str) -> None:
    if not text:
        return

    pyperclip.copy(text)
    time.sleep(0.08)
    keyboard.send("ctrl+v")

