import 'dart:convert';

import 'package:print_agent/print_agent.dart';

import 'agent_store.dart';
import 'desktop_printer.dart';

/// Máy in LAN của cửa hàng mà trạm in máy tính đã in giúp ("In hộ máy in
/// LAN"). Máy tính không có danh sách máy in đã lưu như app bán hàng — nhớ
/// theo lệnh in để báo lên sơ đồ: từng máy tạm ngưng / bật lại được (trên máy
/// này hoặc từ xa) như máy in của trạm in Android.
///
/// Lưu theo công ty, tối đa [maxPrinters] máy; máy không in giúp quá
/// [keepFor] thì bỏ (máy in đã thay / bỏ đi).
class DesktopLanPrinters {
  DesktopLanPrinters(this._companyKey, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const int maxPrinters = 20;
  static const Duration keepFor = Duration(days: 30);

  /// Ghi lại "lần in gần nhất" tối đa mỗi khoảng này (không ghi file mỗi
  /// phiếu).
  static const Duration _touchEvery = Duration(hours: 1);

  /// Tên khi máy gửi không báo tên máy in (không hiện IP lên sơ đồ).
  static const String unnamed = 'Máy in chưa đặt tên';

  final String Function() _companyKey;
  final DateTime Function() _now;

  String? _loadedFor;
  List<_Entry> _items = [];

  String get _storageKey => 'lanPrinters.${_companyKey()}';

  List<DesktopPrinter> get printers {
    _load();
    return [for (final e in _items) e.printer];
  }

  /// Vừa in giúp máy in LAN [p]. `true` khi danh sách đổi (máy mới / đổi tên,
  /// IP, MAC) — cần báo lại sơ đồ.
  bool remember(DesktopPrinter p) {
    if (p.kind != AgentPrinterKind.lan || p.address.trim().isEmpty) {
      return false;
    }
    _load();
    final now = _now();
    final i = _items.indexWhere((e) => e.matches(p));
    if (i < 0) {
      _items.insert(0, _Entry(_normalized(p), now));
      _trim();
      _save();
      return true;
    }
    final old = _items[i];
    final next = _merge(old.printer, p);
    final changed = !old.sameAs(next);
    if (!changed && now.difference(old.lastAt) < _touchEvery) return false;
    _items[i] = _Entry(next, now);
    _save();
    return changed;
  }

  /// Máy in [p] tìm lại được ở [address] (đổi IP, theo MAC).
  bool moved(DesktopPrinter p, String address) {
    _load();
    final i = _items.indexWhere((e) => e.matches(p));
    if (i < 0 || _items[i].printer.address == address) return false;
    _items[i] = _Entry(_items[i].printer.withAddress(address), _now());
    _save();
    return true;
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
      final cutoff = _now().subtract(keepFor);
      for (final m in list) {
        if (m is! Map) continue;
        final e = _Entry.fromJson(m);
        if (e != null && e.lastAt.isAfter(cutoff)) _items.add(e);
      }
    } catch (_) {
      _items = [];
    }
  }

  void _trim() {
    if (_items.length <= maxPrinters) return;
    _items.sort((a, b) => b.lastAt.compareTo(a.lastAt));
    _items = _items.take(maxPrinters).toList();
  }

  void _save() => AgentStore.set(
    _storageKey,
    jsonEncode([for (final e in _items) e.toJson()]),
  );

  static DesktopPrinter _normalized(DesktopPrinter p) => DesktopPrinter(
    kind: AgentPrinterKind.lan,
    address: p.address.trim(),
    name: p.name.trim().isEmpty ? unnamed : p.name.trim(),
    id: p.id,
    mac: p.mac,
  );

  /// Thông tin mới của lệnh vừa in, giữ cái cũ khi lệnh không báo.
  static DesktopPrinter _merge(DesktopPrinter old, DesktopPrinter p) =>
      DesktopPrinter(
        kind: AgentPrinterKind.lan,
        address: p.address.trim(),
        name: p.name.trim().isEmpty ? old.name : p.name.trim(),
        id: p.id ?? old.id,
        mac: (p.mac == null || p.mac!.isEmpty) ? old.mac : p.mac,
      );
}

class _Entry {
  const _Entry(this.printer, this.lastAt);

  final DesktopPrinter printer;
  final DateTime lastAt;

  /// Cùng máy in: cùng mã máy in (máy gửi báo), không có mã thì cùng IP.
  bool matches(DesktopPrinter p) {
    final id = printer.id;
    if (id != null && p.id != null) return '$id' == '${p.id}';
    return printer.address == p.address.trim();
  }

  bool sameAs(DesktopPrinter p) =>
      printer.address == p.address &&
      printer.name == p.name &&
      '${printer.id}' == '${p.id}' &&
      printer.mac == p.mac;

  Map<String, Object?> toJson() => {
    'address': printer.address,
    'name': printer.name,
    if (printer.id != null) 'id': printer.id,
    if (printer.mac != null) 'mac': printer.mac,
    'at': lastAt.millisecondsSinceEpoch,
  };

  static _Entry? fromJson(Map<Object?, Object?> m) {
    final address = m['address'];
    final at = m['at'];
    if (address is! String || address.isEmpty || at is! int) return null;
    return _Entry(
      DesktopPrinter(
        kind: AgentPrinterKind.lan,
        address: address,
        name: m['name']?.toString() ?? DesktopLanPrinters.unnamed,
        id: m['id'],
        mac: m['mac']?.toString(),
      ),
      DateTime.fromMillisecondsSinceEpoch(at),
    );
  }
}
