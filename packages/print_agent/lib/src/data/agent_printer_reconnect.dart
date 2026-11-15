import 'dart:async';
import 'dart:io';

import 'package:print_agent_core/print_agent_core.dart';

import '../domain/entities/agent_printer_ref.dart';
import '../domain/entities/agent_printer_status.dart';
import '../domain/ports/agent_printer_gateway.dart';
import 'agent_printer_watchdog.dart';

/// Các bước "Kết nối lại" (màn hình hiện tiến trình).
enum ReconnectStep {
  /// LAN: xem máy này có cùng mạng với máy in không.
  checkNetwork,

  /// LAN: thử kết nối IP đã lưu (vài lần — máy in có thể đang khởi động lại).
  tryIp,

  /// LAN: tìm máy in theo MAC (máy in bật lại nhận IP mới).
  searchMac,

  /// Tích hợp: khởi động lại kết nối máy in tích hợp.
  restartBuiltIn,

  /// USB: kiểm tra cáp + quyền USB rồi kết nối.
  checkUsb,
}

/// Kết quả "Kết nối lại".
enum ReconnectOutcome {
  /// Đã kết nối lại.
  connected,

  /// Máy in đổi IP — đã tìm thấy theo MAC và cập nhật.
  relocated,

  /// Máy in LAN ở mạng khác: cần chuyển máy này sang Wi-Fi của máy in.
  otherNetwork,

  /// Không thấy máy in (tắt nguồn / rút cáp mạng / chưa có MAC để tìm).
  notFound,

  /// Máy in đang bận / giữ kết nối khác (cổng từ chối).
  busy,

  /// USB: không thấy máy in cắm vào máy này.
  usbUnplugged,

  /// Tích hợp: không kết nối lại được.
  builtInFailed,
}

/// Kết quả kèm thông tin để màn hình gợi ý bước tiếp theo.
class ReconnectResult<P extends AgentPrinterRef> {
  const ReconnectResult(this.outcome, {this.printer, this.oldIp, this.ssid});

  final ReconnectOutcome outcome;

  /// Máy in sau khi kết nối lại (có thể đã đổi IP).
  final P? printer;
  final String? oldIp;

  /// [ReconnectOutcome.otherNetwork]: Wi-Fi của máy in (nếu đã nhớ).
  final String? ssid;

  bool get ok =>
      outcome == ReconnectOutcome.connected ||
      outcome == ReconnectOutcome.relocated;
}

/// "Kết nối lại" một máy in của máy Agent một cách thông minh: thử từ nhanh tới
/// chậm, không làm bước chắc chắn vô ích (VD khác mạng thì không thử IP 10 giây),
/// cập nhật trạng thái trên sơ đồ ([AgentPrinterWatchdog]) theo kết quả.
/// Một đối tượng cho mỗi app chủ (dùng chung watchdog với sơ đồ).
class AgentPrinterReconnect<P extends AgentPrinterRef> {
  AgentPrinterReconnect(this._gateway, this._watchdog);

  final AgentPrinterGateway<P> _gateway;
  final AgentPrinterWatchdog<P> _watchdog;
  final Set<String> _running = {};

  Future<ReconnectResult<P>> run(
    P printer, {
    void Function(ReconnectStep step)? onStep,
  }) async {
    final key =
        '${printer.refId}|${printer.refAddress}|${printer.refKind?.name}';
    if (!_running.add(key)) {
      return ReconnectResult<P>(ReconnectOutcome.busy);
    }
    final watchdog = _watchdog;
    try {
      // Sang nhịp sau rồi mới đổi trạng thái: nơi gọi có thể đang ở giữa lúc
      // dựng giao diện (VD initState) — đổi Rx lúc đó làm Obx báo lỗi.
      await Future<void>(() {});
      watchdog.report(printer, AgentPrinterState.checking);
      final result = await switch (printer.refKind) {
        AgentPrinterKind.builtIn => _builtIn(onStep),
        AgentPrinterKind.usb => _usb(printer, onStep),
        _ => _lan(printer, onStep),
      };
      final state = switch (result.outcome) {
        ReconnectOutcome.connected ||
        ReconnectOutcome.relocated => AgentPrinterState.connected,
        ReconnectOutcome.otherNetwork => AgentPrinterState.otherNetwork,
        _ => AgentPrinterState.disconnected,
      };
      watchdog.report(
        result.printer ?? printer,
        state,
        note: result.outcome == ReconnectOutcome.relocated
            ? '${result.oldIp} → ${result.printer?.refAddress}'
            : null,
        replaced: result.outcome == ReconnectOutcome.relocated ? printer : null,
      );
      return result;
    } finally {
      _running.remove(key);
    }
  }

