import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/agent_spinner.dart';
import 'package:flutter/services.dart';

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
  final _port = TextEditingController(text: '9100');
  _Check _check = _Check.idle;

  @override
  void dispose() {
    _port.dispose();
    super.dispose();
  }

  /// Cổng người dùng nhập (1–65535); sai / rỗng = 9100.
  int get _portNumber {
    final n = int.tryParse(_port.text.trim());
    return n != null && n > 0 && n < 65536 ? n : 9100;
  }

  /// `ip` (cổng 9100) hoặc `ip:cổng` — dạng lưu trong cấu hình.
  String _addressOf(String ip) => _portNumber == 9100 ? ip : '$ip:$_portNumber';

  Future<void> _test() async {
    final ip = _ip;
    if (ip == null) return;
    final address = _addressOf(ip);
    setState(() => _check = _Check.checking);
    final ok = await widget.discovery.reachable(address);
    if (!mounted) return;
    setState(() => _check = ok ? _Check.ok : _Check.failed);
    if (ok) widget.onFound(address);
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
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Cổng',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '9100',
                  ),
                  onChanged: (_) => setState(() => _check = _Check.idle),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Mặc định 9100; một số máy in tem dùng cổng khác',
                  style: TextStyle(
                    fontSize: 12,
                    color: AgentColors.textSecondary,
                  ),
                ),
              ),
            ],
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
                  ? AgentSpinner(size: 16)
                  : const Text('Kiểm tra kết nối'),
            ),
          ),
        ],
      ),
    );
  }
}
