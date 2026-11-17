import 'package:printer_label/desktop.dart' show BeepStyle, PrinterBeep;

import '../agent/printer_type.dart';

/// Các cách thử bíp một máy in theo thứ tự (khách bấm lại khi "không nghe thấy"): cách đúng với loại
/// máy trước, rồi các cách còn lại — máy chưa rõ loại / nhận sai loại vẫn có cách bíp được.
abstract final class PrinterBeepPlan {
  static List<BeepStyle> of(PrinterType? type) =>
      PrinterBeep.plan(label: type == null ? null : type == PrinterType.label);

  /// Cách bíp ở lần thử thứ [attempt] (0, 1, 2...; quá số cách thì quay vòng).
  static BeepStyle styleFor(PrinterType? type, int attempt) {
    final plan = of(type);
    return plan[attempt % plan.length];
  }

  /// Còn cách khác để thử sau lần thử [attempt] không.
  static bool hasMore(PrinterType? type, int attempt) =>
      attempt + 1 < of(type).length;

  /// Cách bíp đó là gì (hiện cho khách biết đã gửi lệnh nào).
  static String describe(BeepStyle s) => switch (s) {
    BeepStyle.escpos => 'lệnh máy in hoá đơn (ESC/POS)',
    BeepStyle.tsplSound => 'lệnh máy in tem (TSPL), kêu còi',
    BeepStyle.tsplHome =>
      'lệnh máy in tem (TSPL), nhích cuộn tem tới khe tem đầu tiên — máy không có còi sẽ chạy cuộn tem',
  };
}
