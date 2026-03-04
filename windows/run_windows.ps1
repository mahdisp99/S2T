param(
    [string]$ApiKey = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$venvPython = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    py -m venv .venv
}

& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install -r .\windows\requirements.txt

if ($ApiKey -ne "") {
    & $venvPython .\windows\cli.py --set-api-key $ApiKey --configure-only
}

& $venvPython .\windows\cli.py

