param(
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$venvPython = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    py -m venv .venv
}

& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install -r .\windows\requirements-build.txt

if ($Clean) {
    if (Test-Path ".\build") { Remove-Item ".\build" -Recurse -Force }
    if (Test-Path ".\dist") { Remove-Item ".\dist" -Recurse -Force }
}

& $venvPython -m PyInstaller `
    --noconfirm `
    --clean `
    --name "SpeechToTextWindows" `
    --onefile `
    --windowed `
    --paths ".\windows" `
    --hidden-import "tkinter" `
    --hidden-import "keyboard" `
    --hidden-import "sounddevice" `
    --hidden-import "numpy" `
    --hidden-import "pyperclip" `
    --hidden-import "websocket" `
    --hidden-import "pystray" `
    --hidden-import "PIL" `
    ".\windows\gui.py"

Write-Host ""
Write-Host "Build complete."
Write-Host "Executable: .\dist\SpeechToTextWindows.exe"

