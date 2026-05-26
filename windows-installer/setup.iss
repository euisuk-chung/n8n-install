; n8n Windows Installer
; Built with Inno Setup 6
;
; Build:
;   ISCC.exe setup.iss /DAppVersion=1.0.0
;
; Required preconditions:
;   - vendor/node/  : extracted portable Node.js LTS for win-x64
;   - tray-app/bin/Release/N8nTray.exe
;   - bootstrap/*.ps1

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif

#define AppName "n8n"
#define AppPublisher "n8n GmbH"
#define AppURL "https://n8n.io"
#define AppExeName "N8nTray.exe"

[Setup]
AppId={{8A4F2E7B-3D6C-4A1F-B9E2-N8NWIN0001}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL=https://community.n8n.io
AppUpdatesURL={#AppURL}

DefaultDirName={userpf}\n8n
DefaultGroupName=n8n
DisableProgramGroupPage=yes

; Install per-user, no admin needed
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

OutputDir=build
OutputBaseFilename=n8n-installer-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible

; Optional branding assets — comment out if files don't exist
;SetupIconFile=assets\icon.ico
;WizardImageFile=assets\banner.bmp
;UninstallDisplayIcon={app}\icon.ico

LicenseFile=assets\license-ko.txt

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
korean.AutoStartTask=Windows 시작 시 자동 실행
korean.DesktopIconTask=바탕화면 바로가기 만들기
korean.LaunchAfterInstall=설치 완료 후 n8n 시작
korean.PreserveUserData=사용자 데이터 (워크플로, 자격증명) 보존
korean.DeleteUserData=사용자 데이터(%USERPROFILE%\.n8n)도 함께 삭제
korean.UninstallConfirmRemoveData=n8n 사용자 데이터(워크플로 포함)도 모두 삭제할까요? 복구할 수 없습니다.
english.AutoStartTask=Start n8n automatically at Windows startup
english.DesktopIconTask=Create desktop shortcut
english.LaunchAfterInstall=Launch n8n after install
english.PreserveUserData=Preserve user data (workflows, credentials)
english.DeleteUserData=Also delete user data at %USERPROFILE%\.n8n
english.UninstallConfirmRemoveData=Delete n8n user data (including workflows)? This cannot be undone.

[Tasks]
Name: "autostart"; Description: "{cm:AutoStartTask}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "desktopicon"; Description: "{cm:DesktopIconTask}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Portable Node.js — produced by scripts/download-nodejs.ps1
Source: "vendor\node\*"; DestDir: "{app}\node"; Flags: ignoreversion recursesubdirs createallsubdirs

; Tray launcher
Source: "tray-app\bin\Release\N8nTray.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "tray-app\bin\Release\N8nTray.exe.config"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; Bootstrap scripts
Source: "bootstrap\*.ps1"; DestDir: "{app}\bootstrap"; Flags: ignoreversion

; Branding — kept optional
Source: "assets\icon.ico"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\n8n"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\icon.ico"
Name: "{group}\n8n 데이터 폴더 열기"; Filename: "{cmd}"; Parameters: "/c explorer %USERPROFILE%\.n8n"
Name: "{group}\n8n 제거"; Filename: "{uninstallexe}"
Name: "{userdesktop}\n8n"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\icon.ico"; Tasks: desktopicon

[Registry]
; Auto-start at logon (per-user)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "n8n"; ValueData: """{app}\{#AppExeName}"" --silent"; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchAfterInstall}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Ensure n8n process is stopped before removal
Filename: "{cmd}"; Parameters: "/c taskkill /f /im node.exe /fi ""WINDOWTITLE eq n8n*"""; Flags: runhidden; RunOnceId: "KillN8nNode"
Filename: "{cmd}"; Parameters: "/c taskkill /f /im N8nTray.exe"; Flags: runhidden; RunOnceId: "KillN8nTray"

[UninstallDelete]
; Remove the npm-installed n8n payload (downloaded on first run, not part of installer)
Type: filesandordirs; Name: "{app}\n8n-data"
Type: filesandordirs; Name: "{app}\node"
Type: filesandordirs; Name: "{app}\bootstrap"

[Code]
var
  DeleteUserDataPage: TInputOptionWizardPage;

procedure InitializeUninstallProgressForm();
begin
  // no-op; uninstall confirmation handled in CurUninstallStepChanged
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  UserDataPath: String;
  Response: Integer;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    UserDataPath := ExpandConstant('{%USERPROFILE}\.n8n');
    if DirExists(UserDataPath) then
    begin
      Response := MsgBox(ExpandConstant('{cm:UninstallConfirmRemoveData}'),
                        mbConfirmation, MB_YESNO or MB_DEFBUTTON2);
      if Response = IDYES then
        DelTree(UserDataPath, True, True, True);
    end;
  end;
end;
