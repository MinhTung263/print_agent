import 'dart:async';

import 'package:flutter/material.dart';

import '../../../printers/printer_discovery.dart';
import '../../agent_theme.dart';
import 'ip_octets_field.dart';

/// "Nhập IP thủ công" (thu gọn mặc định): 4 ô số như app EasyPOS → kiểm tra
/// kết nối cổng in → kết nối được thì [onFound] (thêm vào danh sách và chọn).
class ManualIpField extends StatefulWidget {
  const ManualIpField({
    super.key,
    required this.discovery,
    required this.onFound,
  });

  final PrinterDiscovery discovery;

  /// IP đã kết nối được.
  final ValueChanged<String> onFound;

  @override
  State<ManualIpField> createState() => _ManualIpFieldState();
}

enum _Check { idle, checking, ok, failed }

class _ManualIpFieldState extends State<ManualIpField> {
  bool _open = false;
  String? _ip;
  _Check _check = _Check.idle;

  Future<void> _test() async {
    final ip = _ip;
    if (ip == null) return;
    setState(() => _check = _Check.checking);
    final ok = await widget.discovery.reachable(ip);
    if (!mounted) return;
    setState(() => _check = ok ? _Check.ok : _Check.failed);
    if (ok) widget.onFound(ip);
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
      _Check.idle => ('Ví dụ: 192.168.1.42', AgentColors.textSecondary),
      _Check.checking => ('Đang kiểm tra kết nối…', AgentColors.textSecondary),
      _Check.ok => (
        'Kết nối được — đã thêm vào danh sách',
        AgentColors.success,
      ),
      _Check.failed => (
        'Không kết nối được. Kiểm tra máy in đã bật và cùng mạng với máy này',
        AgentColors.error,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AgentColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AgentColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Địa chỉ IP',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          IpOctetsField(
            prefill: widget.discovery.localIp,
            onChanged: (ip) => setState(() {
              _ip = ip;
              _check = _Check.idle;
            }),
            onSubmitted: () => unawaited(_test()),
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: _ip == null || _check == _Check.checking
                  ? null
                  : () => unawaited(_test()),
              child: _check == _Check.checking
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kiểm tra kết nối'),
            ),
          ),
        ],
      ),
    );
  }
}
