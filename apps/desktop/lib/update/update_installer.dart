import 'dart:io';

/// Cài bộ cài đã tải xong rồi mở lại Agent. Chạy SAU khi Agent thoát (bộ cài thay file đang dùng), nên lệnh
/// cài chạy ở tiến trình riêng, tách khỏi Agent.
abstract interface class UpdateInstaller {
  /// Bắt đầu cài [file]; `true` = đã giao việc cho tiến trình riêng (Agent nên thoát ngay), `false` = không
  /// cài tự động được (khách cài tay).
  Future<bool> install(File file);
}

/// Dựng lệnh cài cho từng hệ điều hành (thuần — kiểm thử được).
abstract final class UpdateCommands {
  /// Windows: tệp `.cmd` chờ Agent thoát, chạy bộ cài ngầm (`/VERYSILENT`, hỏi quyền quản trị một lần qua
  /// UAC) kèm `/RESTART=1` (bộ cài mở lại Agent), rồi tự xoá.
  static String windowsScript(String setupPath) =>
      '@echo off\r\n'
      'timeout /t 2 /nobreak >nul\r\n'
      'start "" /wait "$setupPath" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /RESTART=1\r\n'
      'del "%~f0"\r\n';

  /// Linux: chờ Agent thoát, cài `.deb` bằng quyền quản trị (`pkexec` hỏi mật khẩu bằng hộp thoại hệ
  /// thống), rồi mở lại Agent. Tham số truyền riêng (`$1` = .deb, `$2` = chương trình) nên đường dẫn có
  /// khoảng trắng vẫn đúng.
  static const String linuxScript =
      'sleep 2; pkexec apt-get install -y "\$1" && '
      'nohup "\$2" >/dev/null 2>&1 &';
}

class WindowsUpdateInstaller implements UpdateInstaller {
  @override
  Future<bool> install(File file) async {
    try {
      final script = File('${file.parent.path}\\easypos_update.cmd')
        ..writeAsStringSync(UpdateCommands.windowsScript(file.path));
      await Process.start('cmd.exe', [
        '/c',
        script.path,
      ], mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class LinuxUpdateInstaller implements UpdateInstaller {
  @override
  Future<bool> install(File file) async {
    try {
      // Không có pkexec (máy không có polkit): không cài tự động được — khách cài tay.
      final has = await Process.run('which', ['pkexec']);
      if (has.exitCode != 0) return false;
      await Process.start('sh', [
        '-c',
        UpdateCommands.linuxScript,
        'easypos-update',
        file.path,
        Platform.resolvedExecutable,
      ], mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Bộ cài của hệ điều hành đang chạy; `null` (macOS...) = không tự cài.
UpdateInstaller? platformUpdateInstaller() {
  if (Platform.isWindows) return WindowsUpdateInstaller();
  if (Platform.isLinux) return LinuxUpdateInstaller();
  return null;
}
