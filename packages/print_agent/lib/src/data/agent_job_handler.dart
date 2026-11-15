import 'dart:async';
import 'dart:collection';

import 'package:get/get.dart';
import 'package:print_agent_core/print_agent_core.dart';

import '../domain/entities/agent_job_log.dart';
import '../domain/entities/agent_printer_ref.dart';
import '../domain/ports/agent_job_printer.dart';
import '../print_agent_module.dart';
import 'agent_job_log_store.dart';
import 'agent_print_activity_store.dart';
import 'agent_printer_watchdog.dart';

/// Máy Agent in các lệnh nhận được — an toàn cho bếp F&B:
///
/// - **Không in đúp:** mỗi mã lệnh ([PrintRelayJob.dedupeKey]) in MỘT lần trong
///   [dedupeWindow], dù lệnh tới qua LAN, MQTT hay Firebase hoặc máy gửi gửi
///   lại khi mất phản hồi (lệnh trùng nhận chung kết quả lệnh đầu).
/// - **Mỗi máy in một hàng đợi (FIFO):** phiếu chế biến / huỷ món ra đúng thứ
///   tự; máy in bếp tắt không làm kẹt máy in bill hay máy in tem.
/// - **Ngắt nhanh máy in vừa mất kết nối** ([breakerWindow]): lệnh sau báo lỗi
///   ngay, không bắt mỗi lệnh chờ dò lại 10–15 giây.
/// - **Giữ lệnh khi hết giấy / mở nắp / quá nhiệt** (máy in báo TRƯỚC khi nhận
///   dữ liệu — chưa in gì): báo máy gửi [PrintRelayStatus.held], thử lại mỗi
///   [holdRetry] tới [holdMax] rồi tự in khi máy in sẵn sàng.
/// - Mọi lời gọi xuống app chủ có giới hạn thời gian.
class AgentJobHandler<P extends AgentPrinterRef> {
  AgentJobHandler({
    required AgentPrinterWatchdog<P> watchdog,
    required AgentJobPrinter<P> printer,
  }) : _watchdog = watchdog,
       _printer = printer;

  static const Duration dedupeWindow = Duration(minutes: 15);
  static const int dedupeMax = 500;
  static Duration breakerWindow = const Duration(seconds: 10);
  static const Duration holdMax = Duration(minutes: 10);
  static Duration holdRetry = const Duration(seconds: 5);
  static Duration readyTimeout = const Duration(seconds: 30);
  static const Duration printTimeout = Duration(seconds: 90);

  final AgentPrinterWatchdog<P> _watchdog;
  final AgentJobPrinter<P> _printer;

  /// Số lệnh đã in hộ / lỗi và lúc nhận lệnh gần nhất (màn Máy Agent).
  final RxInt printed = 0.obs;
  final RxInt failed = 0.obs;
  final Rxn<DateTime> lastJobAt = Rxn<DateTime>();

  /// Mã lệnh → (lúc nhận, kết quả). Thứ tự chèn = cũ trước.
  final LinkedHashMap<String, (DateTime, Future<bool>)> _recent =
      LinkedHashMap();

  /// Máy in → đuôi hàng đợi (lệnh sau chờ lệnh trước xong).
  final Map<String, Future<void>> _tails = {};

  /// Máy in → các lệnh đang chờ tới lượt (để báo "giữ lệnh" khi máy in hết
  /// giấy giữa chừng).
  final Map<String, List<PrintRelayJob>> _waiting = {};

  /// Máy in vừa được xác nhận mất kết nối.
  final Map<String, DateTime> _downAt = {};

  /// Máy in đang giữ lệnh (hết giấy / mở nắp).
  final Set<String> _holding = {};

  /// Đổi công ty: đếm lại từ đầu.
  void reset() {
    printed.value = 0;
    failed.value = 0;
    lastJobAt.value = null;
  }

  Future<bool> handle(PrintRelayJob job) {
    final key = job.dedupeKey;
    _pruneRecent();
    final prev = key.isEmpty ? null : _recent[key];
    if (prev != null) {
      PrintAgentModule.host.log('[AGENT] Bỏ lệnh trùng $key (đã nhận trước)');
      return prev.$2;
    }
    final result = _enqueue(job);
    if (key.isNotEmpty) _recent[key] = (DateTime.now(), result);
    return result;
  }

  void _pruneRecent() {
    final cutoff = DateTime.now().subtract(dedupeWindow);
    while (_recent.isNotEmpty &&
        (_recent.length > dedupeMax ||
            _recent.values.first.$1.isBefore(cutoff))) {
      _recent.remove(_recent.keys.first);
    }
  }

  static String _printerKey(AgentPrinterRef p) =>
      '${p.refKind?.name}|${p.refAddress?.trim() ?? ''}';

