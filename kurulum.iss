; SaLda kurulum betiği (Inno Setup 6). kurulum_olustur.bat tarafından derlenir.
#define AppName "SaLda"
#define AppVersion "2.0.0"

[Setup]
AppId={{6B1E2C4A-5D3F-4A8E-9C21-7F0D5A3B9E10}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Ramazan Karataş
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=build
OutputBaseFilename=SaLda_Kurulum_{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\SaLda.exe

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "build\oyun\SaLda.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "OYNA.md"; DestDir: "{app}"; DestName: "OYNA.txt"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\SaLda.exe"
Name: "{group}\Nasıl Oynanır"; Filename: "{app}\OYNA.txt"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\SaLda.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\SaLda.exe"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
