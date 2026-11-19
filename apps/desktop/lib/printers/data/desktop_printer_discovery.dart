import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:print_agent/print_agent.dart' show AgentJobErrorText;
import 'package:print_agent_core/print_agent_core.dart' show PrintRelayClient;
import 'package:printer_label/desktop.dart';
import 'package:printer_label/printer_label.dart' show PrinterLabel;

import '../../agent/agent_printer.dart';
import '../../agent/printer_type.dart';
import '../lan_dhcp_auto_enable.dart';
import '../printer_discovery.dart';
import '../printer_option.dart';
import '../printer_beep_plan.dart';
import '../printer_type_detector.dart';
import '../usb_printer_relevance.dart';

/// [PrinterDiscovery] bằng plugin printer_label: quét cổng 9100 trong các dải
/// mạng của máy, máy in USB theo hệ điều hành (Linux usblp, Windows hàng in
/// RAW, macOS CUPS), tên model qua SNMP / mDNS...
class DesktopPrinterDiscovery implements ProgressivePrinterDiscovery {
  const DesktopPrinterDiscovery();

  @override
  Future<List<PrinterOption>> find() async {
    final results = await Future.wait([
      LanPrinterScanner.scan(),
      if (UsbPrinters.supported) UsbPrinters.list(),
    ]);
    return _compose(
      results.length > 1
          ? await _usableUsb(results[1] as List<UsbPrinterInfo>)
          : const <UsbPrinterInfo>[],
      results[0] as List<LanPrinterFound>,
    );
  }

  List<PrinterOption> _compose(
    List<UsbPrinterInfo> usb,
    List<LanPrinterFound> lan,
  ) => [
    for (final p in usb) _usbOption(p),
    for (final p in lan)
      PrinterOption.lan(
        p.address,
        mac: p.mac,
        hardBlock: p.issue == LanPrinterIssue.ipConflict,
        warning: switch (p.issue) {
          LanPrinterIssue.none => null,
          LanPrinterIssue.ipConflict =>
            'IP đang bị thiết bị khác dùng — cần đổi IP máy in',
          LanPrinterIssue.unreachable =>
            'Chưa kết nối được tới cổng in — bấm loa để thử bíp và xem lý do (IP bị thiết bị khác dùng, máy in tắt hoặc khác mạng), vẫn thêm được',
        },
      ),
  ];

  /// Chỉ giữ máy in USB in được phiếu / tem: bỏ máy in văn phòng và khổ lớn (HP Designjet...), hàng in ảo
  /// (PDF, XPS, OneNote, Fax...) — "USB rác" làm khách rối. Tên đủ kết luận thì khỏi hỏi máy; tên
  /// chưa rõ thì đọc chuỗi định danh IEEE 1284 của máy (chờ tối đa 2 giây mỗi máy, các máy song song).
  /// Máy đọc không được gì: giữ (bỏ nhầm máy thật tệ hơn hiện thừa).
  Future<List<UsbPrinterInfo>> _usableUsb(List<UsbPrinterInfo> list) async {
    final keep = await Future.wait([
      for (final p in list)
        () async {
          final byName = UsbPrinterRelevance.decidedByName(p.name);
          if (byName != null) return byName;
          // Chưa cài (Windows): chưa có gì để hỏi.
          if (p.address.isEmpty) return true;
          String? id;
          try {
            id = await UsbPrinters.deviceId(
              p.address,
            ).timeout(const Duration(seconds: 2));
          } catch (_) {}
          return UsbPrinterRelevance.isUsable(p.name, deviceId: id);
        }(),
    ]);
    return [
      for (var i = 0; i < list.length; i++)
        if (keep[i]) list[i],
    ];
  }

  @override
  Future<List<String>> usbHints() async {
    try {
      return [for (final i in await UsbPrinters.issues()) '$i'];
    } catch (_) {
      return const [];
    }
  }

  PrinterOption _usbOption(UsbPrinterInfo p) => PrinterOption.usb(
    address: p.address,
    name: p.name,
    setupPort: p.setupPort,
  );

