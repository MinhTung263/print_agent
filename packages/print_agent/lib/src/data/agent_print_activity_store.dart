import 'dart:async';

import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../domain/entities/agent_print_activity.dart';
import '../domain/entities/agent_printer_ref.dart';

/// Các lệnh in hộ đang chạy / vừa xong trên máy này. Lệnh xong giữ thêm
/// [_keepDone] cho người dùng kịp thấy kết quả rồi tự bỏ.
abstract final class AgentPrintActivityStore {
  static const Duration _keepDone = Duration(seconds: 5);
  static const Duration _stuckAfter = Duration(minutes: 2);

  static final RxList<AgentPrintActivity> items = <AgentPrintActivity>[].obs;
  static int _seq = 0;

  /// Bắt đầu một lệnh — trả mã để [finish].
  static int start({
    required bool isLabel,
    required bool builtIn,
    required bool usb,
    String? ip,
    Object? printerId,
    String? sender,
  }) {
    final seq = ++_seq;
    items.add(
      AgentPrintActivity(
        seq: seq,
        phase: AgentPrintPhase.printing,
        isLabel: isLabel,
        builtIn: builtIn,
        usb: usb,
        ips: {if (ip != null && ip.trim().isNotEmpty) ip.trim()},
        printerId: printerId,
        sender: sender,
      ),
    );
    // Chốt an toàn: lệnh lỗi ngoại lệ không gọi [finish] thì không nhấp nháy mãi.
    Timer(_stuckAfter, () {
      if (items.any((a) => a.seq == seq && a.active)) finish(seq, ok: false);
    });
    return seq;
  }

  /// Lệnh [seq] xong — [ip]: IP thực tế đã in (máy in đổi IP).
  static void finish(int seq, {required bool ok, String? ip}) {
    final i = items.indexWhere((a) => a.seq == seq);
    if (i < 0) return;
    final a = items[i];
    items[i] = a.copyWith(
      phase: ok ? AgentPrintPhase.done : AgentPrintPhase.failed,
      ips: {...a.ips, if (ip != null && ip.trim().isNotEmpty) ip.trim()},
    );
    Timer(_keepDone, () => items.removeWhere((x) => x.seq == seq));
  }

  /// Hoạt động nên hiện ở máy in [p]: lệnh đang in trước, không thì lệnh vừa
  /// xong gần nhất.
  static AgentPrintActivity? of(AgentPrinterRef p) {
    final list = items.where((a) => a.matches(p)).toList();
    if (list.isEmpty) return null;
    return list.lastWhereOrNull((a) => a.active) ?? list.last;
  }
}
