import 'dart:convert';

import 'package:printer_label/desktop.dart' show TsplLabelSpec;

import 'agent_store.dart';
import 'label_preset.dart';

/// Khổ tem máy in tem LẦN IN GẦN NHẤT (từ lệnh của app bán hàng): màn căn chỉnh tem dùng
/// luôn khổ này — khách không phải chọn lại khổ tem. Lưu theo địa chỉ máy in.
abstract final class LastLabel {
  static String _key(String address) => 'lastLabel.${address.trim()}';

  /// Nhớ khổ [spec] gồm [count] tem trên một hàng vừa in ra máy in [address].
  static void remember(String address, TsplLabelSpec spec, int count) {
    final json = jsonEncode({
      'w': spec.widthMm,
      'h': spec.heightMm,
      'gap': spec.gapMm,
      'count': count,
    });
    if (AgentStore.get(_key(address)) != json) {
      AgentStore.set(_key(address), json);
    }
  }

  /// Khổ tem in gần nhất của máy in [address]; chưa in lần nào → khổ mặc định (2 tem
  /// 35×22).
  static LabelPreset of(String address) {
    try {
      final raw = AgentStore.get(_key(address));
      if (raw != null) {
        final m = jsonDecode(raw) as Map;
        final w = (m['w'] as num).toInt();
        final h = (m['h'] as num).toInt();
        final count = ((m['count'] as num?) ?? 1).toInt().clamp(1, 8);
        final gap = (m['gap'] as num?) ?? 2;
        return LabelPreset.forSize(
          widthMm: w,
          heightMm: h,
          count: count,
          gapMm: gap,
        );
      }
    } catch (_) {}
    return LabelPreset.defaultPreset;
  }
}