  @override
  Stream<List<PrinterOption>> findStream() {
    final out = StreamController<List<PrinterOption>>();
    unawaited(() async {
      var usb = <PrinterOption>[];
      final lanNow = <PrinterOption>[];
      void emit() {
        if (!out.isClosed) out.add([...usb, ...lanNow]);
      }

      try {
        // Máy USB chỉ hỏi hệ điều hành: nhanh, hiện trước khi quét mạng xong.
        final usbFuture = UsbPrinters.supported
            ? UsbPrinters.list().then(_usableUsb).then((list) {
                usb = [for (final p in list) _usbOption(p)];
                emit();
                return list;
              })
            : Future.value(const <UsbPrinterInfo>[]);
        // Máy in mạng: báo ngay khi một máy trả lời cổng in (chưa có kết quả ghép UDP / trùng IP).
        final lanFuture = LanPrinterScanner.scan(
          onFound: (f) {
            lanNow.add(PrinterOption.lan(f.address));
            emit();
          },
        );
        final results = await Future.wait<Object>([usbFuture, lanFuture]);
        // Kết quả cuối (đầy đủ, đã ghép UDP, cảnh báo trùng IP) thay các thẻ tạm.
        out.add(
          _compose(
            results[0] as List<UsbPrinterInfo>,
            results[1] as List<LanPrinterFound>,
          ),
        );
      } catch (e, s) {
        if (!out.isClosed) out.addError(e, s);
      } finally {
        await out.close();
      }
    }());
    return out.stream;
  }

  @override
  PrinterOption missing(String address) => UsbPrinters.isLocal(address)
      ? PrinterOption.usb(
          address: address,
          name: UsbPrinters.label(address),
          missing: true,
        )
      : PrinterOption.lan(address);

