import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../desktop/autostart.dart';
import '../ds/ds.dart';

/// Cài đặt chung của trạm in: tự chạy (cửa hàng + đăng xuất ở đầu
/// trang). Cài đặt từng máy in (loại, khổ giấy, căn chỉnh tem) nằm trong chi tiết máy
/// in trên sơ đồ ([PrinterSettingsPanel]).
class AgentSettingsCard extends StatelessWidget {
  const AgentSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Máy không hỗ trợ tự chạy khi bật máy: không còn cài đặt chung nào để hiện.
    if (!Autostart.supported) return const SizedBox.shrink();
    return BaseCard.section(
      child: AppColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.sm,
        children: [
          const AppText('Cài đặt trạm in', variant: .title),
          ValueListenableBuilder<bool>(
            valueListenable: Autostart.instance.enabled,
            builder: (_, on, _) => AppRow(
              children: [
                const Expanded(
                  child: AppColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText('Tự chạy khi bật máy'),
                      AppText(
                        'Chạy ẩn dưới khay hệ thống để luôn nhận lệnh in',
                        variant: .caption,
                        tone: .secondary,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: on,
                  activeTrackColor: AppColors.primaryBlueBase,
                  onChanged: (v) => unawaited(Autostart.instance.set(v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
