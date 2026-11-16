import 'package:print_agent/src/agent_domain.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/presentation/widgets/sheets/agent_wifi_switch_sheet.dart';

/// "Kết nối lại" một máy in lỗi của máy Agent: chạy ngay khi mở, hiện từng bước
/// đang làm ([AgentPrinterReconnect]), xong thì báo kết quả + bước nên làm tiếp
/// (chuyển Wi-Fi, cắm lại cáp, thử lại...).
class AgentReconnectSheet extends StatefulWidget {
  const AgentReconnectSheet({super.key, required this.printer});

  final AgentPrinterRef printer;

  /// Trả `true` khi đã kết nối lại được.
  static Future<bool> show(AgentPrinterRef printer) async =>
      await BaseBottomSheet.show<bool>(
        body: AgentReconnectSheet(printer: printer),
        headerTitle: LocaleKeys.printerSetting_agentReconnectTitle,
        allowOffline: true,
      ) ??
      false;

  @override
  State<AgentReconnectSheet> createState() => _AgentReconnectSheetState();
}

class _AgentReconnectSheetState extends State<AgentReconnectSheet> {
  late AgentPrinterRef _printer = widget.printer;
  final List<ReconnectStep> _steps = [];
  ReconnectResult<AgentPrinterRef>? _result;

  bool get _running => _result == null;

