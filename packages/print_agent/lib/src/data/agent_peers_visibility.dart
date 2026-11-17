import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../print_agent_module.dart';

/// Sơ đồ Agent có hiện các trạm in KHÁC cùng công ty hay không. Mặc định ẨN (sơ đồ gọn: chỉ máy này
/// và máy in của nó); bật bằng nút ở đầu sơ đồ. Lưu trên máy này theo công ty.
abstract final class AgentPeersVisibility {
  static final RxBool show = false.obs;

  static String? _loadedFor;

  static String get _storageKey =>
      'agent_show_peers_${PrintAgentModule.host.companyKey}';

  /// Đọc lựa chọn của công ty đang đăng nhập — gọi NGOÀI lúc dựng giao diện.
  static void ensureLoaded() {
    final key = _storageKey;
    if (_loadedFor == key) return;
    _loadedFor = key;
    var on = false;
    try {
      on = PrintAgentModule.host.storage.get(key) == true;
    } catch (_) {}
    _apply(on);
  }

  /// Đặt giá trị; đang trong lúc dựng giao diện (hàm này được gọi từ `build`) thì hoãn tới sau khung
  /// hình — đổi Rx giữa lúc dựng làm các `Obx` đang theo dõi báo lỗi "setState() called during build".
  static void _apply(bool on) {
    if (show.value == on) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => show.value = on);
    } else {
      show.value = on;
    }
  }

  static Future<void> set(bool on) async {
    ensureLoaded();
    show.value = on;
    try {
      await PrintAgentModule.host.storage.put(_storageKey, on);
    } catch (_) {}
  }
}
