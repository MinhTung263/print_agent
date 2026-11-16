import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/print_agent.dart'
    show AgentNoticeLevel, PrintAgentModule;
import '../widgets/agent_spinner.dart';

import '../agent_theme.dart';
import 'printer_picker/manual_ip_field.dart';
import 'printer_picker/printer_picker_parts.dart';
import '../../printers/data/desktop_printer_discovery.dart';
import '../../printers/printer_discovery.dart';
import '../../printers/printer_option.dart';
import '../../printers/printer_picker_list.dart';
import 'printer_picker/printer_option_tile.dart';

/// Chọn máy in của trạm in: tự dò CÙNG LÚC máy in mạng (cổng 9100) và máy in
/// cắm USB, hiện chung một danh sách thẻ — bấm chọn rồi "Dùng máy in này".
/// Chỉ có một máy in thì chọn sẵn. Không thấy thì nhập IP (kiểm tra kết nối
/// trước khi thêm).
///
/// Trả địa chỉ (`ip` / `ip:cổng` / địa chỉ USB), chuỗi rỗng khi bỏ chọn,
/// `null` khi đóng.
Future<String?> showPrinterPickerDialog(
  BuildContext context, {
  String current = '',
  PrinterDiscovery discovery = const DesktopPrinterDiscovery(),
}) => showDialog<String>(
  context: context,
  builder: (_) => _PrinterPickerDialog(current: current, discovery: discovery),
);

/// Chọn NHIỀU máy in một lúc (thêm nhanh vào trạm in): tick các máy muốn thêm rồi bấm
/// "Thêm N máy in". Máy [current] (đang dùng) hiện nhưng không chọn lại được. Trả danh
/// sách địa chỉ (đã cài đặt xong với máy USB chưa cài), `null` khi đóng.
Future<List<String>?> showPrintersPickerDialog(
  BuildContext context, {
  String current = '',
  Set<String> added = const {},
  PrinterDiscovery discovery = const DesktopPrinterDiscovery(),
}) => showDialog<List<String>>(
  context: context,
  builder: (_) => _PrinterPickerDialog(
    current: current,
    added: added,
    discovery: discovery,
    multi: true,
  ),
);

class _PrinterPickerDialog extends StatefulWidget {
  const _PrinterPickerDialog({
    required this.current,
    this.added = const {},
    required this.discovery,
    this.multi = false,
  });

  final bool multi;
  final String current;

  /// Địa chỉ các máy đã thêm vào trạm (ngoài máy in chính): hiện "Đã thêm", không chọn lại.
  final Set<String> added;
  final PrinterDiscovery discovery;

  @override
  State<_PrinterPickerDialog> createState() => _PrinterPickerDialogState();
}

class _PrinterPickerDialogState extends State<_PrinterPickerDialog> {
  List<PrinterOption> _options = const [];
  final List<PrinterOption> _manual = [];
  String? _selected;

  /// Chế độ nhiều máy: các khoá đã tick.
  final Set<String> _checked = {};
  bool _scanning = false;
  bool _settingUp = false;
  List<String> _networks = const [];

  @override
  void initState() {
    super.initState();
    _selected = widget.multi || widget.current.isEmpty ? null : widget.current;
    unawaited(_scan());
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final found = await widget.discovery.find();
    final networks = await widget.discovery.scannedNetworks();
    if (!mounted) return;
    setState(() {
      _networks = networks;
      _options = found;
      _scanning = false;
      if (widget.multi) {
        // Chỉ có một máy chưa dùng thì tick sẵn.
        final free = _all
            .where((o) => !_isCurrent(o) && !_isAdded(o) && !o.blocked)
            .toList();
        if (_checked.isEmpty && free.length == 1) _checked.add(free.first.key);
      } else {
        _selected = PrinterPickerList.preselect(_all, _selected);
      }
    });
    // Tên model rồi loại máy in (tem / hoá đơn) của từng máy mạng: thẻ hiện "Xprinter
    // XP-420B · Máy in tem" ngay lúc chọn, khỏi chọn nhầm.
    for (final o in found.where((o) => o.kind == PrinterOptionKind.lan)) {
      unawaited(_identify(o.address));
    }
    // Máy USB tự báo loại (tem / hoá đơn) qua chuỗi định danh IEEE 1284.
    for (final o in found.where(
      (o) => o.kind == PrinterOptionKind.usb && o.address.isNotEmpty,
    )) {
      unawaited(_identifyUsb(o));
    }
  }

  /// Đọc model (không gửi gì vào cổng in) rồi hỏi trạng thái để biết máy in tem hay hoá
  /// đơn; cập nhật thẻ máy in ở [address].
  Future<void> _identify(String address) async {
    final model = await widget.discovery.modelOf(address);
    if (!mounted) return;
    if (model != null) {
      setState(() {
        _options = PrinterPickerList.withModel(_options, address, model);
        _manual.replaceRange(0, _manual.length, [
          for (final m in _manual)
            m.address == address
                ? PrinterOption.lan(
                    address,
                    manual: true,
                    model: model,
                    type: m.type,
                  )
                : m,
        ]);
      });
    }
    final type = await widget.discovery.typeOf(address, model: model);
    if (!mounted || type == null) return;
    setState(() {
      _options = PrinterPickerList.withType(_options, address, type);
      _manual.replaceRange(0, _manual.length, [
        for (final m in _manual) m.address == address ? m.withType(type) : m,
      ]);
    });
  }

  Future<void> _identifyUsb(PrinterOption o) async {
    final type = await widget.discovery.typeOf(o.address, model: o.title);
    if (!mounted || type == null) return;
    setState(
      () => _options = PrinterPickerList.withType(_options, o.address, type),
    );
  }

