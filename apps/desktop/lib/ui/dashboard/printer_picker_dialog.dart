import 'dart:async';

import 'package:flutter/material.dart';

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

class _PrinterPickerDialog extends StatefulWidget {
  const _PrinterPickerDialog({required this.current, required this.discovery});

  final String current;
  final PrinterDiscovery discovery;

  @override
  State<_PrinterPickerDialog> createState() => _PrinterPickerDialogState();
}

class _PrinterPickerDialogState extends State<_PrinterPickerDialog> {
  List<PrinterOption> _options = const [];
  final List<PrinterOption> _manual = [];
  String? _selected;
  bool _scanning = false;
  bool _settingUp = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.current.isEmpty ? null : widget.current;
    unawaited(_scan());
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final found = await widget.discovery.find();
    if (!mounted) return;
    setState(() {
      _options = found;
      _scanning = false;
      _selected = PrinterPickerList.preselect(_all, _selected);
    });
    // Tên model máy in mạng (không gửi gì vào cổng in): thẻ hiện "Xprinter
    // XP-80C" thay vì "Máy in mạng".
    for (final o in found.where((o) => o.kind == PrinterOptionKind.lan)) {
      unawaited(
        widget.discovery.modelOf(o.address).then((model) {
          if (!mounted || model == null) return;
          setState(
            () => _options = PrinterPickerList.withModel(
              _options,
              o.address,
              model,
            ),
          );
        }),
      );
    }
  }

  List<PrinterOption> get _all => PrinterPickerList.merge(
    found: _options,
    manual: _manual,
    current: widget.current,
    missing: widget.discovery.missing,
  );

  void _addManual(String address) => setState(() {
    if (!_all.any((o) => o.address == address)) {
      _manual.insert(0, PrinterOption.lan(address, manual: true));
    }
    _selected = address;
  });

  Future<void> _confirm() async {
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
      const SnackBar(
        content: Text(
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
              Flexible(
                child: all.isEmpty
                    ? PrinterPickerEmpty(scanning: _scanning)
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: all.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => PrinterOptionTile(
                          option: all[i],
                          selected: all[i].key == _selected,
                          current:
                              all[i].address.isNotEmpty &&
                              all[i].address == widget.current,
                          onTap: () => setState(() => _selected = all[i].key),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              ManualIpField(discovery: widget.discovery, onFound: _addManual),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.current.isNotEmpty)
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
                    onPressed: _selected == null || _settingUp
                        ? null
                        : () => unawaited(_confirm()),
                    child: _settingUp
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Dùng máy in này'),
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
