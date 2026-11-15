import 'dart:async';

import '../domain/entities/agent_printer_ref.dart';
import '../domain/ports/agent_printer_gateway.dart';
import '../print_agent_module.dart';

/// Bọc cổng máy in của app chủ: MỌI lời gọi xuống máy in / plugin native có
/// giới hạn thời gian — một driver treo (USB, máy in tích hợp, quét MAC) không
/// bao giờ khoá chết hàng đợi in hay bộ canh máy in.
class TimedPrinterGateway<P extends AgentPrinterRef>
    implements AgentPrinterGateway<P> {
  TimedPrinterGateway(this._inner);

  final AgentPrinterGateway<P> _inner;

  static const Duration quick = Duration(seconds: 8);
  static const Duration slow = Duration(seconds: 25);

  static Future<T> _guard<T>(
    String what,
    Future<T> Function() call,
    Duration limit,
    T fallback,
  ) async {
    try {
      return await call().timeout(limit);
    } on TimeoutException {
      PrintAgentModule.host.log(
        '[AGENT] $what quá ${limit.inSeconds}s — bỏ qua',
      );
      return fallback;
    } catch (e) {
      PrintAgentModule.host.log('[AGENT] $what lỗi: $e');
      return fallback;
    }
  }

  @override
  List<P> get printers => _inner.printers;

  @override
  bool get hasBuiltIn => _inner.hasBuiltIn;

  @override
  bool get builtInConnected => _inner.builtInConnected;

  @override
  Stream<bool> get builtInChanges => _inner.builtInChanges;

  @override
  Stream<void> get networkChanges => _inner.networkChanges;

  @override
  Stream<void> get printersChanged => _inner.printersChanged;

  @override
  P builtInPrinter() => _inner.builtInPrinter();

  @override
  String? wifiSsidOf(P printer) => _inner.wifiSsidOf(printer);

  @override
  Future<void> reconnectBuiltIn() =>
      _guard('Nối lại máy in tích hợp', _inner.reconnectBuiltIn, slow, null);

  @override
  Future<bool> isUsbAttached(P printer) => _guard(
    'Kiểm tra USB ${printer.refName}',
    () => _inner.isUsbAttached(printer),
    quick,
    false,
  );

  @override
  Future<bool> connectUsb(P printer) => _guard(
    'Kết nối USB ${printer.refName}',
    () => _inner.connectUsb(printer),
    slow,
    false,
  );

  @override
  Future<bool> isReady(P printer) => _guard(
    'Kiểm tra ${printer.refName}',
    () => _inner.isReady(printer),
    quick,
    false,
  );

  @override
  Future<P?> relocate(P printer, {Duration? timeout}) => _guard(
    'Tìm lại ${printer.refName} theo MAC',
    () => _inner.relocate(printer, timeout: timeout),
    (timeout ?? quick) + const Duration(seconds: 5),
    null,
  );
}
