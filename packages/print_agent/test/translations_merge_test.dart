import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';

import 'support/fake_host.dart';

void main() {
  test('module thêm chuỗi nhưng giữ nguyên bảng dịch của app', () {
    // Bảng của app là `const` như app EasyPOS sinh ra.
    const appVi = {
      'config_config': 'Cấu hình',
      'printerSetting_agentDashboard': 'Máy Agent (app)',
    };
    Get.clearTranslations();
    Get.addTranslations({'vi_VN': appVi});
    Get.locale = const Locale('vi', 'VN');

    PrintAgentModule.init(FakeHost());

    expect('config_config'.tr, 'Cấu hình');
    // Trùng khoá: chuỗi của app được ưu tiên.
    expect('printerSetting_agentDashboard'.tr, 'Máy Agent (app)');
    // Khoá chỉ module có: vẫn dịch được.
    expect(
      'printerSetting_agentJobLog'.tr,
      isNot('printerSetting_agentJobLog'),
    );
  });
}
