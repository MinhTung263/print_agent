import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart' show Obx;

import '../../agent/agent_config.dart' show PaperSize, PrinterType;
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
          AppText(
            'Loại máy in được nhận tự động lúc thêm. Muốn đổi loại: xoá máy in này '
            'rồi thêm lại.',
            variant: .caption,
            tone: .secondary,
            maxLines: 3,
          ),
          if (connected) _BeepButton(agent: agent, address: address),
          const AppDivider(),
          if (isLabel)
            LabelCalibrationPanel(
              agent: agent,
              address: address,
              connected: connected,
            )
          else ...[
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
            if (connected)
              _TestPrintButton(agent: agent, address: address)
            else
              const _OfflineNote(),
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
                CupertinoSwitch(
                  value: s.autoCut,
                  activeTrackColor: AppColors.primaryBlueBase,
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
                CupertinoSwitch(
                  value: s.beep,
                  activeTrackColor: AppColors.primaryBlueBase,
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

/// "In thử" của máy hoá đơn (máy tem có "In tem thử" trong phần căn chỉnh).
class _TestPrintButton extends StatefulWidget {
  const _TestPrintButton({required this.agent, required this.address});

  final DesktopAgent agent;
  final String address;

  @override
  State<_TestPrintButton> createState() => _TestPrintButtonState();
}

class _TestPrintButtonState extends State<_TestPrintButton> {
  bool _busy = false;

  Future<void> _print() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final error = await widget.agent.printTestTo(widget.address);
    if (!mounted) return;
    setState(() => _busy = false);
    // In được thì không báo gì (tờ giấy ra là đủ); chỉ báo khi LỖI để biết vì sao.
    if (error == null) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.errorRed,
        duration: const Duration(seconds: 10),
        content: Text(error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: _busy ? null : () => unawaited(_print()),
      icon: _busy
          ? AgentSpinner(size: 16, color: Colors.white)
          : const Icon(Icons.print_rounded, size: 18),
      label: const Text('In thử'),
    ),
  );
}

/// Máy in chưa kết nối: không in thử được — kết nối lại thì nút in thử tự hiện.
class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) => const AppText(
    'Máy in chưa kết nối nên chưa in thử được. Nút "In thử" sẽ hiện lại khi máy in '
    'kết nối.',
    variant: .caption,
    tone: .secondary,
    maxLines: 3,
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