  /// Cho máy in [o] kêu bíp để nhận ra đó là máy nào.
  Future<void> _beep(PrinterOption o) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.discovery.beep(o.address, type: o.type);
    messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: error == null ? 4 : 8),
        content: Text(
          error ??
              'Đã gửi lệnh bíp tới "${o.title}". Nghe thấy tiếng bíp là đúng máy in '
                  'đó; không nghe thấy có thể máy không có còi.',
        ),
      ),
    );
  }

  List<PrinterOption> get _all => PrinterPickerList.merge(
    found: _options,
    manual: _manual,
    current: widget.current,
    missing: widget.discovery.missing,
  );

  bool _isCurrent(PrinterOption o) =>
      o.address.isNotEmpty && o.address == widget.current;

  /// Máy [o] đã có trong trạm (máy in chính hoặc máy đã thêm) — thêm lại không được.
  bool _isAdded(PrinterOption o) =>
      o.address.isNotEmpty && widget.added.contains(o.address);

  void _toggle(PrinterOption o) => setState(() {
    if (!_checked.remove(o.key)) _checked.add(o.key);
  });

  void _addManual(String address) {
    setState(() {
      if (!_all.any((o) => o.address == address)) {
        _manual.insert(0, PrinterOption.lan(address, manual: true));
      }
      if (widget.multi) {
        if (address != widget.current && !widget.added.contains(address)) {
          _checked.add(address);
        }
      } else {
        _selected = address;
      }
    });
    // Máy nhập tay cũng nhận ra model + loại như máy dò thấy.
    unawaited(_identify(address));
  }

  /// Nhiều máy: cài đặt máy USB chưa cài, trả địa chỉ các máy dùng được.
  Future<void> _confirmMany() async {
    final picked = [
      for (final o in _all)
        if (_checked.contains(o.key)) o,
    ];
    if (picked.isEmpty) return;
    setState(() => _settingUp = true);
    final addresses = <String>[];
    final failed = <String>[];
    for (final o in picked) {
      if (!o.needsSetup) {
        addresses.add(o.address);
        continue;
      }
      final address = await widget.discovery.setupUsb(o.setupPort!);
      if (address != null) {
        addresses.add(address);
      } else {
        failed.add(o.title);
      }
    }
    if (!mounted) return;
    setState(() => _settingUp = false);
    if (failed.isNotEmpty) {
      final why = widget.discovery.setupError ?? 'máy tính cần quyền quản trị';
      final text = 'Chưa cài được máy in USB ${failed.join(', ')} — $why';
      if (addresses.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
        await _scan();
        return;
      }
      PrintAgentModule.host.notify(text, level: AgentNoticeLevel.warning);
    }
    Navigator.of(context).pop(addresses);
  }

  Future<void> _confirm() async {
    if (widget.multi) return _confirmMany();
    final option = _all.where((o) => o.key == _selected).firstOrNull;
    if (option == null) return;
    if (!option.needsSetup) {
      Navigator.of(context).pop(option.address);
      return;
    }
    setState(() => _settingUp = true);
    final address = await widget.discovery.setupUsb(option.setupPort!);
    if (!mounted) return;
    setState(() => _settingUp = false);
    if (address != null) {
      Navigator.of(context).pop(address);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.discovery.setupError ??
              'Chưa cài được máy in USB này — máy tính cần quyền quản trị',
        ),
      ),
    );
    await _scan();
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    return Dialog(
      backgroundColor: AgentColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrinterPickerHeader(
                scanning: _scanning,
                onRescan: () => unawaited(_scan()),
              ),
              const SizedBox(height: 16),
              // Danh sách + nhập IP tay cuộn chung: nội dung cao (gợi ý, ô nhập IP) không
              // làm hộp tràn khỏi cửa sổ, nút "Dùng máy in này" luôn thấy.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (all.isEmpty)
                        PrinterPickerEmpty(
                          scanning: _scanning,
                          networks: _networks,
                        )
                      else
                        for (var i = 0; i < all.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          PrinterOptionTile(
                            option: all[i],
                            selected: widget.multi
                                ? _checked.contains(all[i].key)
                                : all[i].key == _selected,
                            current: _isCurrent(all[i]),
                            added: _isAdded(all[i]),
                            multi: widget.multi,
                            onBeep: all[i].address.isNotEmpty && !all[i].blocked
                                ? () => unawaited(_beep(all[i]))
                                : null,
                            // Máy đang dùng không thêm lại được.
                            onTap:
                                all[i].blocked ||
                                    (widget.multi &&
                                        (_isCurrent(all[i]) ||
                                            _isAdded(all[i])))
                                ? null
                                : () => widget.multi
                                      ? _toggle(all[i])
                                      : setState(() => _selected = all[i].key),
                          ),
                        ],
                      const SizedBox(height: 12),
                      ManualIpField(
                        discovery: widget.discovery,
                        onFound: _addManual,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.current.isNotEmpty && !widget.multi)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(''),
                      style: TextButton.styleFrom(
                        foregroundColor: AgentColors.error,
                      ),
                      child: const Text('Bỏ chọn máy in'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Huỷ'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:
                        (widget.multi ? _checked.isEmpty : _selected == null) ||
                            _settingUp
                        ? null
                        : () => unawaited(_confirm()),
                    child: _settingUp
                        ? AgentSpinner(size: 16, color: Colors.white)
                        : Text(
                            widget.multi
                                ? 'Thêm ${_checked.length} máy in'
                                : 'Dùng máy in này',
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
