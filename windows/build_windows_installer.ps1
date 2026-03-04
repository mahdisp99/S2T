param(
    [switch]$Clean,
    [switch]$SkipExeBuild,
    [string]$Version = "0.3.0"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$exePath = Join-Path $repoRoot "dist\\SpeechToTextWindows.exe"
$outputDir = Join-Path $repoRoot "dist\\installer"

if (-not $SkipExeBuild) {
    Write-Host "Building application executable first..."
    & powershell -ExecutionPolicy Bypass -File ".\\windows\\build_windows_exe.ps1" -Clean:$Clean
}

if (-not (Test-Path $exePath)) {
    throw "App executable not found at '$exePath'. Build EXE first or pass correct path in script."
}

if ($Clean -and (Test-Path $outputDir)) {
    Remove-Item -Recurse -Force $outputDir
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

function Resolve-InnoCompiler {
    $cmd = Get-Command iscc.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $candidatePaths = @(
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\\ISCC.exe"),
        (Join-Path ${env:ProgramFiles} "Inno Setup 6\\ISCC.exe")
    )

    foreach ($candidate in $candidatePaths) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    return $null
}

$iscc = Resolve-InnoCompiler
if (-not $iscc) {
    throw "Inno Setup compiler (ISCC.exe) not found. Install Inno Setup 6, then run this script again."
}

$issPath = Join-Path $repoRoot "windows\\installer\\SpeechToTextWindows.iss"
if (-not (Test-Path $issPath)) {
    throw "Installer script not found: $issPath"
}

Write-Host "Compiling installer with ISCC..."
& $iscc $issPath "/DMyAppVersion=$Version" "/DSourceExe=$exePath" "/DOutputDir=$outputDir"

Write-Host ""
Write-Host "Installer build complete."
Write-Host "Output folder: $outputDir"

