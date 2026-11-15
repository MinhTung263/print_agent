import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/utils/agent_peer_cluster.dart';
import 'package:print_agent/src/presentation/widgets/agent_printers_map.dart';

/// Một máy in trong bảng sắp xếp.
class _Printer {
  const _Printer(this.key, this.name, this.icon);

  final String key;
  final String name;
  final IconData icon;
}

/// Một nhánh (máy Agent) trong bảng sắp xếp.
class _Branch {
  _Branch({
    required this.id,
    required this.title,
    required this.printers,
    this.self = false,
  });

  final String id;
  final String title;
  final List<_Printer> printers;

  /// Máy này (đứng đầu, không kéo đổi chỗ).
  final bool self;
}

/// "Sắp xếp sơ đồ": kéo đổi thứ tự các máy Agent + máy in trong từng Agent cho
/// sơ đồ dễ nhìn ([AgentMapLayout]). Chỉ đổi cách hiển thị trên máy này — không
/// đổi Agent nào in máy in nào.
class AgentMapArrangeSheet extends StatefulWidget {
  const AgentMapArrangeSheet({super.key, required this.isAgent});

  /// Máy này đang là Agent: có nhánh "máy này" (máy in của máy này) ở đầu.
  final bool isAgent;

  static Future<void> show({required bool isAgent}) {
    AgentMapLayout.ensureLoaded();
    return BaseBottomSheet.show<void>(
      headerTitle: LocaleKeys.printerSetting_agentArrange,
      body: AgentMapArrangeSheet(isAgent: isAgent),
      allowOffline: true,
    );
  }

  @override
  State<AgentMapArrangeSheet> createState() => _AgentMapArrangeSheetState();
}

class _AgentMapArrangeSheetState extends State<AgentMapArrangeSheet> {
  late final List<_Branch> _branches = _load();

  List<_Branch> _load() {
    final service = PrintAgentUi.station;
    final peers = agentPeerEntries(service.relay.stations.value);
    return [
      if (widget.isAgent)
        _Branch(
          id: service.stationId,
          title: AgentIdentity.label(service.displayName, service.stationId),
          self: true,
          printers: [
            for (final s in AgentMapLayout.sorted(
              PrintAgentUi.station.watchdog.statuses.toList(),
              AgentMapLayout.printers[service.stationId] ?? const <String>[],
              (s) => AgentPrintersMap.selfPrinterKey(s.printer),
            ))
              _Printer(
                AgentPrintersMap.selfPrinterKey(s.printer),
                s.printer.nameOrNull ?? s.printer.refAddress ?? '',
                switch (s.printer.refKind) {
                  AgentPrinterKind.builtIn => Icons.point_of_sale_rounded,
                  AgentPrinterKind.usb => Icons.usb_rounded,
                  _ => Icons.print_rounded,
                },
              ),
          ],
        ),
      for (final e in peers)
        _Branch(
          id: '${e.info['id']}',
          title: AgentIdentity.ofStation(e.info),
          printers: [
            for (final p in agentPeerPrinterMaps(e.info))
              _Printer(
                agentPeerPrinterKey(p),
                p['name']?.toString() ?? '',
                switch (p['kind']) {
                  'builtin' => Icons.point_of_sale_rounded,
                  'usb' => Icons.usb_rounded,
                  _ => Icons.print_rounded,
                },
              ),
          ],
        ),
    ];
  }

  Future<void> _save() async {
    await AgentMapLayout.save(
      agentOrder: [
        for (final b in _branches)
          if (!b.self) b.id,
      ],
      printerOrder: {
        for (final b in _branches) b.id: [for (final p in b.printers) p.key],
      },
    );
    Get.back<void>();
  }

  Future<void> _reset() async {
    await AgentMapLayout.reset();
    Get.back<void>();
  }