  @override
  Future<String?> modelOf(String address) async {
    try {
      final host = parsePrinterAddress(address)?.$1 ?? address;
      final name = await PrinterLabel.getLanPrinterName(host);
      return (name ?? '').trim().isEmpty ? null : name!.trim();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DhcpEnsureResult> ensureDhcp(String address) async {
    if (UsbPrinters.isLocal(address)) return DhcpEnsureResult(address);
    final parsed = parsePrinterAddress(address);
    if (parsed == null) return DhcpEnsureResult(address);
    final (ip, port) = parsed;
    final r = await LanDhcpAutoEnable.instance.ensure(ip);
    final next = r.ip == ip ? address : (port == 9100 ? r.ip : '${r.ip}:$port');
    return DhcpEnsureResult(next, enabled: r.enabled, failed: r.failed);
  }

  /// Bảng ARP đọc chung cho cả lượt quét: đọc bảng là chạy một tiến trình `arp` — máy yếu mà quét ra nhiều
  /// máy in thì mỗi máy một tiến trình rất tốn. Giữ vài giây rồi đọc lại (máy mới thấy cần MAC mới).
  static Map<String, String> _arpCache = const {};
  static DateTime _arpAt = DateTime.fromMillisecondsSinceEpoch(0);
  static Future<Map<String, String>>? _arpLoading;

  static Future<Map<String, String>> _arp() {
    if (DateTime.now().difference(_arpAt) < const Duration(seconds: 3)) {
      return Future.value(_arpCache);
    }
    return _arpLoading ??= ArpTable.read()
        .then((t) {
          _arpCache = t;
          _arpAt = DateTime.now();
          return t;
        })
        .whenComplete(() {
          _arpLoading = null;
        });
  }

  @override
  Future<String?> macOf(String address) async {
    try {
      final host = parsePrinterAddress(address)?.$1 ?? address;
      return (await _arp())[host];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PrinterType?> typeOf(String address, {String? model}) async {
    // Máy USB: loại máy tự báo trong chuỗi định danh IEEE 1284 (`CMD:TSPL2` / `CMD:ESC/POS`).
    if (UsbPrinters.isLocal(address)) {
      final id = await UsbPrinters.deviceId(address);
      final language = id == null
          ? null
          : PrinterLanguageProbe.fromIeee1284(id);
      return PrinterTypeDetector.decide(
        language: language,
        model: model ?? (id == null ? null : Ieee1284.name(id)),
      ).type;
    }
    final parsed = parsePrinterAddress(address);
    if (parsed == null) return null;
    PrinterLanguage? language;
    try {
      language = await PrinterLanguageProbe.probeLan(
        parsed.$1,
        port: parsed.$2,
      );
    } catch (_) {}
    return PrinterTypeDetector.decide(language: language, model: model).type;
  }

  @override
  Future<String?> beep(
    String address, {
    PrinterType? type,
    int attempt = 0,
  }) async {
    final style = PrinterBeepPlan.styleFor(type, attempt);
    final failure = await AgentPrinter.beep(
      address,
      label: type == PrinterType.label,
      style: style,
    );
    if (failure == null) return null;
    // Máy LAN không bíp được: nói đúng vì sao (IP đang do thiết bị khác dùng, cổng in
    // đóng, khác mạng...) thay vì "máy in bận" chung chung.
    final why = await _explainLan(address);
    return why ??
        AgentJobErrorText.message(failure.error, detail: failure.detail);
  }

  Future<String?> _explainLan(String address) async {
    if (UsbPrinters.isLocal(address)) return null;
    final parsed = parsePrinterAddress(address);
    if (parsed == null) return null;
    final (ip, port) = parsed;
    final open = await LanPrinterScanner.probe(
      ip,
      port: port,
      timeout: const Duration(milliseconds: 800),
    );
    if (open) return null; // cổng in mở: lỗi khác, giữ thông báo gốc
    final mac = await ArpTable.macOf(ip);
    return explainUnreachableLan(
      ip: ip,
      port: port,
      mac: mac,
      sameSubnet: await PrintRelayClient.isOnSameSubnet(ip),
    );
  }

  /// Vì sao máy in LAN [ip] không nhận lệnh (cổng [port] không mở). Thuần — kiểm thử được.
  ///
  /// - Khác dải mạng với máy này → "khác mạng".
  /// - Cùng dải mà có thiết bị trả lời ARP (có [mac]) nhưng cổng in đóng: IP đang do thiết bị
  ///   khác dùng. MAC "ngẫu nhiên" (bit 0x02 của byte đầu) là điện thoại / máy tính bảng
  ///   dùng địa chỉ Wi-Fi riêng tư — chắc chắn không phải máy in.
  /// - Không ai trả lời → máy in tắt / ngắt mạng.
  @visibleForTesting
  static String explainUnreachableLan({
    required String ip,
    required int port,
    required String? mac,
    required bool sameSubnet,
  }) {
    if (!sameSubnet) {
      return 'Máy này không cùng dải mạng với $ip — nối máy tính vào cùng Wi-Fi / mạng '
          'dây với máy in rồi thử lại.';
    }
    if (mac != null && mac.isNotEmpty) {
      final first = int.tryParse(mac.split(RegExp('[:-]')).first, radix: 16);
      final randomMac = first != null && first & 0x02 != 0;
      return randomMac
          ? 'Địa chỉ $ip đang do một thiết bị khác (điện thoại / máy tính bảng, MAC $mac) '
                'dùng, không phải máy in nên không bíp được. Đổi IP của máy in sang địa chỉ '
                'khác rồi thử lại.'
          : 'Có thiết bị ($mac) trả lời ở $ip nhưng không nhận lệnh in (cổng $port đóng). '
                'Có thể không phải máy in hoặc IP bị trùng — kiểm tra lại IP máy in.';
    }
    return 'Không có thiết bị nào trả lời ở $ip — máy in đang tắt, chưa nối mạng hoặc đã '
        'đổi IP. Máy in đã bật và nối mạng mà vẫn không thấy: Wi-Fi có thể đang bật "cách ly '
        'thiết bị" (AP Isolation / mạng khách) — tắt tuỳ chọn đó trên router hoặc cắm dây mạng '
        'cho máy tính.';
  }

  @override
  Future<String?> setupUsb(String setupPort) => UsbPrinters.setup(setupPort);

  @override
  String? get setupError => UsbPrinters.lastSetupError;

  /// [address] là `ip` hoặc `ip:cổng` (máy in tem hay dùng cổng khác 9100).
  @override
  Future<bool> reachable(String address) {
    final parsed = parsePrinterAddress(address);
    if (parsed == null) return Future.value(false);
    return LanPrinterScanner.probe(
      parsed.$1,
      port: parsed.$2,
      timeout: const Duration(seconds: 2),
    );
  }

  @override
  Future<List<String>> scannedNetworks() async {
    final out = <String>{};
    try {
      for (final nic in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      )) {
        for (final a in nic.addresses) {
          if (a.isLoopback || a.isLinkLocal) continue;
          final p = a.address.split('.');
          if (p.length == 4) out.add('${p.take(3).join('.')}.x');
        }
      }
    } catch (_) {}
    return out.toList()..sort();
  }

  @override
  Future<String?> localIp() async {
    try {
      for (final nic in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      )) {
        for (final a in nic.addresses) {
          final p = a.address.split('.');
          if (p.length != 4) continue;
          final second = int.tryParse(p[1]) ?? 0;
          if (p[0] == '10' ||
              (p[0] == '192' && p[1] == '168') ||
              (p[0] == '172' && second >= 16 && second <= 31)) {
            return a.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
