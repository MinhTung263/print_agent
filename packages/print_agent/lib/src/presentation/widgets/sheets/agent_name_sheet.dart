import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// "Trạm in này" — mở từ thẻ tên hoặc bấm nút máy này trên sơ đồ: CHỈ để đặt tên (gợi ý một chạm
/// "Quầy thu ngân", "Bếp"...) và xem mã máy (không đổi). "Thêm máy in" nằm riêng ở đầu sơ đồ
/// ([AgentMapHeader]) — không gộp vào đây để khách khỏi tưởng nút "Lưu" áp dụng cho cả hai.
class AgentNameSheet extends StatefulWidget {
  const AgentNameSheet({super.key});

  static Future<void> show() => BaseBottomSheet.show<void>(
    body: const AgentNameSheet(),
    headerTitle: LocaleKeys.printerSetting_agentNameTitle,
    allowOffline: true,
  );

  static const List<String> _suggestions = [
    LocaleKeys.printerSetting_agentNameSuggestCashier,
    LocaleKeys.printerSetting_agentNameSuggestKitchen,
    LocaleKeys.printerSetting_agentNameSuggestBar,
    LocaleKeys.printerSetting_agentNameSuggestFloor1,
    LocaleKeys.printerSetting_agentNameSuggestFloor2,
  ];

  @override
  State<AgentNameSheet> createState() => _AgentNameSheetState();
}

class _AgentNameSheetState extends State<AgentNameSheet> {
  // Chưa đặt tên: điền sẵn tên máy đang dùng để sửa nhanh.
  late final String _original = PrintAgentUi.station.displayName;
  late final _name = TextEditingController(text: _original)
    ..addListener(_onChanged);

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _name
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    await PrintAgentUi.station.setName(_name.text.trim());
    Get.back<void>();
  }

  void _pick(String key) => _name
    ..text = key.tr
    ..selection = TextSelection.collapsed(offset: key.tr.length);

  @override
  Widget build(BuildContext context) {
    final station = PrintAgentUi.station;
    final current = _name.text.trim();
    return AppPadding.all(
      AppSpace.lg,
      child: AppColumn(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.md,
        children: [
          AppRow(
            spacing: AppSpace.md,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.purpleAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: AppColors.purpleAccent,
                ),
              ),
              Expanded(
                child: AppColumn(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    const AppText(
                      LocaleKeys.printerSetting_agentNameSheetHint,
                      variant: .body,
                      maxLines: 2,
                    ),
                    AppText.raw(
                      LocaleKeys.printerSetting_agentNameCodeTr(
                        code: AgentIdentity.shortId(station.stationId),
                      ),
                      variant: .caption,
                      tone: .secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          BaseInput(
            model: BaseInputModel(
              controller: _name,
              label: LocaleKeys.printerSetting_agentNameTitle,
            ),
          ),
          const AppText(
            LocaleKeys.printerSetting_agentNameSuggest,
            variant: .caption,
            tone: .secondary,
          ),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final key in AgentNameSheet._suggestions)
                _Chip(
                  text: key.tr,
                  selected: current == key.tr,
                  onTap: () => _pick(key),
                ),
            ],
          ),
          BaseButton(
            // Chỉ bấm được khi đã đổi tên (chưa đổi gì thì không có gì để lưu).
            onPressed: current.isEmpty || current == _original.trim()
                ? null
                : () => unawaited(_save()),
            title: LocaleKeys.printerSetting_agentNameSave,
            backgroundColor: AppColors.primaryBlueBase,
          ),
        ],
      ),
    );
  }
}

/// Gợi ý tên dạng viên: chọn → nền xanh, chữ trắng.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BaseTap(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs + 2,
      ),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryBlueBase
            : AppColors.primaryBlueBase.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText.raw(
        text,
        variant: .title,
        textColor: selected ? Colors.white : AppColors.primaryBlueBase,
      ),
    ),
  );
}
