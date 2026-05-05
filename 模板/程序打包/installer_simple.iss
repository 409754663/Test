[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName=账号簿
AppVersion=1.0.0
AppPublisher=AccountBook
AppPublisherURL=https://github.com/yourusername/AccountBook
AppSupportURL=https://github.com/yourusername/AccountBook
AppUpdatesURL=https://github.com/yourusername/AccountBook
DefaultDirName={autopf}\AccountBook
DefaultGroupName=账号簿
AllowNoIcons=yes
OutputDir=installer_output
OutputBaseFilename=AccountBook_Setup_1.0.1
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog


[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "AccountBook_Release\AccountBook.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "AccountBook_Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\账号簿"; Filename: "{app}\AccountBook.exe"
Name: "{group}\{cm:UninstallProgram,账号簿}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\账号簿"; Filename: "{app}\AccountBook.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\AccountBook.exe"; Description: "{cm:LaunchProgram,账号簿}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\AccountBook"
