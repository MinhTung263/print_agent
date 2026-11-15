import 'store_printer.dart';

/// Máy in LAN dò thấy trong mạng (mở cổng in).
class FoundPrinter {
  const FoundPrinter({required this.address, this.mac});

  /// `ip` hoặc `ip:cổng`.
  final String address;

  /// MAC (bảng ARP); `null` khi không đọc được.
  final String? mac;
}

/// Trí nhớ của việc tự thêm theo từng công ty: máy in nào đã có trong danh
/// sách cửa hàng ở lượt trước ([known]) và máy nào người dùng vừa XOÁ
/// ([removed] — có ở lượt trước, lượt này mất).
class AutoAddMemory {
  const AutoAddMemory({this.known = const {}, this.removed = const {}});

  final Set<String> known;
  final Map<String, DateTime> removed;

  Map<String, Object?> toJson() => {
    'known': known.toList(),
    'removed': {
      for (final e in removed.entries) e.key: e.value.millisecondsSinceEpoch,
    },
  };

  static AutoAddMemory fromJson(Object? raw) {
    if (raw is! Map) return const AutoAddMemory();
    final removed = raw['removed'];
    return AutoAddMemory(
      known: {
        if (raw['known'] is List)
          for (final k in raw['known'] as List) '$k',
      },
      removed: {
        if (removed is Map)
          for (final e in removed.entries)
            if (e.value is int)
              '${e.key}': DateTime.fromMillisecondsSinceEpoch(e.value as int),
      },
    );
  }
}

/// Kết quả một lượt: máy in cần tạo + trí nhớ mới.
class AutoAddResult {
  const AutoAddResult(this.toCreate, this.memory);

  final List<StorePrinter> toCreate;
  final AutoAddMemory memory;
}

/// Chọn máy in LAN cần tự thêm vào cửa hàng (không gọi mạng — test được):
///
/// - Máy in dò thấy mà danh sách cửa hàng CHƯA có (trùng MAC hoặc trùng IP
///   đều coi là đã có — không tạo trùng) → thêm, tên "Máy in mới N", mọi mẫu
///   hoá đơn, khổ K80.
/// - Máy in người dùng vừa xoá khỏi danh sách (lượt trước có, lượt này mất)
///   → không tự thêm lại trong [removedHold] (người dùng chủ ý xoá).
abstract final class PrinterAutoAddPlan {
  static const Duration removedHold = Duration(days: 7);
  static const String namePrefix = 'Máy in mới';

  static AutoAddResult plan({
    required List<FoundPrinter> found,
    required List<StorePrinter> existing,
    required AutoAddMemory memory,
    required DateTime now,
  }) {
    final lan = existing.where((p) => p.type == StorePrinter.typeLan).toList();
    final presentKeys = {for (final p in lan) ..._keysOf(p.ip, p.mac)};
    final removed = <String, DateTime>{
      for (final e in memory.removed.entries)
        if (now.difference(e.value) < removedHold) e.key: e.value,
    };
    for (final k in memory.known) {
      if (!presentKeys.contains(k)) removed.putIfAbsent(k, () => now);
    }
    for (final k in presentKeys) {
      removed.remove(k);
    }

    final names = {for (final p in existing) p.name.trim()};
    var n = 0;
    String nextName() {
      String name;
      do {
        name = '$namePrefix ${++n}';
      } while (names.contains(name));
      names.add(name);
      return name;
    }

    final toCreate = <StorePrinter>[];
    final taken = {
      for (final p in lan) ...{
        ..._keysOf(p.ip, p.mac),
        if (_ip(p.ip).isNotEmpty) 'ip:${_ip(p.ip)}',
      },
    };
    for (final f in found) {
      final ip = _ip(f.address);
      if (ip.isEmpty) continue;
      final keys = {..._keysOf(f.address, f.mac), 'ip:$ip'};
      if (keys.any(taken.contains)) continue;
      if (keys.any(removed.containsKey)) continue;
      taken.addAll(keys);
      toCreate.add(
        StorePrinter(
          name: nextName(),
          ip: f.address,
          mac: _mac(f.mac),
          templates: StorePrinter.receiptTemplates,
        ),
      );
    }
    return AutoAddResult(
      toCreate,
      AutoAddMemory(known: presentKeys, removed: removed),
    );
  }

  /// Khoá nhận ra máy in: `mac:<MAC>` (ưu tiên) và `ip:<ip>` (bỏ cổng 9100).
  static Set<String> _keysOf(String address, String? mac) {
    final m = _mac(mac);
    final ip = _ip(address);
    return {if (m != null) 'mac:$m', if (m == null && ip.isNotEmpty) 'ip:$ip'};
  }

  static String _ip(String address) {
    final s = address.trim();
    return s.endsWith(':9100') ? s.substring(0, s.length - 5) : s;
  }

  /// MAC chuẩn `AA:BB:CC:DD:EE:FF`; `null` khi không hợp lệ.
  static String? _mac(String? raw) {
    final hex = (raw ?? '').replaceAll(RegExp('[^0-9A-Fa-f]'), '');
    if (hex.length != 12 || RegExp(r'^0+$').hasMatch(hex)) return null;
    final up = hex.toUpperCase();
    return [for (var i = 0; i < 12; i += 2) up.substring(i, i + 2)].join(':');
  }
}
