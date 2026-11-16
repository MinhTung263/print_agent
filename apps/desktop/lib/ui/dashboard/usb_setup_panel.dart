import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart'
    show AgentNoticeLevel, PrintAgentModule;

import '../../agent/desktop_agent.dart';
import '../agent_theme.dart';
import '../widgets/agent_spinner.dart';

/// Chi tiết máy USB đang cắm nhưng chưa là máy in của trạm in (bấm vào máy trên sơ
/// đồ): một nút "Cài đặt máy in" — máy chưa có hàng in thì cài luôn (macOS / Windows
/// có thể hỏi mật khẩu quản trị một lần), xong tự thêm vào trạm in.
class UsbSetupPanel extends StatefulWidget {
  const UsbSetupPanel({super.key, required this.agent, required this.address});

  final DesktopAgent agent;

  /// Địa chỉ giả `setup:...` của máy USB trên sơ đồ.
  final String address;

  @override
  State<UsbSetupPanel> createState() => _UsbSetupPanelState();
}

class _UsbSetupPanelState extends State<UsbSetupPanel> {
  bool _busy = false;
  String? _error;

  Future<void> _setup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.agent.setupUsbPrinter(widget.address);
    if (!mounted) return;
    if (error == null) {
      PrintAgentModule.host.notify(
        'Đã thêm máy in USB vào trạm in',
        level: AgentNoticeLevel.success,
      );
      Get.back<void>();
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final needsSetup =
        widget.agent.gateway.pendingByAddress(widget.address)?.needsSetup ??
        true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        Text(
          needsSetup
              ? 'Máy in USB này chưa được cài đặt trên máy tính'
              : 'Máy in USB này chưa được thêm vào trạm in',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        Text(
          needsSetup
              ? 'Bấm "Cài đặt máy in" để máy tính nhận máy in này và thêm vào trạm '
                    'in. Máy có thể hỏi mật khẩu của máy tính một lần.'
              : 'Bấm "Thêm vào trạm in" để máy bán hàng in được ra máy này.',
          style: const TextStyle(
            fontSize: 12,
            color: AgentColors.textSecondary,
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: const TextStyle(fontSize: 12, color: AgentColors.error),
          ),
        FilledButton.icon(
          onPressed: _busy ? null : () => unawaited(_setup()),
          icon: _busy
              ? AgentSpinner(size: 16, color: Colors.white)
              : const Icon(Icons.usb_rounded, size: 18),
          label: Text(needsSetup ? 'Cài đặt máy in' : 'Thêm vào trạm in'),
        ),
      ],
    );
  }
}
