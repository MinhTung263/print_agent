import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/domain/agent_print_route_planner.dart';
import 'package:print_agent/src/domain/agent_print_route_validator.dart';
import 'package:print_agent/src/domain/entities/agent_print_route.dart';
import 'package:print_agent/src/domain/ports/agent_host.dart';
import 'package:print_agent/src/domain/ports/agent_print_routing_store.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// "Chức năng in của máy này" ngay trong chi tiết máy in trên sơ đồ: bấm chọn / bỏ chọn chức
/// năng (Tạm tính, Thanh toán, Tem nhãn...) máy in này đảm nhận. Tự lưu khi bấm — không có nút
/// Lưu. Một chức năng chỉ in ra một máy: chọn chức năng đang ở máy khác thì chuyển sang máy này.
class AgentPrinterFunctions extends StatefulWidget {
  const AgentPrinterFunctions({
    super.key,
    required this.store,
    required this.printerName,
    this.isLabelPrinter = false,
  });

  final AgentPrintRoutingStore store;

  /// Tên máy in (khoá cấu hình theo máy in).
  final String printerName;

  /// Máy in tem: chỉ hiện / gợi ý chức năng "Tem nhãn" (máy tem không in hoá đơn, phiếu bếp).
  final bool isLabelPrinter;

  @override
  State<AgentPrinterFunctions> createState() => _AgentPrinterFunctionsState();
}

