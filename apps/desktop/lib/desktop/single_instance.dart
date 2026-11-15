import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Một máy chỉ MỘT Agent: hai bản cùng chạy sẽ dùng chung mã Agent, tắt ở bản
/// này mà bản kia vẫn báo trực tuyến.
///
/// Bản đầu tiên giữ khoá file `agent.lock` và mở một cổng nội bộ (127.0.0.1,
/// số cổng ghi ở `agent.port`). Mở thêm lần nữa (bấm biểu tượng, shortcut...)
/// thì bản mới báo bản đang chạy hiện cửa sổ rồi tự thoát — giống app thường.
class SingleInstance {
  SingleInstance._(this._lock, this._server);

  final RandomAccessFile? _lock;
  final ServerSocket _server;
  final _showRequests = StreamController<void>.broadcast();

  /// Một bản khác vừa được mở — nên hiện cửa sổ của bản này.
  Stream<void> get showRequests => _showRequests.stream;

  static const _showCommand = 'show';

  /// Giữ khoá thành công → [SingleInstance]. Đã có bản khác chạy → báo bản đó
  /// hiện cửa sổ rồi trả `null` (bên gọi thoát). [dir] là thư mục cấu hình.
  static Future<SingleInstance?> acquire(Directory dir) async {
    dir.createSync(recursive: true);
    final sep = Platform.pathSeparator;
    final portFile = File('${dir.path}${sep}agent.port');
    final RandomAccessFile lock;
    try {
      lock = File('${dir.path}${sep}agent.lock').openSync(mode: FileMode.write);
    } catch (_) {
      // Không tạo được file khoá (quyền ghi...): coi như bản duy nhất.
      return _start(null, portFile);
    }
    try {
      lock.lockSync(FileLock.exclusive);
    } catch (_) {
      lock.closeSync();
      await _askRunningToShow(portFile);
      return null;
    }
    return _start(lock, portFile);
  }

  static Future<SingleInstance?> _start(
    RandomAccessFile? lock,
    File portFile,
  ) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    try {
      portFile.writeAsStringSync('${server.port}');
    } catch (_) {}
    final instance = SingleInstance._(lock, server);
    server.listen((client) {
      client
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .then((line) {
            if (line.trim() == _showCommand) instance._showRequests.add(null);
          }, onError: (Object _) {})
          .whenComplete(client.destroy);
    });
    return instance;
  }

  static Future<void> _askRunningToShow(File portFile) async {
    try {
      final port = int.parse(portFile.readAsStringSync().trim());
      final s = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(seconds: 2),
      );
      s.writeln(_showCommand);
      await s.flush();
      await s.close();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _server.close();
    await _showRequests.close();
    try {
      _lock?.closeSync();
    } catch (_) {}
  }
}
