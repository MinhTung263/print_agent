import 'dart:async';

import 'package:flutter/material.dart';
import 'package:printer_label/desktop.dart';

import '../../agent_theme.dart';

/// "Nhập IP thủ công" (thu gọn mặc định): nhập IP → kiểm tra kết nối cổng in
/// ngay → kết nối được thì [onFound] (thêm vào danh sách và chọn luôn).
class ManualIpField extends StatefulWidget {
  const ManualIpField({super.key, required this.onFound});

  /// Địa chỉ chuẩn (`ip` / `ip:cổng`) đã kết nối được.
  final ValueChanged<String> onFound;

  @override
  State<ManualIpField> createState() => _ManualIpFieldState();
}

enum _Check { idle, checking, ok, failed, invalid }

class _ManualIpFieldState extends State<ManualIpField> {
  final _input = TextEditingController();
  bool _open = false;
  _Check _check = _Check.idle;

  static final RegExp _ipv4 = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
  );

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final parsed = parsePrinterAddress(_input.text);
    final host = parsed?.$1 ?? '';
    final m = _ipv4.firstMatch(host);
    if (parsed == null ||
        m == null ||
        [1, 2, 3, 4].any((i) => int.parse(m.group(i)!) > 255)) {
      setState(() => _check = _Check.invalid);
      return;
    }
    setState(() => _check = _Check.checking);
    final ok = await LanPrinterScanner.probe(
      host,
      port: parsed.$2,
      timeout: const Duration(seconds: 2),
    );
    if (!mounted) return;
    setState(() => _check = ok ? _Check.ok : _Check.failed);
    if (ok) widget.onFound(parsed.$2 == 9100 ? host : '$host:${parsed.$2}');
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _open = true),
          icon: const Icon(Icons.keyboard_rounded, size: 18),
          label: const Text('Không thấy máy in? Nhập IP thủ công'),
        ),
      );
    }
    final (message, color) = switch (_check) {
      _Check.idle => ('Xem IP trên phiếu tự in của máy in', AgentColors.muted),
      _Check.checking => ('Đang kiểm tra kết nối…', AgentColors.textSecondary),
      _Check.ok => (
        'Kết nối được — đã thêm vào danh sách',
        AgentColors.success,
      ),
      _Check.failed => (
        'Không kết nối được. Kiểm tra máy in đã bật và cùng mạng với máy này',
        AgentColors.error,
      ),
      _Check.invalid => (
        'IP chưa đúng, VD 192.168.1.100 hoặc 192.168.1.100:9100',
        AgentColors.error,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '192.168.1.100',
                  prefixIcon: Icon(Icons.lan_outlined, size: 20),
                ),
                onChanged: (_) {
                  if (_check != _Check.idle) {
                    setState(() => _check = _Check.idle);
                  }
                },
                onSubmitted: (_) => unawaited(_test()),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _check == _Check.checking
                  ? null
                  : () => unawaited(_test()),
              child: _check == _Check.checking
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kiểm tra'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(message, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
