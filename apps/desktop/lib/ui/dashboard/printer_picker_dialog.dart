import 'dart:async';

import 'package:flutter/material.dart';

import 'package:printer_label/desktop.dart';
import '../ds/ds.dart';
import 'usb_printer_section.dart';

/// Chọn máy in của Agent: quét LAN (máy mở cổng 9100) hoặc nhập IP. Trả địa chỉ
/// (`ip` / `ip:cổng`), chuỗi rỗng khi bỏ chọn, `null` khi đóng.
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
  late final TextEditingController _input = TextEditingController(
    text: UsbPrinters.isLocal(widget.current) ? '' : widget.current,
  );
  List<LanPrinterFound>? _found;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    unawaited(_scan());
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final found = await LanPrinterScanner.scan();
    if (!mounted) return;
    setState(() {
      _found = found;
      _scanning = false;
    });
  }

  void _submit(String address) {
    if (UsbPrinters.isLocal(address)) {
      Navigator.of(context).pop(address);
      return;
    }
    final parsed = parsePrinterAddress(address);
    Navigator.of(context).pop(
      parsed == null
          ? ''
          : (parsed.$2 == 9100 ? parsed.$1 : '${parsed.$1}:${parsed.$2}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final found = _found ?? const <LanPrinterFound>[];
    return AlertDialog(
      title: const Text('Máy in của trạm in'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: AppColumn(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpace.sm,
            children: [
              AppRow(
                children: [
                  const Expanded(
                    child: AppText('Máy in LAN tìm thấy', variant: .title),
                  ),
                  if (_scanning)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      tooltip: 'Quét lại',
                      onPressed: () => unawaited(_scan()),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                ],
              ),
              if (!_scanning && found.isEmpty)
                const AppText(
                  'Không thấy máy in nào mở cổng 9100 trong mạng của máy này. '
                  'Kiểm tra máy in đã cắm mạng, cùng dải mạng, hoặc nhập IP bên dưới.',
                  variant: .caption,
                  tone: .secondary,
                  maxLines: 4,
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in found)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.print_rounded),
                        title: Text(p.address),
                        selected: p.address == widget.current,
                        onTap: () => _submit(p.address),
                      ),
                  ],
                ),
              ),
              if (UsbPrinters.supported)
                UsbPrinterSection(current: widget.current, onPick: _submit),
              TextField(
                controller: _input,
                decoration: const InputDecoration(
                  labelText: 'Hoặc nhập IP máy in',
                  hintText: '192.168.1.100 hoặc 192.168.1.100:9100',
                ),
                onSubmitted: _submit,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.current.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Bỏ chọn'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: () => _submit(_input.text),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
