import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/print_agent.dart'
    show AgentJobErrorText, AgentPrintFailure;
import 'package:printer_label/printer_label.dart' show LabelCalibration;

import '../../agent/agent_printer.dart';
import '../../agent/desktop_agent.dart';
import '../../agent/label_drift.dart';
import '../../agent/label_preset.dart';
import '../../agent/last_label.dart';
import '../../agent/printer_settings.dart';
import '../agent_theme.dart';
import '../ds/ds.dart';
import '../widgets/agent_spinner.dart';
import 'calibration_stepper.dart';
import 'offset_preview_pad.dart';
import 'label_offset_text.dart';

/// Căn chỉnh tem cho MỘT máy in tem — gọn và tự động:
/// - khổ tem lấy từ lần in gần nhất (không phải chọn);
/// - "In tem thử", rồi bấm mũi tên quanh hình tem cho tới khi khung nằm sát mép tem;
/// - tem lệch dần khi in nhiều lần: in 4 tem liền, nhập độ lệch, app tự tính lại khe.
class LabelCalibrationPanel extends StatefulWidget {
  const LabelCalibrationPanel({
    super.key,
    required this.agent,
    required this.address,
    this.connected = true,
  });

  final DesktopAgent agent;
  final String address;

  /// Máy in đang kết nối: chưa kết nối thì ẩn các nút in (in thử, đo độ lệch).
  final bool connected;

  @override
  State<LabelCalibrationPanel> createState() => _LabelCalibrationPanelState();
}

class _LabelCalibrationPanelState extends State<LabelCalibrationPanel> {
  bool _busy = false;
  bool _measured = false; // đã in 4 tem liền để đo độ lệch
  double _drift = 0; // hàng cuối lệch so với hàng đầu (mm, dương = xuống)

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

  Future<void> _setGap(double mm) => widget.agent.updateSettings(
    widget.address,
    _settings.copyWith(gapMm: mm.clamp(0.0, 10.0).toDouble()),
  );

  Future<void> _run(
    Future<AgentPrintFailure?> Function(LabelPreset size) action,
    String ok,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final failure = await action(_size);
    if (!mounted) return;
    setState(() => _busy = false);
    final error = failure == null
        ? null
        : AgentJobErrorText.message(failure.error, detail: failure.detail);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: error == null
            ? AppColors.successGreen
            : AppColors.errorRed,
        duration: Duration(seconds: error == null ? 4 : 10),
        content: Text(error ?? ok),
      ),
    );
  }

  Future<AgentPrintFailure?> _slip(LabelPreset size, {int repeat = 1}) =>
      AgentPrinter.printLabelCalibration(
        address: widget.address,
        spec: size.spec,
        calibration: _settings.calibration,
        gapOverrideMm: _settings.gapMm,
        labelsPerRow: size.count,
        temWidthMm: size.temWidthMm,
        repeat: repeat,
      );

  Future<void> _printSlip() => _run((size) => _slip(size), 'Đã gửi tem thử');

  /// In [LabelDrift.rows] hàng liền nhau trong một lần: nhìn hàng cuối lệch bao nhiêu so
  /// với hàng đầu để tính khe đúng.
  Future<void> _printMeasure() async {
    await _run(
      (size) => _slip(size, repeat: LabelDrift.rows),
      'Đã in ${LabelDrift.rows} tem liền — so tem cuối với tem đầu',
    );
    if (mounted) setState(() => _measured = true);
  }

  /// Khe hiện đang dùng (theo khổ tem nếu chưa chỉnh).
  double get _currentGap =>
      _settings.gapMm == 0 ? _size.spec.gapMm.toDouble() : _settings.gapMm;

  Future<void> _applyDrift() async {
    final gap = LabelDrift.newGap(currentGapMm: _currentGap, driftMm: _drift);
    await _setGap(gap);
    if (!mounted) return;
    setState(() {
      _drift = 0;
      _measured = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã chỉnh. In lại 4 tem liền để kiểm tra.')),
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
              'Tem in ra phải giống hình bên dưới: khung cách đều bốn mép tem. Khung '
              'sát hoặc bị cắt một mép thì bấm mũi tên ngược lại.',
            ),
          ] else
            const _Hint(
              'Máy in chưa kết nối nên chưa in thử được. Nút "In tem thử" sẽ hiện lại '
              'khi máy in kết nối. Vẫn dời vị trí bằng mũi tên được.',
            ),
          Center(
            child: OffsetPreviewPad(
              widthMm: size.spec.widthMm,
              heightMm: size.spec.heightMm,
              count: size.count,
              offsetXMm: c.offsetXMm,
              offsetYMm: c.offsetYMm,
              onUp: () => unawaited(_nudge(dy: -LabelCalibration.stepMm)),
              onDown: () => unawaited(_nudge(dy: LabelCalibration.stepMm)),
              onLeft: () => unawaited(_nudge(dx: -LabelCalibration.stepMm)),
              onRight: () => unawaited(_nudge(dx: LabelCalibration.stepMm)),
              onReset: c.isZero ? null : () => unawaited(_reset()),
            ),
          ),
          const OffsetPreviewLegend(),
          Row(
            children: [
              Expanded(
                child: Text(
                  LabelOffsetText.describe(c),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!c.isZero)
                TextButton(
                  onPressed: () => unawaited(_reset()),
                  child: const Text('Về 0'),
                ),
            ],
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _settings.gapMm > 0,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text(
                'In nhiều tem bị lệch dần?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              children: [
                if (widget.connected) ...[
                  const _Hint(
                    'Bấm đo: máy in 4 tem liền. Nhìn khung ở tem cuối so với tem '
                    'đầu rồi nhập độ lệch — app tự tính lại khe giữa các tem.',
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => unawaited(_printMeasure()),
                      icon: const Icon(Icons.straighten_rounded, size: 18),
                      label: Text('Đo độ lệch: in ${LabelDrift.rows} tem liền'),
                    ),
                  ),
                  if (_measured) ...[
                    const SizedBox(height: 8),
                    CalibrationStepper(
                      title: 'Tem cuối lệch so với tem đầu',
                      hint:
                          'Tem cuối thấp hơn thì bấm +, cao hơn thì bấm −. Thẳng '
                          'hàng thì không cần chỉnh.',
                      valueText: _drift == 0
                          ? 'Không lệch'
                          : '${_drift > 0 ? 'Xuống ' : 'Lên '}'
                                '${LabelOffsetText.mm(_drift.abs())}',
                      onMinus: () => setState(
                        () => _drift = (_drift - 0.5).clamp(-10.0, 10.0),
                      ),
                      onPlus: () => setState(
                        () => _drift = (_drift + 0.5).clamp(-10.0, 10.0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _drift == 0
                            ? null
                            : () => unawaited(_applyDrift()),
                        child: const Text('Tự chỉnh khe'),
                      ),
                    ),
                  ],
                ] else
                  const _Hint('Cần máy in đang kết nối để đo độ lệch.'),
              ],
            ),
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
