import 'dart:async';

import 'package:flutter/material.dart';

import 'package:printer_label/desktop.dart';
import '../ds/ds.dart';

/// Mục "Máy in USB" trong hộp thoại chọn máy in: máy in cắm vào máy tính
/// (Linux) / hàng in (Windows). Windows: cổng USB chưa có hàng in → nút "Tạo"
/// (driver có sẵn "Generic / Text Only", Windows hỏi quyền quản trị).
class UsbPrinterSection extends StatefulWidget {
  const UsbPrinterSection({
    super.key,
    required this.current,
    required this.onPick,
  });

  final String current;
  final ValueChanged<String> onPick;

  @override
  State<UsbPrinterSection> createState() => _UsbPrinterSectionState();
}

class _UsbPrinterSectionState extends State<UsbPrinterSection> {
  List<UsbPrinterInfo>? _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    final items = await UsbPrinters.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _busy = false;
    });
  }

  Future<void> _setup(String port) async {
    setState(() => _busy = true);
    final address = await WindowsRawPrinters.createRawQueue(port);
    if (!mounted) return;
    if (address != null) {
      widget.onPick(address);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Chưa tạo được hàng in cho $port')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <UsbPrinterInfo>[];
    return AppColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppRow(
          children: [
            const Expanded(child: AppText('Máy in USB', variant: .title)),
            if (_busy)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                tooltip: 'Tìm lại',
                onPressed: () => unawaited(_load()),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
          ],
        ),
        if (!_busy && items.isEmpty)
          const AppText(
            'Không thấy máy in USB nào. Cắm cáp, bật máy in rồi bấm tìm lại.',
            variant: .caption,
            tone: .secondary,
            maxLines: 3,
          ),
        for (final p in items)
          ListTile(
            dense: true,
            leading: const Icon(Icons.usb_rounded),
            title: Text(p.name),
            subtitle: Text(p.detail),
            selected: p.address.isNotEmpty && p.address == widget.current,
            trailing: p.needsSetup
                ? TextButton(
                    onPressed: _busy
                        ? null
                        : () => unawaited(_setup(p.setupPort!)),
                    child: const Text('Tạo hàng in'),
                  )
                : null,
            onTap: p.needsSetup ? null : () => widget.onPick(p.address),
          ),
      ],
    );
  }
}
