import 'dart:convert';

import 'package:print_agent/print_agent.dart';
import 'package:printer_label/desktop.dart';

import 'agent_store.dart';
import 'desktop_printer.dart';
import 'paper_size.dart';
import 'printer_settings.dart';
import 'printer_type.dart';

/// Máy in người dùng thêm vào trạm in này NGOÀI máy in chính (một quầy có thể cắm
/// máy in hoá đơn + máy in tem + máy in bếp): hiện trên sơ đồ, nhận lệnh in nhắm
/// vào đúng địa chỉ của nó (kể cả tem). Lưu theo công ty.
class DesktopExtraPrinters {
  DesktopExtraPrinters(this._companyKey);

  static const int maxPrinters = 50;

  final String Function() _companyKey;

  String? _loadedFor;
  List<ExtraPrinter> _items = [];

  String get _storageKey => 'extraPrinters.${_companyKey()}';

  List<ExtraPrinter> get items {
    _load();
    return List.unmodifiable(_items);
  }

  bool contains(String address) {
    _load();
    final a = address.trim();
    return _items.any((e) => e.address == a);
  }

  /// Thêm máy in [address]. `false` khi đã có hoặc hết chỗ.
  bool add(
    String address, {
    String name = '',
    String mac = '',
    PrinterType? type,
    PaperSize paper = PaperSize.size80,
  }) {
    _load();
    final a = address.trim();
    if (a.isEmpty || contains(a) || _items.length >= maxPrinters) return false;
    _items.add(
      ExtraPrinter(
        address: a,
        name: name,
        mac: mac,
        type: type ?? PrinterType.receipt,
        paper: paper,
      ),
    );
    _save();
    return true;
  }

  /// Bỏ máy in [address]. `false` khi không có.
  bool remove(String address) {
    _load();
    final before = _items.length;
    _items.removeWhere((e) => e.address == address.trim());
    if (_items.length == before) return false;
    _save();
    return true;
  }

  /// Cập nhật tên / loại / MAC (đọc được sau khi nhận ra máy in).
  bool update(
    String address, {
    String? name,
    PrinterType? type,
    String? mac,
    PaperSize? paper,
    double? offsetXMm,
    double? offsetYMm,
    double? gapMm,
    bool? beep,
    bool? autoCut,
    int? dpi,
    RibbonMode? ribbon,
  }) {
    _load();
    final i = _items.indexWhere((e) => e.address == address.trim());
    if (i < 0) return false;
    _items[i] = _items[i].copyWith(
      name: name,
      type: type,
      mac: mac,
      paper: paper,
      offsetXMm: offsetXMm,
      offsetYMm: offsetYMm,
      gapMm: gapMm,
      beep: beep,
      autoCut: autoCut,
      dpi: dpi,
      ribbon: ribbon,
    );
    _save();
    return true;
  }

  /// Ghi cài đặt riêng của máy in [address].
  bool updateSettings(String address, PrinterSettings v) => update(
    address,
    type: v.type,
    paper: v.paper,
    offsetXMm: v.offsetXMm,
    offsetYMm: v.offsetYMm,
    gapMm: v.gapMm,
    beep: v.beep,
    autoCut: v.autoCut,
    dpi: v.dpi,
    ribbon: v.ribbon,
  );

  /// Máy in [from] tìm lại được ở [to] (đổi IP, theo MAC).
  bool moved(String from, String to) {
    _load();
    final i = _items.indexWhere((e) => e.address == from.trim());
    if (i < 0 || _items[i].address == to) return false;
    _items[i] = _items[i].copyWith(address: to);
    _save();
    return true;
  }

  ExtraPrinter? byAddress(String address) {
    _load();
    final a = address.trim();
    for (final e in _items) {
      if (e.address == a) return e;
    }
    return null;
  }

  void _load() {
    final key = _storageKey;
    if (_loadedFor == key) return;
    _loadedFor = key;
    _items = [];
    try {
      final raw = AgentStore.get(key);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      for (final m in list) {
        if (m is Map) {
          final e = ExtraPrinter.fromJson(m);
          if (e != null) _items.add(e);
        }
      }
    } catch (_) {
      _items = [];
    }
  }

