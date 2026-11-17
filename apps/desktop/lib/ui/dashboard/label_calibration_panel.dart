import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/print_agent.dart'
    show AgentJobErrorText, AgentPrintFailure;
import 'package:printer_label/printer_label.dart' show LabelCalibration;

import '../../agent/agent_printer.dart';
import '../../agent/desktop_agent.dart';
import '../../agent/label_preset.dart';
import '../../agent/last_label.dart';
import '../../agent/printer_settings.dart';
import '../agent_theme.dart';
import '../ds/ds.dart';
import '../widgets/agent_spinner.dart';
import 'offset_preview_pad.dart';
import 'label_offset_text.dart';

/// Căn chỉnh tem cho MỘT máy in tem — gọn và tự động:
/// - khổ tem lấy từ lần in gần nhất (không phải chọn);
/// - "In tem thử", rồi bấm mũi tên quanh hình tem cho tới khi khung nằm sát mép tem;
/// - đổi cuộn tem: "Dò lại khe", máy tự đo khe thật của cuộn mới.
class LabelCalibrationPanel extends StatefulWidget {
  const LabelCalibrationPanel({
    super.key,
    required this.agent,
    required this.address,
    this.connected = true,
  });

  final DesktopAgent agent;
  final String address;

  /// Máy in đang kết nối: chưa kết nối thì ẩn các nút in (in thử, dò khe).
  final bool connected;

  @override
  State<LabelCalibrationPanel> createState() => _LabelCalibrationPanelState();
}

class _LabelCalibrationPanelState extends State<LabelCalibrationPanel> {
  bool _busy = false;

  PrinterSettings get _settings => widget.agent.settingsOf(widget.address);

  /// Khổ tem tự nhận từ lần in gần nhất.
  LabelPreset get _size => LastLabel.of(widget.address);

  Future<void> _nudge({double dx = 0, double dy = 0}) =>
      widget.agent.updateSettings(
        widget.address,
        _settings.withCalibration(_settings.calibration.nudge(dx: dx, dy: dy)),
      );

  Future<void> _reset() => widget.agent.updateSettings(
    widget.address,
    _settings.withCalibration(LabelCalibration.none),
  );

  Future<void> _run(
    Future<AgentPrintFailure?> Function(LabelPreset size) action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final failure = await action(_size);
    if (!mounted) return;
    setState(() => _busy = false);
    // In được thì không báo gì (tờ giấy ra là đủ); chỉ báo khi LỖI để biết vì sao.
    if (failure == null) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.errorRed,
        duration: const Duration(seconds: 10),
        content: Text(
          AgentJobErrorText.message(failure.error, detail: failure.detail),
        ),
      ),
    );
  }

  Future<AgentPrintFailure?> _slip(LabelPreset size) =>
      AgentPrinter.printLabelCalibration(
        address: widget.address,
        spec: size.spec,
        calibration: _settings.calibration,
        gapOverrideMm: _settings.gapMm,
        labelsPerRow: size.count,
        temWidthMm: size.temWidthMm,
        dpi: _settings.dpi,
        ribbon: _settings.ribbon.value,
      );

  Future<void> _printSlip() => _run((size) => _slip(size));

  /// Đổi cuộn tem: bảo máy cuốn vài tem để đo lại khe thật của cuộn mới (cuộn khác khe thì
  /// tem lệch dần). Gửi được thì báo cho khách biết máy sắp cuốn giấy.
  Future<void> _detectGap() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final size = _size;
    final failure = await AgentPrinter.detectGap(
      address: widget.address,
      spec: size.spec,
      gapOverrideMm: _settings.gapMm,
      dpi: _settings.dpi,
      ribbon: _settings.ribbon.value,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: failure == null ? null : AppColors.errorRed,
        duration: Duration(seconds: failure == null ? 8 : 10),
        content: Text(
          failure == null
              ? 'Máy đang cuốn vài tem để đo lại khe. Đợi máy dừng rồi bấm "In tem '
                    'thử" để kiểm tra.'
              : AgentJobErrorText.message(
                  failure.error,
                  detail: failure.detail,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.agent,
    builder: (context, _) {
      final c = _settings.calibration;
      final size = _size;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          const _SectionTitle('Căn chỉnh tem'),
          if (widget.connected) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => unawaited(_printSlip()),
                icon: _busy
                    ? AgentSpinner(size: 16, color: Colors.white)
                    : const Icon(Icons.print_rounded, size: 18),
                label: const Text('In tem thử'),
              ),
            ),
            const _Hint(
              'Khung phải cách đều bốn mép tem. Lệch về phía nào thì bấm mũi tên ngược lại.',
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => unawaited(_detectGap()),
                icon: const Icon(Icons.height_rounded, size: 18),
                label: const Text('Vừa đổi cuộn tem? Dò lại khe'),
              ),
            ),
          ] else
            const _Hint(
              'Máy in chưa kết nối nên chưa in thử được. Vẫn dời vị trí bằng mũi tên được.',
            ),
          Center(
            child: OffsetPreviewPad(
              widthMm: size.spec.widthMm,
              heightMm: size.spec.heightMm,
              count: size.count,
              jewelry: _settings.dpi >= 300 || _settings.ribbon.value == true,
              offsetXMm: c.offsetXMm,
              offsetYMm: c.offsetYMm,
              onUp: () => unawaited(_nudge(dy: -LabelCalibration.stepMm)),
              onDown: () => unawaited(_nudge(dy: LabelCalibration.stepMm)),
              onLeft: () => unawaited(_nudge(dx: -LabelCalibration.stepMm)),
              onRight: () => unawaited(_nudge(dx: LabelCalibration.stepMm)),
              onReset: c.isZero ? null : () => unawaited(_reset()),
            ),
          ),
          Text(
            LabelOffsetText.describe(c),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 12, color: AgentColors.textSecondary),
  );
}