  Future<bool> _enqueue(PrintRelayJob job) {
    final found = _printer.resolve(job);
    final key = _printerKey(found);
    final waiting = _waiting.putIfAbsent(key, () => []);
    waiting.add(job);
    // Máy in đang giữ lệnh: lệnh mới xếp sau, báo máy gửi ngay.
    if (_holding.contains(key)) job.onHeld?.call();
    final result = Completer<bool>();
    final tail = (_tails[key] ?? Future<void>.value()).then((_) async {
      waiting.remove(job);
      try {
        result.complete(await _run(job, found, key));
      } catch (e) {
        PrintAgentModule.host.log('[AGENT] In lệnh lỗi: $e');
        result.complete(false);
      }
    });
    _tails[key] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_tails[key], tail)) _tails.remove(key);
      }),
    );
    return result.future;
  }

  Future<bool> _run(PrintRelayJob job, P found, String key) async {
    final sw = Stopwatch()..start();
    lastJobAt.value = DateTime.now();
    final target = job.printer;
    // Sơ đồ máy Agent làm nổi máy in đang nhận lệnh này.
    final activity = AgentPrintActivityStore.start(
      isLabel: job.isLabel,
      builtIn: target.isBuiltIn,
      usb: target.isUsb,
      ip: target.isBuiltIn || target.isUsb ? null : target.address,
      printerId: target.id,
      sender: job.sender,
    );
    String? printedIp;
    final name = found.nameOrNull ?? found.refAddress ?? '';
    bool record(AgentPrintFailure? failure) {
      final ok = failure == null;
      AgentPrintActivityStore.finish(activity, ok: ok, ip: printedIp);
      ok ? printed.value++ : failed.value++;
      AgentJobLogStore.add(
        AgentJobLog(
          at: DateTime.now(),
          sender: job.sender,
          isLabel: job.isLabel,
          printerName: job.images.isEmpty
              ? (target.name ?? target.address)
              : name,
          copies: job.copies,
          ok: ok,
          error: failure?.error,
          printerAddress: target.isBuiltIn ? null : target.address,
          connection: target.isBuiltIn
              ? 'builtin'
              : (target.isUsb ? 'usb' : 'lan'),
          detail: failure?.detail,
          viaLan: job.id == 'lan',
          durationMs: sw.elapsedMilliseconds,
        ),
      );
      return ok;
    }

    if (job.images.isEmpty) {
      return record(const AgentPrintFailure(AgentJobError.noContent));
    }
    final down = _downAt[key];
    if (down != null && DateTime.now().difference(down) < breakerWindow) {
      return record(AgentPrintFailure(await _notReadyReason(found)));
    }
    // Máy in vừa tắt nguồn / mất mạng / bật lại nhận IP mới: chờ sẵn sàng.
    final ready = await _watchdog.printing(
      () => _watchdog
          .waitUntilReady(found)
          .timeout(readyTimeout, onTimeout: () => null),
    );
    if (ready == null) {
      _downAt[key] = DateTime.now();
      return record(AgentPrintFailure(await _notReadyReason(found)));
    }
    _downAt.remove(key);
    printedIp = ready.refAddress;
    var failure = await _attempt(ready, job);
    if (_holdable(failure)) failure = await _hold(ready, job, key, failure!);
    return record(failure);
  }

  Future<AgentPrintFailure?> _attempt(P printer, PrintRelayJob job) =>
      _watchdog.printing(
        () => _printer
            .printJob(printer, job)
            .timeout(
              printTimeout,
              onTimeout: () => const AgentPrintFailure(
                AgentJobError.notReady,
                detail: 'Máy in không phản hồi',
              ),
            ),
      );

  /// Lỗi máy in báo TRƯỚC khi nhận dữ liệu (chưa in gì) — an toàn để giữ lệnh
  /// rồi in lại.
  static bool _holdable(AgentPrintFailure? f) =>
      f != null &&
      (f.error == AgentJobError.outOfPaper ||
          f.error == AgentJobError.coverOpen ||
          f.error == AgentJobError.overheated);

  /// Giữ lệnh tới khi máy in sẵn sàng (thay giấy / đóng nắp) hoặc hết [holdMax].
  /// Các lệnh đang chờ cùng máy in cũng được báo "giữ lệnh".
  Future<AgentPrintFailure?> _hold(
    P printer,
    PrintRelayJob job,
    String key,
    AgentPrintFailure first,
  ) async {
    _holding.add(key);
    final host = PrintAgentModule.host;
    host.log(
      '[AGENT] ${printer.refName}: ${first.error.name} — giữ lệnh, tự in khi '
      'máy in sẵn sàng',
    );
    job.onHeld?.call();
    for (final waiting in List.of(_waiting[key] ?? const <PrintRelayJob>[])) {
      waiting.onHeld?.call();
    }
    final until = DateTime.now().add(holdMax);
    AgentPrintFailure? failure = first;
    try {
      while (_holdable(failure) && DateTime.now().isBefore(until)) {
        await Future<void>.delayed(holdRetry);
        failure = await _attempt(printer, job);
      }
    } finally {
      _holding.remove(key);
    }
    if (failure == null) {
      host.log('[AGENT] ${printer.refName}: đã in lệnh đang giữ');
    }
    return failure;
  }

  /// Vì sao máy Agent không tới được [printer] (cho nhật ký lệnh in).
  static Future<AgentJobError> _notReadyReason(AgentPrinterRef printer) async {
    if (printer.refKind == AgentPrinterKind.builtIn) {
      return AgentJobError.builtInNotReady;
    }
    final ip = printer.refAddress?.trim() ?? '';
    if (printer.refKind == AgentPrinterKind.lan &&
        ip.isNotEmpty &&
        !await PrintRelayClient.isOnSameSubnet(ip)) {
      return AgentJobError.otherNetwork;
    }
    return AgentJobError.notReady;
  }
}
