import 'dart:async';
import 'dart:convert';

import 'printer_auto_add_plan.dart';
import 'store_printer.dart';
import 'store_printer_api.dart';

/// Tự thêm máy in LAN dò thấy trong mạng vào danh sách máy in của cửa hàng —
/// máy bán hàng có ngay máy in để chọn, không phải nhập IP.
///
/// Chạy khi trạm in đang bật VÀ là trạm in chính ([enabled]) — nhiều trạm cùng
/// mạng không cùng thêm một máy in. Lượt chạy: sau khi bật [startDelay], mỗi
/// [every], và khi đổi mạng ([networkChanged]).
class PrinterAutoAdd {
  PrinterAutoAdd({
    required StorePrinterRepository repository,
    required Future<List<FoundPrinter>> Function() scan,
    required bool Function() enabled,
    required String? Function() companyKey,
    required String? Function(String key) readStore,
    required void Function(String key, String value) writeStore,
    void Function(List<StorePrinter> added)? onAdded,
    void Function(String message)? log,
    DateTime Function()? now,
  }) : _repository = repository,
       _scan = scan,
       _enabled = enabled,
       _companyKey = companyKey,
       _read = readStore,
       _write = writeStore,
       _onAdded = onAdded ?? ((_) {}),
       _log = log ?? ((_) {}),
       _now = now ?? DateTime.now;

  static const Duration startDelay = Duration(seconds: 20);
  static const Duration every = Duration(minutes: 30);
  static const Duration _networkDebounce = Duration(seconds: 10);

  final StorePrinterRepository _repository;
  final Future<List<FoundPrinter>> Function() _scan;
  final bool Function() _enabled;
  final String? Function() _companyKey;
  final String? Function(String key) _read;
  final void Function(String key, String value) _write;
  final void Function(List<StorePrinter> added) _onAdded;
  final void Function(String message) _log;
  final DateTime Function() _now;

  Timer? _timer;
  Timer? _soon;
  Future<int>? _running;

  void start() {
    stop();
    _soon = Timer(startDelay, () => unawaited(runOnce()));
    _timer = Timer.periodic(every, (_) => unawaited(runOnce()));
  }

  void stop() {
    _timer?.cancel();
    _soon?.cancel();
    _timer = _soon = null;
  }

  void networkChanged() {
    if (_timer == null) return;
    _soon?.cancel();
    _soon = Timer(_networkDebounce, () => unawaited(runOnce()));
  }

  /// Một lượt; trả số máy in đã thêm. Đang chạy thì dùng chung lượt đó.
  Future<int> runOnce() => _running ??= _run().whenComplete(() {
    _running = null;
  });

  Future<int> _run() async {
    final company = _companyKey();
    if (company == null || !_enabled()) return 0;
    final List<FoundPrinter> found;
    final List<StorePrinter> existing;
    try {
      found = await _scan();
      if (found.isEmpty) return 0;
      existing = await _repository.list();
    } on StoreApiException catch (e) {
      _log('[AUTO-ADD] Không đọc được danh sách máy in cửa hàng: ${e.message}');
      return 0;
    } catch (e) {
      _log('[AUTO-ADD] Dò máy in lỗi: $e');
      return 0;
    }
    final key = 'autoAddPrinters.$company';
    AutoAddMemory memory;
    try {
      memory = AutoAddMemory.fromJson(jsonDecode(_read(key) ?? 'null'));
    } catch (_) {
      memory = const AutoAddMemory();
    }
    final plan = PrinterAutoAddPlan.plan(
      found: found,
      existing: existing,
      memory: memory,
      now: _now(),
    );
    final added = <StorePrinter>[];
    for (final p in plan.toCreate) {
      // Công ty đổi / trạm tắt giữa chừng: dừng.
      if (_companyKey() != company || !_enabled()) break;
      try {
        await _repository.create(p);
        added.add(p);
        _log('[AUTO-ADD] Đã thêm ${p.name} (${p.ip}) vào cửa hàng');
      } on StoreApiException catch (e) {
        _log('[AUTO-ADD] Thêm ${p.ip} lỗi: ${e.message}');
      }
    }
    _write(
      key,
      jsonEncode(
        AutoAddMemory(
          // Máy vừa thêm coi như đã có — lượt sau không tưởng bị xoá.
          known: {
            ...plan.memory.known,
            for (final p in added)
              p.mac != null ? 'mac:${p.mac}' : 'ip:${p.ip}',
          },
          removed: plan.memory.removed,
        ).toJson(),
      ),
    );
    if (added.isNotEmpty) _onAdded(added);
    return added.length;
  }
}
