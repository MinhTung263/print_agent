; Bộ cài Windows cho "Agent" (Inno Setup 6.3+).
;
; File phải giữ mã UTF-8 có BOM (Inno đọc tiếng Việt đúng nhờ BOM).
;
; Build (chạy trong apps/desktop, sau `flutter build windows --release`):
;   ISCC.exe /DMyAppVersion=0.1.0 /DMyAppBuild=1 installer\windows\easypos_print_agent.iss
; Tham số /D tuỳ chọn:
;   MyAppVersion  phiên bản x.y.z (phần trước dấu + của `version:` trong pubspec.yaml)
;   MyAppBuild    số build (phần sau dấu +), mặc định 0
;   BundleDir     thư mục bản build Release (mặc định build\windows\x64\runner\Release)
;   OutputDir     nơi ghi file Setup (mặc định build\installer)
; Đường dẫn tương đối tính từ thư mục chứa file .iss này.
;
; Tự chạy khi bật máy: KHÔNG tạo ở đây — app tự quản (launch_at_startup, khoá
; HKCU\...\Run tên "EasyPOS Print Agent"). Bộ cài chỉ xoá khoá đó khi gỡ.

#ifndef MyAppVersion
#define MyAppVersion "0.0.0"
#endif
#ifndef MyAppBuild
#define MyAppBuild "0"
#endif
#ifndef BundleDir
#define BundleDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
#define OutputDir "..\..\build\installer"
#endif

#define MyAppName "Agent"
#define MyAppExeName "easypos_print_agent.exe"
#define MyAppPublisher "EasyPOS"
; Tên rule tường lửa (không dấu cho netsh dễ xử lý).
#define FirewallRule "Tram in EasyPOS (TCP 9101)"
#define LanPort "9101"
; Phải khớp appName trong lib/desktop/autostart.dart.
#define AutostartName "EasyPOS Print Agent"

; Bản dịch tiếng Việt: chỉ dùng nếu bản Inno cài trên máy có sẵn (không tải ngoài).
#define ViIsl ""
#if FileExists(AddBackslash(CompilerPath) + "Languages\Vietnamese.isl")
#define ViIsl "compiler:Languages\Vietnamese.isl"
#elif FileExists(AddBackslash(CompilerPath) + "Languages\Unofficial\Vietnamese.isl")
#define ViIsl "compiler:Languages\Unofficial\Vietnamese.isl"
#endif

[Setup]
; AppId cố định — đổi là Windows coi như app khác (cài đè không được).
AppId={{21F79CC9-B4BB-4EDC-A13A-C4D62A4A844C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
VersionInfoVersion={#MyAppVersion}.{#MyAppBuild}
VersionInfoProductName={#MyAppName}
VersionInfoDescription={#MyAppName} - Setup
DefaultDirName={autopf}\EasyPOS\Tram in EasyPOS
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=TramInEasyPOS-Setup-{#MyAppVersion}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Đóng app qua Restart Manager nếu còn file bị giữ (taskkill ở [Code] chạy trước).
CloseApplications=yes
RestartApplications=no
LanguageDetectionMethod=none
ShowLanguageDialog=no
SetupLogging=yes

[Languages]
; Ngôn ngữ đầu tiên là mặc định (LanguageDetectionMethod=none).
#if ViIsl != ""
Name: "vietnamese"; MessagesFile: "{#ViIsl}"
#endif
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
english.FirewallStatus=Opening Windows Firewall port {#LanPort} for {#MyAppName}...
#if ViIsl != ""
vietnamese.FirewallStatus=Đang mở cổng {#LanPort} trên tường lửa Windows cho {#MyAppName}...
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[InstallDelete]
; Cài đè: xoá tài nguyên Flutter cũ để không lẫn file của bản trước.
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
; Tường lửa: nhận phiếu in qua LAN TCP {#LanPort}, chỉ cho đúng file exe.
; Xoá rule cũ trước (cài đè / đổi thư mục) rồi thêm lại.
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#FirewallRule}"""; Flags: runhidden waituntilterminated; StatusMsg: "{cm:FirewallStatus}"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#FirewallRule}"" dir=in action=allow protocol=TCP localport={#LanPort} program=""{app}\{#MyAppExeName}"" profile=any enable=yes"; Flags: runhidden waituntilterminated; StatusMsg: "{cm:FirewallStatus}"
; Tuỳ chọn mở app ngay sau khi cài (chạy bằng tài khoản người dùng, không phải admin).
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/F /T /IM {#MyAppExeName}"; Flags: runhidden waituntilterminated; RunOnceId: "KillApp"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#FirewallRule}"""; Flags: runhidden waituntilterminated; RunOnceId: "DeleteFirewallRule"

[Code]
procedure KillRunningApp();
var
  ResultCode: Integer;
begin
  // App ẩn dưới khay (đóng cửa sổ không thoát) nên phải kill hẳn tiến trình.
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /T /IM {#MyAppExeName}', '',
    SW_HIDE, ewWaitUntilTerminated, ResultCode);
  // taskkill trả 128 khi không có tiến trình nào — bỏ qua.
  if ResultCode = 0 then
    Sleep(1000);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  KillRunningApp();
  Result := '';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // Bỏ mục tự chạy app đã tạo cho người dùng hiện tại (không để lối tắt chết).
    RegDeleteValue(HKEY_CURRENT_USER,
      'Software\Microsoft\Windows\CurrentVersion\Run', '{#AutostartName}');
    RegDeleteValue(HKEY_CURRENT_USER,
      'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
      '{#AutostartName}');
  end;
end;
