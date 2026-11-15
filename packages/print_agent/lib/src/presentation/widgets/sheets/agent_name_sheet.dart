import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Đặt tên máy Agent này (VD "Quầy bar") — mở từ thẻ tên hoặc bấm nút máy này
/// trên sơ đồ.
class AgentNameSheet extends StatefulWidget {
  const AgentNameSheet({super.key});

  static Future<void> show() => BaseBottomSheet.show<void>(
    body: const AgentNameSheet(),
    headerTitle: LocaleKeys.printerSetting_agentNameTitle,
    allowOffline: true,
  );

  @override
  State<AgentNameSheet> createState() => _AgentNameSheetState();
}

class _AgentNameSheetState extends State<AgentNameSheet> {
  // Chưa đặt tên: điền sẵn tên máy đang dùng để sửa nhanh.
  late final _name = TextEditingController(
    text: PrintAgentUi.station.displayName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await PrintAgentUi.station.setName(_name.text);
    Get.back<void>();
  }

  @override
  Widget build(BuildContext context) {
    return AppPadding.all(
      AppSpace.lg,
      child: AppColumn(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.md,
        children: [
          const AppText(
            LocaleKeys.printerSetting_agentNameSheetHint,
            variant: .caption,
            tone: .secondary,
            maxLines: 3,
          ),
          BaseInput(
            model: BaseInputModel(
              controller: _name,
              label: LocaleKeys.printerSetting_agentNameTitle,
            ),
          ),
          BaseButton(
            onPressed: () => unawaited(_save()),
            title: LocaleKeys.printerSetting_agentNameSave,
            backgroundColor: AppColors.primaryBlueBase,
          ),
        ],
      ),
    );
  }
}