class _AgentPrinterFunctionsState extends State<AgentPrinterFunctions> {
  List<AgentPrintRoute> _routes = [];
  List<AgentPrintTemplate> _templates = const [];
  List<String> _printers = const [];
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final routes = await widget.store.load();
      final templates = await widget.store.templates();
      final printers = await widget.store.printers();
      if (!mounted) return;
      setState(() {
        _routes = List.of(routes);
        _templates = templates;
        _printers = printers;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  /// Dòng cấu hình của (chức năng [f], máy này); `null` = máy này chưa nhận chức năng đó.
  AgentPrintRoute? _routeOf(AgentPrintFunction f) {
    for (final r in _routes) {
      if (r.function == f && _mine(r)) return r;
    }
    return null;
  }

  /// Chức năng [f] đã có máy in khác nhận chưa (chỉ để không gợi ý giành của máy khác).
  bool _takenElsewhere(AgentPrintFunction f) =>
      _routes.any((r) => r.function == f && !_mine(r));

  bool _mine(AgentPrintRoute? r) =>
      r != null && (r.printerName ?? '').trim() == widget.printerName.trim();

  /// Gợi ý chỉ hiện khi máy này CHƯA nhận chức năng nào và còn chức năng chưa máy nào nhận.
  List<AgentPrintFunction> get _suggestion => _routes.any(_mine)
      ? const []
      : [
          for (final f
              in widget.isLabelPrinter
                  ? const [AgentPrintFunction.label]
                  : AgentPrintRoutePlanner.suggest(widget.printerName))
            // Không giành chức năng máy khác đang nhận; chỉ gợi ý chức năng đã có mẫu in.
            if (!_takenElsewhere(f) &&
                AgentPrintRoutePlanner.templatesFor(f, _templates).isNotEmpty)
              f,
        ];

  /// Máy tem chỉ nhận "Tem nhãn"; chức năng khác lỡ đã chọn vẫn hiện để bỏ chọn được.
  bool _allowed(AgentPrintFunction f) =>
      !widget.isLabelPrinter ||
      f == AgentPrintFunction.label ||
      _routeOf(f) != null;

  static String _hint(AgentPrintFunction f) => switch (f) {
    AgentPrintFunction.provisional =>
      LocaleKeys.printerSetting_fnHintProvisional,
    AgentPrintFunction.payment => LocaleKeys.printerSetting_fnHintPayment,
    AgentPrintFunction.kitchen => LocaleKeys.printerSetting_fnHintKitchen,
    AgentPrintFunction.cancelDish => LocaleKeys.printerSetting_fnHintCancelDish,
    AgentPrintFunction.supply => LocaleKeys.printerSetting_fnHintSupply,
    AgentPrintFunction.paymentQr => LocaleKeys.printerSetting_fnHintPaymentQr,
    AgentPrintFunction.label => LocaleKeys.printerSetting_fnHintLabel,
    AgentPrintFunction.prescription =>
      LocaleKeys.printerSetting_fnHintPrescription,
  };

  Future<void> _applySuggestion() async {
    final free = _suggestion;
    if (free.isEmpty || _busy) return;
    await _commit([
      ..._routes,
      for (final f in free)
        AgentPrintRoutePlanner.create(
          f,
          printers: _printers,
          templates: _templates,
        ).copyWith(printerName: widget.printerName),
    ]);
  }

  /// Một chức năng có thể in ra nhiều máy (như cấu hình máy in của EasyPOS): bấm chỉ thêm / bỏ
  /// chức năng đó CHO MÁY NÀY, không đụng máy khác.
  Future<void> _toggle(AgentPrintFunction f) async {
    if (_busy) return;
    final current = _routeOf(f);
    final next = List.of(_routes);
    if (current != null) {
      next.remove(current);
    } else {
      next.add(
        AgentPrintRoutePlanner.create(
          f,
          printers: _printers,
          templates: _templates,
        ).copyWith(printerName: widget.printerName),
      );
    }
    await _commit(next);
  }

  /// Lưu danh sách mới (chỉ khi mỗi dòng đủ máy in + mẫu in); lỗi thì tải lại cho đúng thực tế.
  Future<void> _commit(List<AgentPrintRoute> next) async {
    if (!_valid(next)) {
      unawaited(
        PrintAgentUi.kit.notify(
          message: LocaleKeys.printerSetting_routingNoTemplate.tr,
          type: AgentNoticeLevel.warning,
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _routes = next;
    });
    try {
      await widget.store.save(next);
    } catch (_) {
      unawaited(
        PrintAgentUi.kit.notify(
          message: LocaleKeys.printerSetting_routingSaveFailed.tr,
          type: AgentNoticeLevel.error,
        ),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Hợp lệ = đủ cặp máy in + mẫu in, số bản ≥ 1. Trùng chức năng giữa các máy là bình thường.
  static bool _valid(List<AgentPrintRoute> routes) => [
    for (final issues in AgentPrintRouteValidator.validate(routes).values)
      ...issues.where((x) => x != AgentPrintRouteIssue.duplicateName),
  ].isEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return PrintAgentUi.kit.spinner();
    return AppColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.sm,
      children: [
        const AppText(
          LocaleKeys.printerSetting_printerFunctionsTitle,
          variant: .title,
        ),
        const AppText(
          LocaleKeys.printerSetting_printerFunctionsHint,
          variant: .caption,
          tone: .secondary,
          maxLines: 2,
        ),
        if (_suggestion.isNotEmpty)
          BaseCard.section(
            child: AppColumn(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpace.sm,
              children: [
                const AppText(
                  LocaleKeys.printerSetting_printerFunctionsSuggest,
                  variant: .captionStrong,
                ),
                AppText.raw(
                  _suggestion.map((f) => f.title).join(' · '),
                  variant: .body,
                  maxLines: 2,
                ),
                BaseButton(
                  title: LocaleKeys.printerSetting_printerFunctionsSuggestApply,
                  onPressed: _busy ? null : () => unawaited(_applySuggestion()),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final f in AgentPrintFunction.values)
              if (_allowed(f)) _chip(f, _routeOf(f)),
          ],
        ),
        // Giải thích bằng lời thường cho chức năng máy này đang nhận.
        for (final f in AgentPrintFunction.values)
          if (_mine(_routeOf(f)))
            AppText.raw(
              '${f.title}: ${_hint(f).tr}',
              variant: .caption,
              tone: .secondary,
              maxLines: 2,
            ),
      ],
    );
  }

  Widget _chip(AgentPrintFunction f, AgentPrintRoute? r) =>
      AdaptiveSelectableCard(
        key: ValueKey('fn_${f.name}'),
        isSelected: _mine(r),
        onTap: _busy ? null : () => unawaited(_toggle(f)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AppText.raw(f.title, variant: .caption, maxLines: 1),
      );
}
