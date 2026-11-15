import 'dart:ui';

import 'package:get/get.dart';

import 'domain/ports/agent_host.dart';
import 'l10n/agent_translations.dart';

/// Điểm nối module với app chủ: app gọi [init] một lần lúc khởi động.
abstract final class PrintAgentModule {
  static AgentHost? _host;

  static void init(AgentHost host) {
    _host = host;
    _mergeTranslations();
    // App chủ chưa đặt ngôn ngữ (Agent máy tính, test): mặc định tiếng Việt.
    Get.locale ??= const Locale('vi', 'VN');
  }

  /// Thêm chuỗi của module vào bộ dịch GetX mà KHÔNG thay bảng của app:
  /// `Get.addTranslations` thay cả bảng một ngôn ngữ (app mất hết chuỗi), còn
  /// `appendTranslations` sửa thẳng bảng của app (bảng `const` → lỗi). Tạo bảng
  /// mới gộp hai bên, chuỗi của app được ưu tiên khi trùng khoá.
  static void _mergeTranslations() {
    final current = Get.translations;
    for (final e in agentTranslations.entries) {
      final app = current[e.key];
      Get.addTranslations({
        e.key: {...e.value, ...?app},
      });
    }
  }

  static AgentHost get host {
    final h = _host;
    if (h == null) {
      throw StateError('Chưa gọi PrintAgentModule.init(host) trước khi dùng');
    }
    return h;
  }
}