  @override
  void initState() {
    super.initState();
    // Chạy sau khung hình đầu: không đổi trạng thái (Rx / setState) giữa lúc
    // đang dựng bảng.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_run());
    });
  }

  Future<void> _run() async {
    setState(() {
      _steps.clear();
      _result = null;
    });
    ReconnectResult<AgentPrinterRef> result;
    try {
      result = await PrintAgentUi.station.reconnect.run(
        _printer,
        onStep: (step) {
          if (!mounted) return;
          // Bước kỹ thuật cùng chữ (thử IP, tìm theo MAC): chỉ hiện một dòng.
          if (_steps.isNotEmpty && _stepText(_steps.last) == _stepText(step)) {
            return;
          }
          setState(() => _steps.add(step));
        },
      );
    } catch (e) {
      PrintAgentModule.host.log(
        '[AGENT] Kết nối lại ${_printer.nameOrNull} lỗi: $e',
      );
      result = ReconnectResult<AgentPrinterRef>(
        ReconnectOutcome.notFound,
        printer: _printer,
      );
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _printer = result.printer ?? _printer;
    });
  }

  Future<void> _switchWifi() async {
    if (await AgentWifiSwitchSheet.show([_printer])) await _run();
  }

  String _stepText(ReconnectStep step) => switch (step) {
    ReconnectStep.checkNetwork =>
      LocaleKeys.printerSetting_agentReconnectStepNetwork.tr,
    ReconnectStep.tryIp => LocaleKeys.printerSetting_agentReconnectStepFind.tr,
    ReconnectStep.searchMac =>
      LocaleKeys.printerSetting_agentReconnectStepFind.tr,
    ReconnectStep.restartBuiltIn =>
      LocaleKeys.printerSetting_agentReconnectStepBuiltIn.tr,
    ReconnectStep.checkUsb =>
      LocaleKeys.printerSetting_agentReconnectStepUsb.tr,
  };

  String _resultText(ReconnectResult<AgentPrinterRef> r) => switch (r.outcome) {
    ReconnectOutcome.connected => LocaleKeys.printerSetting_agentReconnectOkTr(
      printer: _printer.nameOrNull ?? '',
    ),
    ReconnectOutcome.relocated =>
      LocaleKeys.printerSetting_agentReconnectMovedTr(
        oldIp: r.oldIp ?? '',
        newIp: r.printer?.refAddress ?? '',
      ),
    ReconnectOutcome.otherNetwork =>
      r.ssid != null
          ? LocaleKeys.printerSetting_agentReconnectOtherWifiTr(wifi: r.ssid!)
          : LocaleKeys.printerSetting_agentReconnectOtherNet.tr,
    ReconnectOutcome.busy => LocaleKeys.printerSetting_agentReconnectBusy.tr,
    ReconnectOutcome.usbUnplugged =>
      LocaleKeys.printerSetting_agentReconnectUsb.tr,
    ReconnectOutcome.builtInFailed =>
      LocaleKeys.printerSetting_agentReconnectBuiltIn.tr,
    ReconnectOutcome.notFound =>
      (_printer.refMac?.isNotEmpty ?? false)
          ? LocaleKeys.printerSetting_agentReconnectNotFound.tr
          : LocaleKeys.printerSetting_agentReconnectNotFoundNoMac.tr,
  };

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return AppPadding.all(
      AppSpace.lg,
      child: AppColumn(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.md,
        children: [
          AppText.raw(
            [?_printer.nameOrNull, ?_printer.refAddress].join(' · '),
            variant: .title,
            maxLines: 2,
          ),
          for (var i = 0; i < _steps.length; i++)
            _StepRow(
              text: _stepText(_steps[i]),
              state: i < _steps.length - 1
                  ? _StepState.done
                  : (_running
                        ? _StepState.running
                        : (result!.ok ? _StepState.done : _StepState.failed)),
            ),
          if (result != null) ...[
            _ResultBox(ok: result.ok, text: _resultText(result)),
            _ResultActions(
              result: result,
              onDone: () => Get.back<bool>(result: true),
              onRetry: () => unawaited(_run()),
              onSwitchWifi: () => unawaited(_switchWifi()),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nút sau khi có kết quả: Xong / Chuyển Wi-Fi (+ Thử lại) / Thử lại.
class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.result,
    required this.onDone,
    required this.onRetry,
    required this.onSwitchWifi,
  });

  final ReconnectResult<AgentPrinterRef> result;
  final VoidCallback onDone;
  final VoidCallback onRetry;
  final VoidCallback onSwitchWifi;

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r.ok) {
      return BaseButton(
        onPressed: onDone,
        title: LocaleKeys.printerSetting_agentReconnectDone,
        backgroundColor: AppColors.primaryBlueBase,
      );
    }
    if (r.outcome != ReconnectOutcome.otherNetwork) {
      return BaseButton(
        onPressed: onRetry,
        title: LocaleKeys.printerSetting_agentReconnectRetry,
        backgroundColor: AppColors.primaryBlueBase,
      );
    }
    // Khác mạng: chuyển sang Wi-Fi của máy in (đã nhớ), không thì mở cài đặt.
    return AppColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.sm,
      children: [
        BaseButton(
          onPressed: r.ssid != null
              ? onSwitchWifi
              : () => unawaited(PrintAgentUi.station.wifi.openSettings()),
          title: r.ssid != null
              ? LocaleKeys.printerSetting_switchWifi
              : LocaleKeys.printerSetting_agentWifiOpenSettings,
          backgroundColor: AppColors.primaryBlueBase,
        ),
        BaseTap(
          onTap: onRetry,
          child: const AppPadding.symmetric(
            vertical: AppSpace.sm,
            child: AppText(
              LocaleKeys.printerSetting_agentReconnectRetry,
              textAlign: TextAlign.center,
              textColor: AppColors.primaryBlueBase,
            ),
          ),
        ),
      ],
    );
  }
}

enum _StepState { running, done, failed }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.text, required this.state});

  final String text;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    return AppRow(
      spacing: AppSpace.sm,
      children: [
        SizedBox.square(
          dimension: 20,
          child: switch (state) {
            _StepState.running => Padding(
              padding: const EdgeInsets.all(2),
              child: PrintAgentUi.kit.spinner(size: 16),
            ),
            _StepState.done => const Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: AppColors.successGreen,
            ),
            _StepState.failed => const Icon(
              Icons.cancel_rounded,
              size: 20,
              color: AppColors.errorRed,
            ),
          },
        ),
        Expanded(child: AppText.raw(text, maxLines: 2)),
      ],
    );
  }
}

class _ResultBox extends StatelessWidget {
  const _ResultBox({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.successGreen : AppColors.errorRed;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: AppRow(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpace.sm,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.info_rounded,
            color: color,
          ),
          Expanded(child: AppText.raw(text, maxLines: 5)),
        ],
      ),
    );
  }
}
