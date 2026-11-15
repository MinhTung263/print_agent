import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/domain/entities/agent_test_print_result.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Nút "In thử" trong chi tiết máy in: bấm là in một phiếu thử ra đúng máy in
/// đó; trong lúc in hiện vòng xoay (không bấm lại được), xong báo kết quả.
class AgentTestPrintButton extends StatefulWidget {
  const AgentTestPrintButton({
    super.key,
    required this.name,
    required this.onTestPrint,
  });

  final String name;
  final Future<AgentTestPrintResult> Function() onTestPrint;

  @override
  State<AgentTestPrintButton> createState() => _AgentTestPrintButtonState();
}

class _AgentTestPrintButtonState extends State<AgentTestPrintButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    AgentTestPrintResult result;
    try {
      result = await widget.onTestPrint();
    } catch (_) {
      result = AgentTestPrintResult.failed;
    }
    if (mounted) setState(() => _busy = false);
    final n = widget.name;
    final (message, type) = switch (result) {
      AgentTestPrintResult.done => (
        LocaleKeys.printerSetting_agentTestPrintDoneTr(printer: n),
        AppNotificationType.success,
      ),
      AgentTestPrintResult.held => (
        LocaleKeys.printerSetting_agentTestPrintHeldTr(printer: n),
        AppNotificationType.warning,
      ),
      AgentTestPrintResult.failed => (
        LocaleKeys.printerSetting_agentTestPrintFailedTr(printer: n),
        AppNotificationType.error,
      ),
      AgentTestPrintResult.offline => (
        LocaleKeys.printerSetting_agentTestPrintOfflineTr(printer: n),
        AppNotificationType.error,
      ),
    };
    unawaited(AppNotification.show(message: message, type: type));
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard.section(
      child: AppRow(
        spacing: AppSpace.md,
        children: [
          const Expanded(
            child: AppColumn(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                AppText(
                  LocaleKeys.printerSetting_agentTestPrint,
                  variant: .title,
                ),
                AppText(
                  LocaleKeys.printerSetting_agentTestPrintHint,
                  variant: .caption,
                  tone: .secondary,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 112,
            height: 44,
            child: _busy
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlueBase.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : PrintAgentUi.kit.button(
                    title: LocaleKeys.printerSetting_agentTestPrint,
                    onPressed: () => unawaited(_run()),
                    backgroundColor: AppColors.primaryBlueBase,
                  ),
          ),
        ],
      ),
    );
  }
}
