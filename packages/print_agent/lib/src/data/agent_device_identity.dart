import '../print_agent_module.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:printer_label/printer_label.dart';

/// Mã Agent theo MÁY (không theo bản app): các bản build trên cùng máy (Dev /
/// prod...) dùng chung một mã → một máy chỉ hiện là MỘT Agent.
///
/// Mã = băm của mã phần cứng ([PrinterLabel.deviceId]: serial trên Android ≤
/// 7.1, ANDROID_ID trên 8+) — không gửi mã gốc đi. Máy không đọc được mã phần
/// cứng (iOS...) giữ mã ngẫu nhiên như trước. Mã cũ (ngẫu nhiên) được nhớ lại
/// ([previousIds]) và báo kèm thông tin trạm để máy khác gộp Agent cũ vào mã mới.
abstract final class AgentDeviceIdentity {
  static const String _prevStorageKey = 'print_station_prev_ids';
  static const int _maxPrev = 5;

  /// Đổi mã đang lưu ở [storageKey] sang mã theo máy (nếu khác) — gọi TRƯỚC khi
  /// tạo trạm (mã trạm cố định từ lúc tạo).
  static Future<void> adopt(String storageKey) async {
    if (!Platform.isAndroid) return;
    String? raw;
    try {
      raw = await PrinterLabel.deviceId().timeout(const Duration(seconds: 2));
    } catch (_) {}
    if (raw == null || raw.isEmpty) return;
    final id = sha256
        .convert(utf8.encode('easypos-agent:$raw'))
        .toString()
        .substring(0, 16);
    final current =
        PrintAgentModule.host.storage.get(storageKey)?.toString() ?? '';
    if (current == id) return;
    if (current.isNotEmpty) {
      final prev = [
        current,
        ...previousIds.where((e) => e != current && e != id),
      ].take(_maxPrev).toList();
      await PrintAgentModule.host.storage.put(_prevStorageKey, prev);
    }
    await PrintAgentModule.host.storage.put(storageKey, id);
    PrintAgentModule.host.log(
      '[AGENT] Mã Agent theo máy: $id (thay mã cũ "$current")',
    );
  }

  /// Các mã Agent cũ của máy này (trước khi dùng mã theo máy).
  static List<String> get previousIds {
    final raw = PrintAgentModule.host.storage.get(_prevStorageKey);
    return [
      if (raw is List)
        for (final e in raw)
          if (e is String && e.isNotEmpty) e,
    ];
  }

  /// Mã cũ mà các Agent trực tuyến báo đã thay ([stations] mỗi trạm `prev`).
  static Set<String> replacedIds(Iterable<Map<Object?, Object?>> stations) => {
    for (final s in stations)
      if (s['prev'] is List)
        for (final e in s['prev'] as List)
          if (e is String && e.isNotEmpty) e,
  };
}

/// Một máy chỉ một bản app được làm Agent cùng lúc: các bản cùng máy dùng chung
/// mã Agent ([AgentDeviceIdentity]) nên nếu 2 bản cùng bật, lệnh nhắm thẳng
/// Agent sẽ bị in 2 lần. Khoá bằng một cổng localhost cố định — bản giữ cổng là
/// Agent; app bị tắt thì hệ thống tự nhả cổng.
abstract final class AgentDeviceLock {
  static const int _port = 47391;
  static ServerSocket? _socket;

  static String get _me => PrintAgentModule.host.appPackage;

  /// Giữ khoá. Bản app khác trên máy đang giữ → trả tên gói của bản đó (không
  /// giữ được); giữ được → `null`.
  static Future<String?> acquire() async {
    if (!Platform.isAndroid || _socket != null) return null;
    try {
      final socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        _port,
      );
      socket.listen((client) {
        // Ai hỏi thì trả tên gói app đang làm Agent.
        client.write('$_me\n');
        unawaited(client.flush().whenComplete(client.destroy));
      });
      _socket = socket;
      return null;
    } on SocketException {
      final owner = await _owner();
      // Chính app này (VD cổng còn giữ từ lần chạy trước trong cùng tiến trình)
      // hoặc không hỏi được: không chặn.
      if (owner == null || owner == _me) return null;
      return owner;
    }
  }

  static Future<void> release() async {
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }

  /// Hỏi bản đang giữ khoá là app nào.
  static Future<String?> _owner() async {
    Socket? s;
    try {
      s = await Socket.connect(
        InternetAddress.loopbackIPv4,
        _port,
        timeout: const Duration(milliseconds: 500),
      );
      final line = await s
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(milliseconds: 500));
      return line.trim().isEmpty ? null : line.trim();
    } catch (_) {
      return null;
    } finally {
      s?.destroy();
    }
  }
}
