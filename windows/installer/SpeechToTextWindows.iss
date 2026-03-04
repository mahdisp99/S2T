#define MyAppName "Speech to Text Windows"
#ifndef MyAppVersion
  #define MyAppVersion "0.3.0"
#endif
#define MyAppPublisher "mahdisp99"
#define MyAppExeName "SpeechToTextWindows.exe"

#ifndef SourceExe
  #error "You must pass /DSourceExe=<absolute-path-to-exe> to ISCC."
#endif

#ifndef OutputDir
  #define OutputDir "..\..\dist\installer"
#endif

[Setup]
AppId={{9A9B135F-3F57-49BC-8A7B-4CF8D0DD8DA3}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\SpeechToTextWindows
DefaultGroupName=Speech to Text Windows
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=SpeechToTextWindows-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "{#SourceExe}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Speech to Text Windows"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\Speech to Text Windows"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Speech to Text Windows"; Flags: nowait postinstall skipifsilent