  @override
  Widget build(BuildContext context) {
    final self = _branches.where((b) => b.self).toList();
    final peers = _branches.where((b) => !b.self).toList();
    if (_branches.isEmpty) {
      return const AppPadding.all(
        AppSpace.lg,
        child: AppText(
          LocaleKeys.printerSetting_agentArrangeEmpty,
          tone: .secondary,
          textAlign: TextAlign.center,
        ),
      );
    }
    return AppColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: AppEdgeInsets.all(AppSpace.lg),
            children: [
              const AppText(
                LocaleKeys.printerSetting_agentArrangeHint,
                variant: .caption,
                tone: .secondary,
                maxLines: 3,
              ),
              sdsSizedBox8,
              for (final b in self) _BranchTile(branch: b, onChanged: _changed),
              // Các Agent khác: kéo tay cầm để đổi thứ tự.
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: (from, to) => setState(() {
                  final item = peers.removeAt(from);
                  peers.insert(to > from ? to - 1 : to, item);
                  _branches
                    ..removeWhere((b) => !b.self)
                    ..addAll(peers);
                }),
                children: [
                  for (var i = 0; i < peers.length; i++)
                    _BranchTile(
                      key: ValueKey(peers[i].id),
                      branch: peers[i],
                      dragIndex: i,
                      onChanged: _changed,
                    ),
                ],
              ),
            ],
          ),
        ),
        AppPadding.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
          child: AppRow(
            spacing: AppSpace.md,
            children: [
              // Hai nút cùng cỡ (44) chia đều hàng: phụ nền xanh nhạt, chính xanh đặc.
              Expanded(
                child: BaseButton(
                  onPressed: () => unawaited(_reset()),
                  title: LocaleKeys.printerSetting_agentArrangeReset,
                  backgroundColor: AppColors.primaryBlueBase.withValues(
                    alpha: 0.1,
                  ),
                  titleColor: AppColors.primaryBlueBase,
                ),
              ),
              Expanded(
                child: BaseButton(
                  onPressed: () => unawaited(_save()),
                  title: LocaleKeys.printerSetting_agentArrangeSave,
                  backgroundColor: AppColors.primaryBlueBase,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _changed() => setState(() {});
}

/// Một Agent: tay cầm kéo (trừ máy này) + tên + danh sách máy in kéo được.
class _BranchTile extends StatelessWidget {
  const _BranchTile({
    super.key,
    required this.branch,
    required this.onChanged,
    this.dragIndex,
  });

  final _Branch branch;
  final VoidCallback onChanged;

  /// Vị trí trong danh sách kéo được (`null`: máy này — cố định).
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final b = branch;
    return AppPadding.only(
      bottom: AppSpace.sm,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.dsGray4.withValues(alpha: 0.6)),
        ),
        padding: AppEdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        child: AppColumn(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.xs,
          children: [
            AppRow(
              spacing: AppSpace.sm,
              children: [
                if (dragIndex case final index?)
                  ReorderableDragStartListener(
                    index: index,
                    child: const Icon(
                      Icons.drag_indicator_rounded,
                      color: AppColors.dsGray2,
                    ),
                  )
                else
                  const Icon(
                    Icons.push_pin_outlined,
                    color: AppColors.dsGray5,
                    size: 20,
                  ),
                const AgentDeviceAvatar(online: true, size: 32),
                Expanded(
                  child: AppText.raw(b.title, variant: .title, maxLines: 1),
                ),
              ],
            ),
            if (b.printers.isEmpty)
              const AppPadding.only(
                left: 60,
                bottom: AppSpace.xs,
                child: AppText(
                  LocaleKeys.printerSetting_agentPeerNoPrinters,
                  variant: .caption,
                  tone: .secondary,
                ),
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: (from, to) {
                  final item = b.printers.removeAt(from);
                  b.printers.insert(to > from ? to - 1 : to, item);
                  onChanged();
                },
                children: [
                  for (var i = 0; i < b.printers.length; i++)
                    ReorderableDragStartListener(
                      key: ValueKey('${b.id}/${b.printers[i].key}'),
                      index: i,
                      child: _PrinterRow(printer: b.printers[i]),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PrinterRow extends StatelessWidget {
  const _PrinterRow({required this.printer});

  final _Printer printer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 60),
      padding: AppEdgeInsets.symmetric(vertical: AppSpace.sm),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEDEFF2))),
      ),
      child: AppRow(
        spacing: AppSpace.sm,
        children: [
          Icon(printer.icon, size: 18, color: AppColors.primaryBlueBase),
          Expanded(child: AppText.raw(printer.name, maxLines: 1)),
          const Icon(
            Icons.drag_indicator_rounded,
            size: 18,
            color: AppColors.dsGray5,
          ),
        ],
      ),
    );
  }
}
