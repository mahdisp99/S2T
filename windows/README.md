# Speech to Text (Windows Preview)

This folder contains the first Windows-focused implementation of the project.

Current scope:
- Real-time microphone capture on Windows
- Streaming to Soniox via WebSocket
- Persian transcript + English translation handling
- Global hotkey to start/stop recording
- Auto-copy + auto-paste for final text
- SQLite session and chunk storage

This is an MVP for Windows and does not yet have feature parity with the macOS UI.

## Requirements

- Windows 10 or Windows 11
- Python 3.10+
- Soniox API key

## Quick Start (PowerShell)

```powershell
cd Speech-to-Text
.\windows\run_windows.ps1 -ApiKey "YOUR_SONIOX_API_KEY"
```

If you already saved the API key once:

```powershell
.\windows\run_windows.ps1
```

## Manual Setup

```powershell
cd Speech-to-Text
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r .\windows\requirements.txt
.\.venv\Scripts\python.exe .\windows\cli.py --set-api-key "YOUR_SONIOX_API_KEY" --configure-only
.\.venv\Scripts\python.exe .\windows\cli.py
```

## Runtime Controls

- Default hotkey: `Ctrl+Shift+Space`
- First press: start recording
- Second press: stop recording and save session
- Exit app: `Ctrl+C` in terminal

## Configuration

Config is saved at:

`%APPDATA%\SpeechToTextWindows\config.json`

Commands:

```powershell
.\.venv\Scripts\python.exe .\windows\cli.py --show-config
.\.venv\Scripts\python.exe .\windows\cli.py --hotkey "alt+shift+s" --configure-only
.\.venv\Scripts\python.exe .\windows\cli.py --paste-language en --configure-only
```

## Data Location

SQLite database:

`%APPDATA%\SpeechToTextWindows\transcriptions.db`

## Known Gaps (Planned)

- No desktop UI yet (currently terminal-driven)
- No waveform/floating window yet
- No history/dashboard UI yet
- Hotkey behavior depends on user privileges and foreground app rules on Windows
