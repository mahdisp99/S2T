from __future__ import annotations

import os
import queue
import threading
import tkinter as tk
from tkinter import messagebox, ttk

import keyboard
import pystray
from PIL import Image, ImageDraw

from .app import SpeechToTextService
from .config import AppConfig, app_dir_path, load_config, save_config


class SpeechToTextTrayApp:
    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.withdraw()

        self._action_queue: queue.Queue[str] = queue.Queue()
        self._status_var = tk.StringVar(value="Ready")
        self._recording_var = tk.StringVar(value="Stopped")
        self._settings_window: tk.Toplevel | None = None
        self._api_key_var = tk.StringVar(value="")
        self._hotkey_var = tk.StringVar(value="")
        self._paste_lang_var = tk.StringVar(value="fa")
        self._is_quitting = False

        self.config = load_config()
        self._api_key_var.set(self.config.api_key)
        self._hotkey_var.set(self.config.hotkey)
        self._paste_lang_var.set(self.config.paste_language)

        self.service = SpeechToTextService(
            config=self.config,
            on_state_change=self._on_service_state_change,
            on_status=self._on_service_status,
            on_error=self._on_service_error,
        )
        self.service.register_hotkey()

        self.icon = self._build_tray_icon()
        self._tray_thread = threading.Thread(target=self.icon.run, daemon=True)
        self._tray_thread.start()

        self.root.after(200, self._process_actions)

        if not self.config.has_api_key:
            self.root.after(400, self.show_settings)
            self.root.after(450, lambda: self._status_var.set("API key is required"))

    def run(self) -> int:
        try:
            self.root.mainloop()
            return 0
        finally:
            self._quit_internal()

    def _build_tray_icon(self) -> pystray.Icon:
        menu = pystray.Menu(
            pystray.MenuItem(
                lambda _item: "Stop Recording" if self.service.is_recording else "Start Recording",
                self._tray_toggle_recording,
            ),
            pystray.MenuItem("Settings", self._tray_open_settings),
            pystray.MenuItem(
                lambda _item: f"Hotkey: {self.config.hotkey}",
                lambda _icon, _item: None,
                enabled=False,
            ),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Open Data Folder", self._tray_open_data_dir),
            pystray.MenuItem("Quit", self._tray_quit),
        )
        return pystray.Icon(
            "speech_to_text_windows",
            self._create_icon_image(recording=False),
            "Speech to Text (Windows)",
            menu,
        )

    def _create_icon_image(self, recording: bool) -> Image.Image:
        background = (29, 46, 63)
        accent = (220, 53, 69) if recording else (46, 204, 113)
        image = Image.new("RGB", (64, 64), background)
        draw = ImageDraw.Draw(image)
        draw.rounded_rectangle((6, 6, 58, 58), radius=13, fill=(20, 31, 44))
        draw.ellipse((18, 12, 46, 40), fill=accent)
        draw.rectangle((28, 38, 36, 50), fill=accent)
        draw.rounded_rectangle((22, 50, 42, 54), radius=2, fill=(230, 230, 230))
        return image

    def _process_actions(self) -> None:
        while True:
            try:
                action = self._action_queue.get_nowait()
            except queue.Empty:
                break
            self._handle_action(action)

        if not self._is_quitting:
            self.root.after(120, self._process_actions)

    def _handle_action(self, action: str) -> None:
        if action == "toggle":
            self.service.toggle_recording()
            return
        if action == "settings":
            self.show_settings()
            return
        if action == "open_data":
            os.startfile(str(app_dir_path()))
            return
        if action == "quit":
            self._quit_internal()
            return

    def show_settings(self) -> None:
        if self._settings_window is not None and self._settings_window.winfo_exists():
            self._settings_window.deiconify()
            self._settings_window.lift()
            self._settings_window.focus_force()
            return

        window = tk.Toplevel(self.root)
        window.title("Speech to Text Settings")
        window.geometry("500x300")
        window.resizable(False, False)
        window.protocol("WM_DELETE_WINDOW", window.withdraw)
        self._settings_window = window

        frame = ttk.Frame(window, padding=16)
        frame.pack(fill=tk.BOTH, expand=True)

        ttk.Label(frame, text="Status").grid(row=0, column=0, sticky=tk.W, pady=4)
        ttk.Label(frame, textvariable=self._status_var).grid(row=0, column=1, sticky=tk.W, pady=4)

        ttk.Label(frame, text="Recording").grid(row=1, column=0, sticky=tk.W, pady=4)
        ttk.Label(frame, textvariable=self._recording_var).grid(row=1, column=1, sticky=tk.W, pady=4)

        ttk.Label(frame, text="Soniox API Key").grid(row=2, column=0, sticky=tk.W, pady=8)
        api_entry = ttk.Entry(frame, textvariable=self._api_key_var, width=45, show="*")
        api_entry.grid(row=2, column=1, sticky=tk.W, pady=8)

        ttk.Label(frame, text="Hotkey").grid(row=3, column=0, sticky=tk.W, pady=8)
        ttk.Entry(frame, textvariable=self._hotkey_var, width=30).grid(row=3, column=1, sticky=tk.W, pady=8)

        ttk.Label(frame, text="Paste Language").grid(row=4, column=0, sticky=tk.W, pady=8)
        lang_combo = ttk.Combobox(
            frame,
            textvariable=self._paste_lang_var,
            state="readonly",
            values=("fa", "en"),
            width=8,
        )
        lang_combo.grid(row=4, column=1, sticky=tk.W, pady=8)

        button_frame = ttk.Frame(frame)
        button_frame.grid(row=5, column=1, sticky=tk.W, pady=20)

        ttk.Button(button_frame, text="Save", command=self._save_settings).pack(side=tk.LEFT, padx=(0, 8))
        ttk.Button(button_frame, text="Start/Stop", command=self.service.toggle_recording).pack(
            side=tk.LEFT, padx=(0, 8)
        )
        ttk.Button(button_frame, text="Close", command=window.withdraw).pack(side=tk.LEFT)

        frame.columnconfigure(1, weight=1)

        window.deiconify()
        window.lift()
        window.focus_force()

    def _save_settings(self) -> None:
        api_key = self._api_key_var.get().strip()
        hotkey = self._hotkey_var.get().strip().lower()
        paste_language = self._paste_lang_var.get().strip().lower()

        if not hotkey:
            messagebox.showerror("Invalid Settings", "Hotkey cannot be empty.")
            return

        try:
            keyboard.parse_hotkey(hotkey)
        except Exception as exc:
            messagebox.showerror("Invalid Settings", f"Hotkey format is invalid: {exc}")
            return

        if paste_language not in {"fa", "en"}:
            messagebox.showerror("Invalid Settings", "Paste language must be 'fa' or 'en'.")
            return

        new_config = AppConfig(api_key=api_key, hotkey=hotkey, paste_language=paste_language)
        save_config(new_config)
        self.config = new_config
        self.service.apply_config(new_config)
        self.icon.update_menu()
        self._status_var.set("Settings saved")

    def _on_service_state_change(self, is_recording: bool) -> None:
        def update_state() -> None:
            self._recording_var.set("Recording" if is_recording else "Stopped")
            self.icon.icon = self._create_icon_image(recording=is_recording)
            self.icon.update_menu()

        self.root.after(0, update_state)

    def _on_service_status(self, message: str) -> None:
        print(message)
        self.root.after(0, lambda: self._status_var.set(message))

    def _on_service_error(self, message: str) -> None:
        print(f"[error] {message}")

        def show_error() -> None:
            self._status_var.set(message)
            messagebox.showerror("Speech to Text", message)

        self.root.after(0, show_error)

    def _tray_toggle_recording(self, _icon: pystray.Icon, _item: pystray.MenuItem) -> None:
        self._action_queue.put("toggle")

    def _tray_open_settings(self, _icon: pystray.Icon, _item: pystray.MenuItem) -> None:
        self._action_queue.put("settings")

    def _tray_open_data_dir(self, _icon: pystray.Icon, _item: pystray.MenuItem) -> None:
        self._action_queue.put("open_data")

    def _tray_quit(self, _icon: pystray.Icon, _item: pystray.MenuItem) -> None:
        self._action_queue.put("quit")

    def _quit_internal(self) -> None:
        if self._is_quitting:
            return

        self._is_quitting = True

        try:
            self.service.shutdown()
        finally:
            try:
                if self.icon is not None:
                    self.icon.stop()
            except Exception:
                pass

            try:
                self.root.quit()
                self.root.destroy()
            except Exception:
                pass

