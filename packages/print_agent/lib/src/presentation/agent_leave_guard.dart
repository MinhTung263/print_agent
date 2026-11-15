import 'package:print_agent/src/presentation/kit/kit.dart';

/// Hỏi lại trước khi rời công ty (đổi công ty / đăng xuất) khi máy này đang là
/// Agent: rời đi là tạm dừng in hộ cho cửa hàng (quay lại thì tự bật lại).
abstract final class AgentLeaveGuard {
  /// `true` = được rời (không phải Agent, hoặc người dùng đồng ý).
  static Future<bool> confirm({required bool logout}) async {
    if (!PrintAgentUi.station.relay.isStation.value) return true;
    var ok = false;
    await Get.dialog<void>(
      AppConfirmDialog(
        title: LocaleKeys.printerSetting_agentLeaveTitle.tr,
        content:
            (logout
                    ? LocaleKeys.printerSetting_agentLeaveLogout
                    : LocaleKeys.printerSetting_agentLeaveChangeCompany)
                .tr,
        confirmText: LocaleKeys.printerSetting_agentLeaveContinue.tr,
        onConfirm: () {
          ok = true;
          Get.back<void>();
        },
      ),
    );
    return ok;
  }
}
