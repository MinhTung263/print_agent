import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart' show Obx;
import 'package:print_agent/print_agent.dart' show PrintAgentUi;

import '../../agent/agent_config.dart' show PrinterType;
import '../../agent/desktop_agent.dart';
import '../ds/ds.dart';
import '../widgets/agent_spinner.dart';

/// Nút "In thử" của máy in hoá đơn, đặt cùng hàng với "Xoá máy in" ở chân chi tiết máy in
/// (máy tem có "In tem thử" trong phần căn chỉnh nên không có nút này). Máy in chưa kết nối thì
/// nút mờ đi, kết nối lại là bấm được ngay.
class PrinterTestPrintAction extends StatefulWidget {
  const PrinterTestPrintAction({
    super.key,
    required this.agent,
    required this.address,
  });

  final DesktopAgent agent;
  final String address;

  /// Máy in [address] có cần nút này không: chỉ máy hoá đơn.
  static bool applies(DesktopAgent agent, String address) =>
      agent.settingsOf(address).type == PrinterType.receipt;

  @override
  State<PrinterTestPrintAction> createState() => _PrinterTestPrintActionState();
}

class _PrinterTestPrintActionState extends State<PrinterTestPrintAction> {
  bool _busy = false;

  Future<void> _print() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    final error = await widget.agent.printTestTo(widget.address);
    if (!mounted) return;
    setState(() => _busy = false);
    // In được thì không báo gì (tờ giấy ra là đủ); chỉ báo khi LỖI để biết vì sao.
    if (error == null) return;
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.errorRed,
        duration: const Duration(seconds: 10),
        content: Text(error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.agent,
    builder: (context, _) => Obx(() {
      final connected = widget.agent.isPrinterConnected(widget.address);
      return SizedBox(
        height: 44,
        child: _busy
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueBase.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: AgentSpinner(size: 20)),
              )
            : PrintAgentUi.kit.button(
                title: 'printerSetting_agentTestPrint',
                // Chưa kết nối: không in thử được.
                onPressed: connected ? () => unawaited(_print()) : null,
                backgroundColor: AppColors.primaryBlueBase,
              ),
      );
    }),
  );
}
