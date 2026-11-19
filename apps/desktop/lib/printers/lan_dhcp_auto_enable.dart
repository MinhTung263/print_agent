import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:printer_label/printer_label.dart';

/// Kết quả [LanDhcpAutoEnable.ensure].
///
/// (Bản cho Agent máy tính — cùng logic với bản trong app EasyPOS; hai app không dùng chung gói nên
/// mỗi bên giữ một bản nhỏ trên cùng các hàm của `printer_label`.)
class LanDhcpOutcome {
  const LanDhcpOutcome({
    required this.ip,
    this.enabled = false,
    this.failed = false,
  });

  /// IP máy in sau khi xử lý (có thể khác IP ban đầu vì router cấp IP mới).
  final String ip;

  /// Vừa bật DHCP cho máy in.
  final bool enabled;

  /// Máy đang IP tĩnh nhưng không bật được DHCP.
  final bool failed;
}

/// Tự bật DHCP cho máy in LAN đang dùng IP TĨNH (tắt DHCP) khi app thấy máy đó.
///
/// IP tĩnh đặt trên máy in mà router không biết: router có thể cấp đúng IP đó cho thiết bị khác
/// (trùng IP — in nhầm hoặc không in được), và máy in đổi mạng là hỏng IP đã lưu. Bật DHCP để máy
/// luôn có IP hợp lệ; app tìm lại máy theo MAC nên IP có đổi cũng không mất máy.
///
/// Việc bật làm máy in khởi động lại mạng vài giây nên KHÔNG chạy trong lúc quét: chỉ khi người dùng
/// bấm loa hoặc chọn máy ở bước kết nối. Mỗi máy chỉ thử một lần mỗi [retryAfter].
class LanDhcpAutoEnable {
  LanDhcpAutoEnable({
    Future<LanPrinterNetInfo?> Function(String ip)? readInfo,
    Future<bool> Function(String ip, LanPrinterNetInfo info)? enable,
    Future<String?> Function(String mac, String lastIp)? findIp,
    DateTime Function()? now,
    this.retryAfter = const Duration(minutes: 10),
    this.waitForPrinter = const Duration(seconds: 20),
  }) : _readInfo = readInfo ?? _defaultReadInfo,
       _enable = enable ?? _defaultEnable,
       _findIp = findIp ?? _defaultFindIp,
       _now = now ?? DateTime.now;

  static final LanDhcpAutoEnable instance = LanDhcpAutoEnable();

  final Duration retryAfter;
  final Duration waitForPrinter;
  final Future<LanPrinterNetInfo?> Function(String) _readInfo;
  final Future<bool> Function(String, LanPrinterNetInfo) _enable;
  final Future<String?> Function(String, String) _findIp;
  final DateTime Function() _now;

  final Map<String, DateTime> _tried = {};
  final Map<String, Future<LanDhcpOutcome>> _running = {};

  /// Máy ở [ip] đang IP tĩnh thì bật DHCP rồi tìm lại IP mới theo MAC. Máy đã DHCP / không đọc được
  /// cấu hình: trả [ip] nguyên vẹn, không làm gì. Gọi đồng thời cho cùng một máy dùng chung một lần chạy.
  Future<LanDhcpOutcome> ensure(
    String ip,
  ) => _running[ip] ??= _run(ip).whenComplete(() {
    // Không `=> _running.remove(ip)`: nó trả chính Future này → whenComplete chờ chính nó (treo).
    _running.remove(ip);
  });

  Future<LanDhcpOutcome> _run(String ip) async {
    final last = _tried[ip];
    if (last != null && _now().difference(last) < retryAfter) {
      return LanDhcpOutcome(ip: ip);
    }
    final info = await _readInfo(ip);
    if (info == null || info.dhcp) return LanDhcpOutcome(ip: ip);

    _tried[ip] = _now();
    debugPrint('[DHCP-AUTO] $ip (${info.mac}) đang IP tĩnh — bật DHCP');
    var ok = false;
    try {
      ok = await _enable(ip, info);
    } catch (e) {
      debugPrint('[DHCP-AUTO] Bật DHCP $ip lỗi: $e');
    }
    if (!ok) return LanDhcpOutcome(ip: ip, failed: true);

    // Máy khởi động lại mạng rồi xin IP: tìm theo MAC (có thể vẫn là IP cũ nếu router cấp lại đúng IP).
    final deadline = _now().add(waitForPrinter);
    String? found;
    while (_now().isBefore(deadline)) {
      found = await _findIp(info.mac, ip);
      if (found != null) break;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    final now = found ?? ip;
    debugPrint('[DHCP-AUTO] ${info.mac}: $ip -> $now');
    _tried[now] = _now();
    return LanDhcpOutcome(ip: now, enabled: true);
  }

  // ── Mặc định (máy in thật) ────────────────────────────────────────────────
  static Future<LanPrinterNetInfo?> _defaultReadInfo(String ip) async =>
      await PrinterLabel.queryHttpNetInfo(ip) ??
      await PrinterLabel.queryXpUdpInfo(ip);

  static Future<bool> _defaultEnable(String ip, LanPrinterNetInfo info) async {
    // Máy có trang cấu hình web (HPRT...): bật qua trang đó. Máy khác (Xprinter...): lệnh UDP theo MAC.
    if (await PrinterLabel.queryHttpNetInfo(ip) != null) {
      return PrinterLabel.enableLanDhcpViaWeb(ip);
    }
    final r = await PrinterLabel.changeLanPrinterIp(
      currentIp: ip,
      mac: info.mac,
      dhcp: true,
    );
    return r.status == LanIpChangeStatus.success ||
        r.status == LanIpChangeStatus.unverified;
  }

  static Future<String?> _defaultFindIp(String mac, String lastIp) =>
      PrinterLabel.findLanPrinterIpByMac(mac, lastIp: lastIp);
}
