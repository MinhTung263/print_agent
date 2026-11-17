import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart' show Obx;

import 'package:print_agent/print_agent.dart'
    show AgentJobErrorText, AgentPrintFailure, AgentSwitch;

import '../../agent/agent_config.dart' show PaperSize, PrinterType;
import '../../agent/agent_printer.dart';
import '../../agent/last_label.dart';
import '../../agent/printer_settings.dart' show PrinterSettings, RibbonMode;
import '../../agent/desktop_agent.dart';
import '../ds/ds.dart';
import '../widgets/agent_spinner.dart';
import 'label_calibration_panel.dart';

/// Cài đặt của MỘT máy in, hiện trong chi tiết máy in khi bấm máy đó trên sơ đồ:
/// loại máy (hoá đơn / tem) + nhận diện lại; máy hoá đơn chọn khổ giấy, máy tem căn
/// chỉnh tem. Mỗi máy in lưu cài đặt riêng.
class PrinterSettingsPanel extends StatelessWidget {
  const PrinterSettingsPanel({
    super.key,
    required this.agent,
    required this.address,
  });

  final DesktopAgent agent;
  final String address;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: agent,
    builder: (context, _) => Obx(() {
      // Mất kết nối: ẩn nút in thử; kết nối lại là hiện lại ngay.
      final connected = agent.isPrinterConnected(address);
      final s = agent.settingsOf(address);
      final isLabel = s.type == PrinterType.label;
      return AppColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.sm,
        children: [
          const AppText('Cài đặt máy in', variant: .title),
          // Loại máy in cố định từ lúc thêm (tự nhận): muốn đổi thì xoá máy rồi thêm lại.
          AppRow(
            spacing: AppSpace.sm,
            children: [
              Icon(
                isLabel ? Icons.label_rounded : Icons.receipt_long_rounded,
                size: 20,
                color: isLabel ? AppColors.primaryBlueBase : null,
              ),
              Expanded(child: AppText(s.type.title, variant: .title)),
            ],
          ),
          if (connected) _BeepButton(agent: agent, address: address),
          if (agent.canPurgeQueue(address))
            _PurgeQueueButton(agent: agent, address: address),
          const AppDivider(),
          if (isLabel) ...[
            _LabelHeadSettings(
              agent: agent,
              address: address,
              settings: s,
              connected: connected,
            ),
            LabelCalibrationPanel(
              agent: agent,
              address: address,
              connected: connected,
            ),
          ] else ...[
            AppRow(
              children: [
                const Expanded(child: AppText('Khổ giấy')),
                CupertinoSlidingSegmentedControl<PaperSize>(
                  groupValue: s.paper,
                  children: const {
                    PaperSize.size80: Text('80mm'),
                    PaperSize.size58: Text('58mm'),
                  },
                  onValueChanged: (p) {
                    if (p != null) {
                      unawaited(
                        agent.updateSettings(address, s.copyWith(paper: p)),
                      );
                    }
                  },
                ),
              ],
            ),
            AppRow(
              spacing: AppSpace.sm,
              children: [
                const Expanded(
                  child: AppColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText('Tự động cắt giấy'),
                      AppText(
                        'Máy in tự cắt sau mỗi phiếu. Tắt nếu máy không có dao cắt hoặc bạn muốn tự xé.',
                        variant: .caption,
                        tone: .secondary,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                AgentSwitch(
                  value: s.autoCut,
                  onChanged: (v) => unawaited(
                    agent.updateSettings(address, s.copyWith(autoCut: v)),
                  ),
                ),
              ],
            ),
            AppRow(
              spacing: AppSpace.sm,
              children: [
                const Expanded(
                  child: AppColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText('Còi báo'),
                      AppText(
                        'Máy in kêu bíp khi có phiếu báo bếp. Tắt để máy in im lặng.',
                        variant: .caption,
                        tone: .secondary,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                AgentSwitch(
                  value: s.beep,
                  onChanged: (v) => unawaited(
                    agent.updateSettings(address, s.copyWith(beep: v)),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }),
  );
}

/// "Kêu bíp để nhận ra máy in": máy in kêu ngắn một lần — biết đang xem máy nào (nhiều máy cắm
/// cùng lúc). Máy không có còi thì không có tiếng.
class _BeepButton extends StatefulWidget {
  const _BeepButton({required this.agent, required this.address});

  final DesktopAgent agent;
  final String address;

  @override
  State<_BeepButton> createState() => _BeepButtonState();
}

class _BeepButtonState extends State<_BeepButton> {
  bool _busy = false;

  Future<void> _beep() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final error = await widget.agent.beepPrinter(widget.address);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: error == null ? null : AppColors.errorRed,
        duration: Duration(seconds: error == null ? 4 : 10),
        content: Text(
          error ??
              'Đã gửi lệnh bíp. Nghe thấy tiếng bíp là đúng máy in này; không nghe '
                  'thấy có thể máy không có còi.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: _busy ? null : () => unawaited(_beep()),
      icon: _busy
          ? AgentSpinner(size: 16)
          : const Icon(Icons.volume_up_rounded, size: 18),
      label: const Text('Kêu bíp để nhận ra máy in'),
    ),
  );
}

/// "Làm sạch hàng đợi": xả lệnh kẹt trong hàng đợi Windows của máy in (máy từng hết giấy / tắt
/// nguồn làm lệnh cũ kẹt, lệnh mới không ra) — thu ngân tự xử lý trong 1 giây.
class _PurgeQueueButton extends StatefulWidget {
  const _PurgeQueueButton({required this.agent, required this.address});

  final DesktopAgent agent;
  final String address;

  @override
  State<_PurgeQueueButton> createState() => _PurgeQueueButtonState();
}

class _PurgeQueueButtonState extends State<_PurgeQueueButton> {
  bool _busy = false;

  Future<void> _purge() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final error = await widget.agent.purgeQueue(widget.address);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: error == null ? null : AppColors.errorRed,
        duration: Duration(seconds: error == null ? 4 : 10),
        content: Text(error ?? 'Đã làm sạch hàng đợi máy in.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: _busy ? null : () => unawaited(_purge()),
      icon: _busy
          ? AgentSpinner(size: 16)
          : const Icon(Icons.cleaning_services_rounded, size: 18),
      label: const Text('Làm sạch hàng đợi máy in'),
    ),
  );
}

/// Đầu in của máy tem: độ phân giải (203 / 300 dpi) và ruy-băng mực. Mặc định 203dpi + không
/// gửi lệnh ruy-băng (tem trà sữa / F&B in nhiệt trực tiếp); tem vàng bạc chọn 300dpi và bật
/// ruy-băng nếu máy in bằng cuộn mực.
class _LabelHeadSettings extends StatefulWidget {
  const _LabelHeadSettings({
    required this.agent,
    required this.address,
    required this.settings,
    required this.connected,
  });

  final DesktopAgent agent;
  final String address;
  final PrinterSettings settings;

  /// Máy in đang kết nối: chưa kết nối thì ẩn nút nhận biết (cần in tem thử).
  final bool connected;

  @override
  State<_LabelHeadSettings> createState() => _LabelHeadSettingsState();
}

class _LabelHeadSettingsState extends State<_LabelHeadSettings> {
  bool _busy = false;

  DesktopAgent get agent => widget.agent;
  String get address => widget.address;
  PrinterSettings get settings => widget.settings;

  /// Khách không biết máy in 203 hay 300 dpi: máy in 2 tem thử — tem A dựng cho 203dpi, tem B
  /// cho 300dpi — khách chọn tem có khung ôm sát bốn mép (máy 300dpi: tem A bị thu nhỏ; máy
  /// 203dpi: tem B bị cắt mép). Chọn xong lưu luôn độ phân giải.
  Future<void> _detect() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final size = LastLabel.of(address);
    Future<AgentPrintFailure?> slip(int dpi) =>
        AgentPrinter.printLabelCalibration(
          address: address,
          spec: size.spec,
          gapOverrideMm: settings.gapMm,
          labelsPerRow: size.count,
          temWidthMm: size.temWidthMm,
          dpi: dpi,
          ribbon: settings.ribbon.value,
        );
    var failure = await slip(203);
    failure ??= await slip(300);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 10),
          content: Text(
            AgentJobErrorText.message(failure.error, detail: failure.detail),
          ),
        ),
      );
      return;
    }
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tem nào có khung đủ bốn cạnh?'),
        content: const Text(
          'Máy vừa in 2 tem thử: tem ra TRƯỚC là A, tem ra SAU là B.\n\n'
          'Chọn tem có khung viền ôm sát bốn mép tem — không bị cắt mất mép và không '
          'bị thu nhỏ lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Không tem nào đủ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 203),
            child: const Text('Tem A (ra trước)'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 300),
            child: const Text('Tem B (ra sau)'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (picked == null) {
      messenger.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 10),
          content: Text(
            'Chưa chọn được độ phân giải. Kiểm tra khổ tem và khe tem ở phần Căn '
            'chỉnh, rồi thử lại.',
          ),
        ),
      );
      return;
    }
    await agent.updateSettings(address, settings.copyWith(dpi: picked));
  }

  @override
  Widget build(BuildContext context) => AppColumn(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: AppSpace.sm,
    children: [
      AppRow(
        children: [
          const Expanded(child: AppText('Độ phân giải đầu in')),
          CupertinoSlidingSegmentedControl<int>(
            groupValue: settings.dpi,
            children: const {203: Text('203 dpi'), 300: Text('300 dpi')},
            onValueChanged: (v) {
              if (v != null) {
                unawaited(
                  agent.updateSettings(address, settings.copyWith(dpi: v)),
                );
              }
            },
          ),
        ],
      ),
      const AppText(
        '203 dpi: tem F&B. 300 dpi: tem vàng bạc, trang sức. Không biết thì bấm "Nhận biết tự động".',
        variant: .caption,
        tone: .secondary,
        maxLines: 3,
      ),
      if (widget.connected)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy ? null : () => unawaited(_detect()),
            icon: _busy
                ? AgentSpinner(size: 16)
                : const Icon(Icons.auto_fix_high_rounded, size: 18),
            label: const Text('Nhận biết tự động (in 2 tem thử)'),
          ),
        ),
      AppRow(
        spacing: AppSpace.sm,
        children: [
          const Expanded(
            child: AppColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText('Máy in ruy-băng mực'),
                AppText(
                  'Bật nếu tem in bằng cuộn mực (thường là tem vàng bạc).',
                  variant: .caption,
                  tone: .secondary,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          AgentSwitch(
            value: settings.ribbon == RibbonMode.on,
            onChanged: (v) => unawaited(
              agent.updateSettings(
                address,
                settings.copyWith(
                  // Tắt sau khi đã bật: gửi lệnh tắt rõ ràng (máy có thể nhớ chế độ cũ);
                  // chưa từng bật thì không gửi gì.
                  ribbon: v
                      ? RibbonMode.on
                      : (settings.ribbon == RibbonMode.on
                            ? RibbonMode.off
                            : RibbonMode.auto),
                ),
              ),
            ),
          ),
        ],
      ),
      const AppDivider(),
    ],
  );
}
