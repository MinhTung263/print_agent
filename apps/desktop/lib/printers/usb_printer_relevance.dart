import 'package:printer_label/desktop.dart' show Ieee1284, PrinterLanguageProbe;

/// Lọc "USB rác" khỏi danh sách máy in USB để thêm vào trạm in: chỉ giữ máy in có thể in phiếu
/// (hoá đơn / tem), bỏ máy in văn phòng và khổ lớn (HP Designjet, LaserJet, Canon PIXMA...), hàng in
/// ảo (PDF, XPS, OneNote, Fax...) và thiết bị tự báo chỉ hiểu PCL / PostScript.
///
/// Thuần (không đọc phần cứng) nên kiểm thử được; nơi gọi đưa vào tên máy và (nếu đọc được) chuỗi
/// định danh IEEE 1284 của máy.
abstract final class UsbPrinterRelevance {
  /// Hãng / dòng máy in phiếu, tem POS quen thuộc — luôn giữ (thắng mọi luật loại bỏ theo tên).
  static final RegExp _pos = RegExp(
    r'xprinter|hprt|rongta|gprinter|gainscha|zjiang|zhu\s*hai|howbest|munbyn|sunmi|bixolon|'
    r'citizen|epson\s*tm|\btm-?[a-z]?\d|star\s*(tsp|mc|sp|tup)|\btsp\d|tsc\b|ttp-?\d|tdp-?\d|'
    r'zebra|argox|4barcode|godex|postek|sato|datamax|honeywell|brady|iDPRT|idprt|netum|'
    r'\bxp-?\d|\bpos-?\d|\bgp-?\d|\bht-?\d|\bdl-?\d|receipt|thermal|barcode|label|ticket|hoá đơn|tem\b',
    caseSensitive: false,
  );

  /// Máy in văn phòng / khổ lớn / máy đa năng: không nhận lệnh ESC/POS hay TSPL.
  static final RegExp _office = RegExp(
    r'designjet|laserjet|deskjet|officejet|photosmart|envy\b|pagewide|plotter|latex\b|'
    r'pixma|imageclass|\blbp-?\d|\bmf-?\d|maxify|selphy|ecotank|workforce|expression|'
    r'\bstylus\b|\bsurecolor\b|\bl[0-9]{3,4}\b|'
    r'\bhl-?[a-z]?\d|\bdcp-?[a-z]?\d|\bmfc-?[a-z]?\d|\bml-?\d{4}|\bscx-?\d|\bclp-?\d|xpress|'
    r'lexmark|ricoh|kyocera|xerox|konica|minolta|oki\s*data|sharp\s*mx|'
    r'scanner|multifunction|all-in-one|\bmfp\b',
    caseSensitive: false,
  );

  /// Hàng in ảo / phần mềm: không phải máy in thật.
  static final RegExp _virtual = RegExp(
    r'\bpdf\b|cups-pdf|\bxps\b|onenote|\bfax\b|virtual|microsoft print|print to file|'
    r'document writer|send to|snagit|\bnull\b|generic\s*/\s*text only',
    caseSensitive: false,
  );

  /// Ngôn ngữ máy in phiếu / tem (trong `CMD:` của chuỗi IEEE 1284).
  static final RegExp _posCmd = RegExp(
    r'^(ESC/?POS|EPSON|STAR|TSPL|ZPL|EPL|EZPL|CPCL|DPL|TSC|BPLA|BPLB|SBPL|ZJ)',
    caseSensitive: false,
  );

  /// Ngôn ngữ máy in văn phòng.
  static final RegExp _officeCmd = RegExp(
    r'^(PCL|POSTSCRIPT|PS$|PJL|GDI|ACL|ESCPR|ESC/P-R|ESC/P$|ESCP$|HBP|SPLC|LIDIL|BJL|URF|PWG|HP-?GL)',
    caseSensitive: false,
  );

  /// Máy in USB [name] (kèm [deviceId] IEEE 1284 nếu đọc được) có nên hiện để thêm không.
  static bool isUsable(String name, {String? deviceId}) {
    final ieee = deviceId == null
        ? const <String, String>{}
        : Ieee1284.parse(deviceId);
    final text = [name, ieee['MFG'], ieee['MDL']].whereType<String>().join(' ');
    // Lệnh máy tự báo, đã chuẩn hoá (một nguồn với nhận loại máy in tem / hoá đơn).
    final cmds =
        (deviceId == null
            ? null
            : PrinterLanguageProbe.ieeeCommands(deviceId)) ??
        const <String>[];

    // Máy tự báo hiểu lệnh phiếu / tem: chắc chắn là máy in phiếu.
    if (cmds.any(_posCmd.hasMatch)) return true;
    if (_virtual.hasMatch(text)) return false;
    if (_pos.hasMatch(text)) return true;
    // Máy tự báo chỉ hiểu lệnh văn phòng (PCL / PostScript...): không in được phiếu.
    if (cmds.any(_officeCmd.hasMatch)) return false;
    if (_office.hasMatch(text)) return false;
    // Không có gì để kết luận (máy rẻ không khai tên / lệnh): giữ — bỏ nhầm máy thật tệ hơn hiện thừa.
    return true;
  }

  /// Tên đã đủ kết luận mà không cần hỏi máy (đỡ đọc IEEE 1284 từng máy): máy phiếu quen thuộc /
  /// hàng in ảo / máy văn phòng rõ ràng.
  static bool? decidedByName(String name) {
    if (_virtual.hasMatch(name)) return false;
    if (_pos.hasMatch(name)) return true;
    if (_office.hasMatch(name)) return false;
    return null;
  }
}