  Future<ReconnectResult<P>> _lan(
    P printer,
    void Function(ReconnectStep)? onStep,
  ) async {
    final ip = printer.refAddress?.trim() ?? '';
    onStep?.call(ReconnectStep.checkNetwork);
    // Khác dải mạng: thử IP hay tìm MAC đều vô ích (quét mạng chỉ thấy mạng hiện
    // tại) — gợi ý chuyển Wi-Fi ngay.
    if (ip.isNotEmpty && !await PrintRelayClient.isOnSameSubnet(ip)) {
      return ReconnectResult(
        ReconnectOutcome.otherNetwork,
        printer: printer,
        ssid: _gateway.wifiSsidOf(printer),
      );
    }
    onStep?.call(ReconnectStep.tryIp);
    var refused = false;
    // 3 lần cách 1,5s: máy in vừa bật cần vài giây mới mở cổng in.
    for (var i = 0; i < 3 && ip.isNotEmpty; i++) {
      final r = await _probe(ip);
      if (r == _Probe.open) {
        return ReconnectResult(ReconnectOutcome.connected, printer: printer);
      }
      refused = refused || r == _Probe.refused;
      if (i < 2) await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
    // Cổng từ chối = máy ở IP đó đang bật nhưng không nhận kết nối: máy in bận
    // (máy khác giữ kết nối) — hoặc IP đã thuộc thiết bị khác. Vẫn tìm theo MAC.
    onStep?.call(ReconnectStep.searchMac);
    final moved = await _gateway.relocate(
      printer,
      timeout: const Duration(seconds: 15),
    );
    final movedIp = moved?.refAddress?.trim() ?? '';
    if (moved != null &&
        movedIp.isNotEmpty &&
        await AgentPrinterWatchdog.tcpOpen(movedIp)) {
      return ReconnectResult(
        ReconnectOutcome.relocated,
        printer: moved,
        oldIp: ip,
      );
    }
    return ReconnectResult(
      refused ? ReconnectOutcome.busy : ReconnectOutcome.notFound,
      printer: printer,
    );
  }

  Future<ReconnectResult<P>> _builtIn(
    void Function(ReconnectStep)? onStep,
  ) async {
    onStep?.call(ReconnectStep.restartBuiltIn);
    await _gateway.reconnectBuiltIn();
    if (!_gateway.builtInConnected) {
      // Dịch vụ máy in của hãng vừa khởi động lại có khi cần thêm một nhịp.
      await Future<void>.delayed(const Duration(seconds: 2));
      await _gateway.reconnectBuiltIn();
    }
    return ReconnectResult(
      _gateway.builtInConnected
          ? ReconnectOutcome.connected
          : ReconnectOutcome.builtInFailed,
      printer: _gateway.builtInPrinter(),
    );
  }

  Future<ReconnectResult<P>> _usb(
    P printer,
    void Function(ReconnectStep)? onStep,
  ) async {
    onStep?.call(ReconnectStep.checkUsb);
    if (!await _gateway.isUsbAttached(printer)) {
      return ReconnectResult(ReconnectOutcome.usbUnplugged, printer: printer);
    }
    final ok = await _gateway.connectUsb(printer);
    return ReconnectResult(
      ok ? ReconnectOutcome.connected : ReconnectOutcome.notFound,
      printer: printer,
    );
  }

  static Future<_Probe> _probe(String ip) async {
    try {
      final socket = await Socket.connect(
        ip,
        9100,
        timeout: const Duration(milliseconds: 1500),
      );
      socket.destroy();
      return _Probe.open;
    } on SocketException catch (e) {
      // ECONNREFUSED (111 Linux/Android, 61 iOS): có máy ở IP đó, cổng đóng.
      final code = e.osError?.errorCode;
      return code == 111 || code == 61 ? _Probe.refused : _Probe.none;
    } catch (_) {
      return _Probe.none;
    }
  }
}

enum _Probe { open, refused, none }