  void _save() => AgentStore.set(
    _storageKey,
    jsonEncode([for (final e in _items) e.toJson()]),
  );
}

class ExtraPrinter {
  const ExtraPrinter({
    required this.address,
    this.name = '',
    this.type = PrinterType.receipt,
    this.mac = '',
    this.paper = PaperSize.size80,
    this.offsetXMm = 0,
    this.offsetYMm = 0,
    this.gapMm = 0,
    this.beep = true,
    this.autoCut = true,
    this.dpi = 203,
    this.ribbon = RibbonMode.auto,
  });

  final String address;

  /// Model máy in (đọc được thì có), rỗng = chưa nhận ra.
  final String name;
  final PrinterType type;
  final String mac;

  /// Khổ giấy hoá đơn (máy in tem không dùng).
  final PaperSize paper;

  /// Độ chỉnh tem của máy này (xem [PrinterSettings]).
  final double offsetXMm;
  final double offsetYMm;
  final double gapMm;
  final bool beep;
  final bool autoCut;

  /// Máy tem: độ phân giải đầu in và ruy-băng mực.
  final int dpi;
  final RibbonMode ribbon;

  PrinterSettings get settings => PrinterSettings(
    type: type,
    paper: paper,
    offsetXMm: offsetXMm,
    offsetYMm: offsetYMm,
    gapMm: gapMm,
    beep: beep,
    autoCut: autoCut,
    dpi: dpi,
    ribbon: ribbon,
  );

  ExtraPrinter copyWith({
    String? address,
    String? name,
    PrinterType? type,
    String? mac,
    PaperSize? paper,
    double? offsetXMm,
    double? offsetYMm,
    double? gapMm,
    bool? beep,
    bool? autoCut,
    int? dpi,
    RibbonMode? ribbon,
  }) => ExtraPrinter(
    address: address ?? this.address,
    name: name ?? this.name,
    type: type ?? this.type,
    mac: mac ?? this.mac,
    paper: paper ?? this.paper,
    offsetXMm: offsetXMm ?? this.offsetXMm,
    offsetYMm: offsetYMm ?? this.offsetYMm,
    gapMm: gapMm ?? this.gapMm,
    beep: beep ?? this.beep,
    autoCut: autoCut ?? this.autoCut,
    dpi: dpi ?? this.dpi,
    ribbon: ribbon ?? this.ribbon,
  );

  /// "Máy in tem · XP-420B" như máy in chính.
  String get title =>
      name.trim().isEmpty ? type.title : '${type.title} · $name';

  DesktopPrinter toPrinter() => DesktopPrinter(
    kind: UsbPrinters.isLocal(address)
        ? AgentPrinterKind.usb
        : AgentPrinterKind.lan,
    address: address,
    name: title,
    mac: mac.isEmpty ? null : mac,
  );

  Map<String, Object?> toJson() => {
    'address': address,
    'name': name,
    'type': type.name,
    'mac': mac,
    'paper': paper.name,
    'offsetX': offsetXMm,
    'offsetY': offsetYMm,
    'gap': gapMm,
    'beep': beep,
    'autoCut': autoCut,
    'dpi': dpi,
    'ribbon': ribbon.name,
  };

  static ExtraPrinter? fromJson(Map<Object?, Object?> m) {
    final address = m['address'];
    if (address is! String || address.trim().isEmpty) return null;
    return ExtraPrinter(
      address: address.trim(),
      name: m['name']?.toString() ?? '',
      type: PrinterType.fromName(m['type']?.toString()),
      mac: m['mac']?.toString() ?? '',
      paper: PaperSize.fromName(m['paper']?.toString()),
      offsetXMm: _mm(m['offsetX']),
      offsetYMm: _mm(m['offsetY']),
      beep: m['beep'] != false,
      autoCut: m['autoCut'] != false,
      dpi: m['dpi'] == 300 ? 300 : 203,
      ribbon: RibbonMode.fromName(m['ribbon']?.toString()),
      gapMm: (m['gap'] is num ? (m['gap'] as num).toDouble() : 0.0)
          .clamp(0.0, 10.0)
          .toDouble(),
    );
  }

  static double _mm(Object? v) =>
      (v is num ? v.toDouble() : 0).clamp(-20.0, 20.0).toDouble();
}
