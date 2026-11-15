import 'dart:async';

import 'package:flutter/material.dart';
import 'package:printer_label/desktop.dart';

import '../agent_theme.dart';
import 'printer_picker/manual_ip_field.dart';
import 'printer_picker/printer_option.dart';
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
}) => showDialog<String>(
  context: context,
  builder: (_) => _PrinterPickerDialog(current: current),
);

class _PrinterPickerDialog extends StatefulWidget {
  const _PrinterPickerDialog({required this.current});

  final String current;

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
    final results = await Future.wait([
      LanPrinterScanner.scan(),
      if (UsbPrinters.supported) UsbPrinters.list(),
    ]);
    if (!mounted) return;
    final lan = results[0] as List<LanPrinterFound>;
    final usb = results.length > 1
        ? results[1] as List<UsbPrinterInfo>
        : const <UsbPrinterInfo>[];
    final options = [
      for (final p in usb) PrinterOption.usb(p),
      for (final p in lan) PrinterOption.lan(p.address),
    ];
    // Máy in đang dùng không dò thấy (tắt / khác mạng) vẫn hiện để giữ chọn.
    final cur = widget.current;
    if (cur.isNotEmpty && !options.any((o) => o.address == cur)) {
      options.insert(
        0,
        UsbPrinters.isLocal(cur)
            ? PrinterOption(
                kind: PrinterOptionKind.usb,
                address: cur,
                title: UsbPrinters.label(cur),
                subtitle: 'Cắm USB · chưa thấy máy in',
              )
            : PrinterOption.lan(cur),
      );
    }
    options.sort(
      (a, b) => (a.address == cur ? 0 : 1) - (b.address == cur ? 0 : 1),
    );
    setState(() {
      _options = options;
      _scanning = false;
      // Chỉ một máy in: chọn sẵn.
      if (_selected == null && _all.length == 1) _selected = _all.first.key;
    });
  }

  List<PrinterOption> get _all => [
    ..._manual.where((m) => !_options.any((o) => o.key == m.key)),
    ..._options,
  ];

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
    final address = await UsbPrinters.setup(option.setupPort!);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(scanning: _scanning, onRescan: () => unawaited(_scan())),
              const SizedBox(height: 16),
              Flexible(
                child: all.isEmpty
                    ? _Empty(scanning: _scanning)
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
              ManualIpField(onFound: _addManual),
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

class _Header extends StatelessWidget {
  const _Header({required this.scanning, required this.onRescan});

  final bool scanning;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AgentColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.print_rounded, color: AgentColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn máy in',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              scanning
                  ? 'Đang tìm máy in trong mạng và cổng USB…'
                  : 'Máy bán hàng chọn "máy in của trạm in" sẽ in ra máy này',
              style: const TextStyle(
                fontSize: 13,
                color: AgentColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      scanning
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : IconButton(
              tooltip: 'Tìm lại',
              onPressed: onRescan,
              icon: const Icon(Icons.refresh_rounded),
            ),
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.scanning});

  final bool scanning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    decoration: BoxDecoration(
      color: AgentColors.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AgentColors.border),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          scanning ? Icons.radar_rounded : Icons.print_disabled_outlined,
          size: 36,
          color: AgentColors.muted,
        ),
        const SizedBox(height: 10),
        Text(
          scanning ? 'Đang tìm máy in…' : 'Chưa thấy máy in nào',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        if (!scanning) ...[
          const SizedBox(height: 4),
          const Text(
            'Bật máy in, cắm dây mạng (cùng mạng với máy này) hoặc cắm cáp '
            'USB rồi bấm tìm lại.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AgentColors.textSecondary),
          ),
        ],
      ],
    ),
  );
}
