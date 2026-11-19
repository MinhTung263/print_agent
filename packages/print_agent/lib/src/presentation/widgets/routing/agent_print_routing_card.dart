import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/domain/entities/agent_print_route.dart';
import 'package:print_agent/src/domain/ports/agent_host.dart';
import 'package:print_agent/src/domain/ports/agent_print_routing_store.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Thẻ "In theo chức năng": tóm tắt chức năng → máy in, hai công tắc chung của cửa hàng và nút
/// mở bảng cấu hình. Cấu hình THEO TÀI KHOẢN (dùng chung mọi máy), Agent chỉ là nơi sửa.
/// Không có kho ([PrintAgentUi.printRouting] rỗng) thì không hiện.
class AgentPrintRoutingCard extends StatefulWidget {
  const AgentPrintRoutingCard({super.key, required this.store});

  final AgentPrintRoutingStore store;

  @override
  State<AgentPrintRoutingCard> createState() => _AgentPrintRoutingCardState();
}

class _AgentPrintRoutingCardState extends State<AgentPrintRoutingCard> {
  List<AgentPrintRoute> _routes = const [];
  bool _preview = true;
  bool _askCopies = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final routes = await widget.store.load();
      final preview = await widget.store.previewBeforePayment();
      final ask = await widget.store.askCopiesEachPrint();
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _preview = preview;
        _askCopies = ask;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _setPreview(bool v) async {
    setState(() => _preview = v);
    await _persist(() => widget.store.setPreviewBeforePayment(v), () {
      if (mounted) setState(() => _preview = !v);
    });
  }

  Future<void> _setAskCopies(bool v) async {
    setState(() => _askCopies = v);
    await _persist(() => widget.store.setAskCopiesEachPrint(v), () {
      if (mounted) setState(() => _askCopies = !v);
    });
  }

  /// Lưu không được: trả công tắc về như cũ và báo — không để khách tưởng đã lưu.
  Future<void> _persist(
    Future<void> Function() save,
    VoidCallback rollback,
  ) async {
    try {
      await save();
    } catch (_) {
      rollback();
      unawaited(
        PrintAgentUi.kit.notify(
          message: LocaleKeys.printerSetting_routingSaveFailed.tr,
          type: AgentNoticeLevel.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard.section(
      child: AppColumn(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.sm,
        children: [
          const AppText(
            LocaleKeys.printerSetting_routingTitle,
            variant: .title,
          ),
          const AppText(
            LocaleKeys.printerSetting_routingCardHint,
            variant: .caption,
            tone: .secondary,
            maxLines: 2,
          ),
          if (!_loaded)
            PrintAgentUi.kit.spinner()
          else ...[
            _FunctionTable(routes: _routes),
            BaseCupertinoSwitch(
              value: _preview,
              onChanged: (v) => unawaited(_setPreview(v)),
              leftLabel: LocaleKeys.printerSetting_routingPreview,
              mainAxisSize: MainAxisSize.max,
            ),
            BaseCupertinoSwitch(
              value: _askCopies,
              onChanged: (v) => unawaited(_setAskCopies(v)),
              leftLabel: LocaleKeys.printerSetting_routingAskCopies,
              mainAxisSize: MainAxisSize.max,
            ),
            const AppText(
              LocaleKeys.printerSetting_routingHowTo,
              variant: .caption,
              tone: .secondary,
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }
}

/// Bảng "chức năng → các máy in đang nhận": mỗi chức năng một dòng; chức năng chưa có máy nào
/// ghi "Chưa có máy" (màu nhạt) để khách thấy ngay chỗ còn thiếu.
class _FunctionTable extends StatelessWidget {
  const _FunctionTable({required this.routes});

  final List<AgentPrintRoute> routes;

  String _printersOf(AgentPrintFunction f) {
    final names = <String>[];
    for (final r in routes) {
      final n = (r.printerName ?? '').trim();
      if (r.function == f && n.isNotEmpty && !names.contains(n)) names.add(n);
    }
    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(
          color: Colors.black.withValues(alpha: 0.08),
        ),
      ),
      children: [
        const TableRow(
          children: [
            _Cell(
              AppText(
                LocaleKeys.printerSetting_routingColFunction,
                variant: .captionStrong,
                tone: .secondary,
              ),
            ),
            _Cell(
              AppText(
                LocaleKeys.printerSetting_routingColPrinter,
                variant: .captionStrong,
                tone: .secondary,
              ),
            ),
          ],
        ),
        for (final f in AgentPrintFunction.values)
          TableRow(
            children: [
              _Cell(AppText.raw(f.title, variant: .body, maxLines: 1)),
              _Cell(
                _printersOf(f).isEmpty
                    ? const AppText(
                        LocaleKeys.printerSetting_routingNone,
                        variant: .caption,
                        tone: .tertiary,
                      )
                    : AppText.raw(_printersOf(f), variant: .body, maxLines: 3),
              ),
            ],
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
    child: child,
  );
}
