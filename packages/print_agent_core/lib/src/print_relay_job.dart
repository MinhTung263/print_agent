import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:printer_label/printer_label.dart';
import 'print_relay_image.dart';
import 'print_relay_label_spec.dart';

/// Loại lệnh in gửi qua trạm.
enum PrintRelayJobKind {
  /// Ảnh hoá đơn (ESC/POS).
  receipt,

  /// Các hàng tem (TSPL), mỗi ảnh là một hàng.
  label,
}

/// Trạng thái lệnh trong hàng đợi: pending → printing → done | failed.
abstract final class PrintRelayStatus {
  static const String pending = 'pending';
  static const String printing = 'printing';
  static const String done = 'done';
  static const String failed = 'failed';

  /// Máy in hết giấy / mở nắp: trạm GIỮ lệnh và tự in khi máy in sẵn sàng lại
  /// (máy gửi báo "sẽ tự in", không bắt in lại — tránh in đúp).
  static const String held = 'held';
}

/// Máy in đích của lệnh in qua trạm.
class PrintRelayPrinter {
  const PrintRelayPrinter({
    required this.address,
    this.isUsb = false,
    this.usbDeviceId,
    this.id,
    this.name,
    this.isBuiltIn = false,
    this.stationId,
    this.mac,
  });

  /// Máy in tích hợp của trạm [stationId] (VD Sunmi / T1-G) — chỉ trạm đó in.
  const PrintRelayPrinter.stationBuiltIn({
    required String this.stationId,
    this.name,
  }) : address = 'builtin',
       isUsb = false,
       usbDeviceId = null,
       id = null,
       mac = null,
       isBuiltIn = true;

  /// Máy in tích hợp sẵn trong trạm (không phải LAN / USB).
  final bool isBuiltIn;

  /// Chỉ trạm có mã này được in lệnh (`null` = trạm nào giành được trước).
  final String? stationId;

  /// Bản chỉ định trạm [id] (máy gửi nhắm thẳng một Agent).
  PrintRelayPrinter withStation(String id) => PrintRelayPrinter(
    address: address,
    isUsb: isUsb,
    usbDeviceId: usbDeviceId,
    id: this.id,
    name: name,
    isBuiltIn: isBuiltIn,
    stationId: id,
    mac: mac,
  );

  /// IP máy in LAN, hoặc địa chỉ máy in USB.
  final String address;
  final bool isUsb;

  /// Mã máy in USB dạng `USB:...` ([PrinterLabel.isUsbAttached]); trống thì dùng
  /// [address].
  final String? usbDeviceId;

  /// Mã máy in đã lưu ở app (để trạm tìm cấu hình của chính máy in đó).
  final Object? id;
  final String? name;

  /// MAC máy in LAN (nếu máy gửi biết): trạm thấy máy in ở IP đó có MAC KHÁC
  /// thì không nhận — 2 chi nhánh trùng dải IP không in nhầm sang nhau.
  final String? mac;

  String get usbId => (usbDeviceId ?? '').isNotEmpty ? usbDeviceId! : address;
}

/// Một lệnh in gửi từ máy không tới được máy in sang trạm in (máy cùng mạng /
/// đang cắm USB với máy in) để trạm in hộ.
///
/// [toMap] / [fromMap] là định dạng lưu trên hàng đợi — giữ ổn định để máy chạy
/// bản cũ và bản mới vẫn in qua nhau được.
class PrintRelayJob {
  const PrintRelayJob({
    this.id,
    required this.kind,
    required this.printer,
    required this.images,
    this.paperSize,
    this.labelSize,
    this.labelSpec,
    this.copies = 1,
    this.openDrawer = false,
    this.status = PrintRelayStatus.pending,
    this.createdAt,
    this.sender,
    this.key,
    this.beep = false,
    this.onHeld,
  });

