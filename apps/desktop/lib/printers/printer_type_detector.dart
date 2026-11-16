import 'package:printer_label/desktop.dart'
    show PrinterLanguage, PrinterLanguageProbe;

import '../agent/printer_type.dart';

/// Kết luận loại máy in + lý do (hiện cho người dùng).
class PrinterTypeGuess {
  const PrinterTypeGuess(this.type, this.note);

  /// `null` = chưa rõ (máy không trả lời, tên model cũng không gợi ý gì).
  final PrinterType? type;
  final String note;
}

/// Quyết định máy in là máy in TEM hay máy in HOÁ ĐƠN từ kết quả dò ngôn ngữ
/// ([PrinterLanguage]) và tên model — một chỗ dùng chung cho hộp chọn máy in
/// (nhãn trên từng máy) lẫn lúc chọn xong ([DesktopAgent.identifyPrinter]).
abstract final class PrinterTypeDetector {
  static PrinterTypeGuess decide({PrinterLanguage? language, String? model}) {
    final name = (model ?? '').trim();
    final byModel = PrinterLanguageProbe.looksLikeLabelModel(name);
    return switch (language) {
      PrinterLanguage.label => const PrinterTypeGuess(
        PrinterType.label,
        'Máy trả lời lệnh tem (TSPL) → Máy in tem.',
      ),
      // Máy hoá đơn không hiểu lệnh tem: trả lời được cả hai thì là máy tem.
      PrinterLanguage.both => const PrinterTypeGuess(
        PrinterType.label,
        'Máy trả lời cả lệnh hoá đơn và lệnh tem → chọn Tem.',
      ),
      PrinterLanguage.receipt =>
        byModel
            ? PrinterTypeGuess(
                PrinterType.label,
                'Tên máy ($name) là máy in tem → chọn Tem.',
              )
            : const PrinterTypeGuess(
                PrinterType.receipt,
                'Máy chỉ trả lời lệnh hoá đơn → Máy in hoá đơn.',
              ),
      PrinterLanguage.unknown || null =>
        byModel
            ? PrinterTypeGuess(
                PrinterType.label,
                'Tên máy ($name) là máy in tem → chọn Tem.',
              )
            : const PrinterTypeGuess(
                null,
                'Máy không trả lời lệnh nào: hãy chọn loại máy in bằng tay.',
              ),
    };
  }
}
