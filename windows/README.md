# Speech to Text (Windows)

Windows implementation now includes a tray UI and a build pipeline for a standalone `.exe`.

Current scope:
- Real-time microphone capture on Windows
- Soniox WebSocket streaming (Persian + English translation)
- Tray app with settings window
- Global hotkey toggle for recording
- Auto-copy and auto-paste for final text
- SQLite storage for sessions/chunks

## Requirements

- Windows 10 or Windows 11
- Python 3.10+
- Soniox API key

## Quick Start (Tray UI)

```powershell
cd Speech-to-Text
.\windows\run_windows.ps1 -ApiKey "YOUR_SONIOX_API_KEY"
```

If API key is already saved:

```powershell
.\windows\run_windows.ps1
```

This launches the tray app. Open `Settings` from tray to update API key, hotkey, and paste language.

## CLI Mode (Optional)

```powershell
.\windows\run_windows.ps1 -Cli
```

## Manual Setup

```powershell
cd Speech-to-Text
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r .\windows\requirements.txt
.\.venv\Scripts\python.exe .\windows\cli.py --set-api-key "YOUR_SONIOX_API_KEY" --configure-only
.\.venv\Scripts\python.exe .\windows\gui.py
```

## Build App EXE

Build the single-file app executable:

```powershell
cd Speech-to-Text
.\windows\build_windows_exe.ps1 -Clean
```

Output:

`.\dist\SpeechToTextWindows.exe`

## Build Setup Installer (.exe)

This creates a Windows installer wizard (`Setup.exe`) using Inno Setup.

1. Install Inno Setup 6 (once).
2. Build installer:

```powershell
cd Speech-to-Text
.\windows\build_windows_installer.ps1 -Clean -Version "0.3.0"
```

Output:

`.\dist\installer\SpeechToTextWindows-Setup-0.3.0.exe`

## Runtime Controls

- Default hotkey: `Ctrl+Shift+Space`
- First press: start recording
- Second press: stop recording and save session
- Tray menu:
  - Start/Stop Recording
  - Settings
  - Open Data Folder
  - Quit

## Configuration

Config file:

`%APPDATA%\SpeechToTextWindows\config.json`

CLI config commands:

```powershell
.\.venv\Scripts\python.exe .\windows\cli.py --show-config
.\.venv\Scripts\python.exe .\windows\cli.py --hotkey "alt+shift+s" --configure-only
.\.venv\Scripts\python.exe .\windows\cli.py --paste-language en --configure-only
```

## Data Location

SQLite database:

`%APPDATA%\SpeechToTextWindows\transcriptions.db`

## Known Gaps

- No dashboard/history desktop window yet
- No waveform/floating text window yet
- Hotkey behavior depends on Windows privilege level and focused application