  /// Mã ngẫu nhiên cho một lệnh mới (giữ nguyên khi gửi lại qua kênh khác).
  static String newKey() {
    final r = Random.secure();
    return List.generate(
      12,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// Lệnh in hoá đơn: [paperSize] là tên khổ giấy của app (VD `size80`).
  factory PrintRelayJob.receipt({
    required PrintRelayPrinter printer,
    required Uint8List image,
    String? paperSize,
    int quantity = 1,
    bool openDrawer = false,
    String? sender,
    bool beep = false,
  }) => PrintRelayJob(
    kind: PrintRelayJobKind.receipt,
    printer: printer,
    images: [image],
    paperSize: paperSize,
    copies: quantity,
    openDrawer: openDrawer,
    sender: sender,
    key: newKey(),
    beep: beep,
  );

  /// Lệnh in tem. Mặc định thu ảnh về đúng độ phân giải máy in
  /// ([PrinterLabel.shrinkLabelImage], [dotsPerMm]: 8 ở 203dpi, ~11,81 ở 300dpi — tem vàng
  /// bạc cần mịn hơn) rồi đổi sang đen / trắng
  /// ([PrintRelayImage.compact]) để gửi qua mạng nhanh hơn.
  static Future<PrintRelayJob> label({
    required PrintRelayPrinter printer,
    required List<Uint8List> images,
    required LabelPerRow size,
    int copies = 1,
    bool shrink = true,
    String? sender,
    double dotsPerMm = 8,
  }) async => PrintRelayJob(
    kind: PrintRelayJobKind.label,
    printer: printer,
    images: shrink
        ? [
            for (final i in images)
              await PrintRelayImage.compact(
                await PrinterLabel.shrinkLabelImage(
                  i,
                  size,
                  dotsPerMm: dotsPerMm,
                ),
              ),
          ]
        : images,
    labelSize: size,
    copies: copies,
    sender: sender,
    key: newKey(),
  );

  /// Mã lệnh trên hàng đợi (có sau khi gửi / khi trạm nhận).
  final String? id;
  final PrintRelayJobKind kind;
  final PrintRelayPrinter printer;

  /// Hoá đơn: một ảnh; tem: mỗi hàng một ảnh.
  final List<Uint8List> images;

  /// Khổ giấy hoá đơn (tên do app quy ước).
  final String? paperSize;
  final LabelPerRow? labelSize;

  /// Kích thước thật của hàng tem (Agent máy tính dùng; app bản cũ bỏ qua).
  final PrintRelayLabelSpec? labelSpec;

  /// Số bản (hoá đơn) / số lần lặp (tem), tối thiểu 1.
  final int copies;
  final bool openDrawer;
  final String status;

  /// Mốc tạo lệnh (ms) — trạm bỏ lệnh quá hạn.
  final int? createdAt;

  /// Tên máy gửi lệnh (hiện ở nhật ký máy Agent); `null` với máy bản cũ.
  final String? sender;

  /// Mã của lệnh, GIỮ NGUYÊN khi máy gửi gửi lại qua kênh khác (LAN → MQTT →
  /// Firebase): trạm in mỗi mã một lần — mất phản hồi rồi gửi lại không in đúp.
  /// `null` với máy gửi bản cũ.
  final String? key;

  /// Kêu còi báo bếp sau khi in (phiếu chế biến / huỷ món).
  final bool beep;

  /// Trạm gắn khi nhận lệnh (KHÔNG gửi đi): gọi khi giữ lệnh chờ máy in sẵn
  /// sàng lại ([PrintRelayStatus.held]).
  final void Function()? onHeld;

  /// Mã để bỏ lệnh trùng: [key], máy gửi bản cũ thì mã lệnh trên hàng đợi.
  String get dedupeKey => key ?? id ?? '';

  bool get isLabel => kind == PrintRelayJobKind.label;

  /// Bản với máy in đích [printer] khác (VD đã chỉ định trạm).
  PrintRelayJob withPrinter(PrintRelayPrinter printer) =>
      _copy(printer: printer);

  /// Bản có [onHeld] (trạm gắn khi nhận lệnh).
  PrintRelayJob withOnHeld(void Function() onHeld) => _copy(onHeld: onHeld);

  PrintRelayJob _copy({PrintRelayPrinter? printer, void Function()? onHeld}) =>
      PrintRelayJob(
        id: id,
        kind: kind,
        printer: printer ?? this.printer,
        images: images,
        paperSize: paperSize,
        labelSize: labelSize,
        labelSpec: labelSpec,
        copies: copies,
        openDrawer: openDrawer,
        status: status,
        createdAt: createdAt,
        sender: sender,
        key: key,
        beep: beep,
        onHeld: onHeld ?? this.onHeld,
      );

  int get payloadBytes => images.fold(0, (sum, i) => sum + i.length);

  Map<String, Object?> toMap() => {
    'kind': kind.name,
    'status': status,
    'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
    'printerId': printer.id,
    'printerIp': printer.address.trim(),
    'printerType': printer.isBuiltIn
        ? 'builtin'
        : (printer.isUsb ? 'usb' : 'lan'),
    if (printer.stationId != null) 'targetStation': printer.stationId,
    'printerName': printer.name,
    if (sender != null) 'sender': sender,
    if (key != null) 'key': key,
    if (beep) 'beep': true,
    if (printer.isUsb) 'usbDeviceId': printer.usbId,
    if (printer.mac != null) 'printerMac': printer.mac,
    if (isLabel) ...{
      'labelSize': labelSize?.name,
      if (labelSpec != null) 'labelSpec': labelSpec!.toMap(),
      'copies': copies < 1 ? 1 : copies,
      'images': images.map(base64Encode).toList(),
    } else ...{
      'size': paperSize,
      'quantity': copies < 1 ? 1 : copies,
      'openDrawer': openDrawer,
      'image': images.isEmpty ? null : base64Encode(images.first),
    },
  };

  /// Đọc lệnh từ hàng đợi; `null` khi dữ liệu không hợp lệ.
  static PrintRelayJob? fromMap(String id, Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final address = map['printerIp'];
    if (address is! String || address.isEmpty) return null;
    final isLabel = map['kind'] == PrintRelayJobKind.label.name;
    List<Uint8List> images;
    try {
      if (isLabel) {
        final list = map['images'];
        images = list is List
            ? [for (final i in list) base64Decode(i.toString())]
            : const [];
      } else {
        final image = map['image'];
        images = image is String ? [base64Decode(image)] : const [];
      }
    } catch (_) {
      images = const [];
    }
    final count = isLabel ? map['copies'] : map['quantity'];
    return PrintRelayJob(
      id: id,
      kind: isLabel ? PrintRelayJobKind.label : PrintRelayJobKind.receipt,
      printer: PrintRelayPrinter(
        address: address,
        isUsb: map['printerType'] == 'usb',
        isBuiltIn: map['printerType'] == 'builtin',
        stationId: map['targetStation']?.toString(),
        usbDeviceId: map['usbDeviceId']?.toString(),
        id: map['printerId'],
        name: map['printerName']?.toString(),
        mac: map['printerMac']?.toString(),
      ),
      images: images,
      paperSize: map['size']?.toString(),
      labelSize: LabelPerRow.fromName(map['labelSize']?.toString()),
      labelSpec: PrintRelayLabelSpec.fromMap(map['labelSpec']),
      copies: count is int && count > 0 ? count : 1,
      openDrawer: map['openDrawer'] == true,
      status: map['status']?.toString() ?? '',
      createdAt: map['createdAt'] is int ? map['createdAt'] as int : null,
      sender: map['sender']?.toString(),
      key: map['key']?.toString(),
      beep: map['beep'] == true,
    );
  }
}
