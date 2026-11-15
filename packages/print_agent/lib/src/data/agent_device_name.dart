import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:printer_label/printer_label.dart';

import '../print_agent_module.dart';

/// Tên dễ nhận ra của máy này (máy khác thấy trên sơ đồ / nhật ký lệnh).
abstract final class AgentDeviceName {
  /// Tên máy người dùng đặt trong Cài đặt Android (cả máy Android 6 như Sunmi:
  /// tên Bluetooth) — `null` khi chưa đọc / không đọc được.
  static final RxnString settingsName = RxnString();

  static Future<void> load() async {
    if (!Platform.isAndroid || settingsName.value != null) return;
    try {
      settingsName.value = await PrinterLabel.deviceName().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {}
  }

  /// Tên đặt trong app, chưa đặt thì tên trong Cài đặt (VD "Quầy bar",
  /// "Redmi Note 13 Pro 5G"), rồi tên hệ thống, cuối cùng là hãng + model.
  static String? get label {
    final host = PrintAgentModule.host;
    final name = host.appDeviceName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final settings = settingsName.value?.trim() ?? '';
    if (settings.isNotEmpty) return settings;
    final device = host.device;
    if (device == null) return null;
    final system = device.name.trim();
    if (system.isNotEmpty) return system;
    return model;
  }

  /// "Sunmi T1-G" thay vì "SUNMI SUNMI T1-G" — model đã có tên hãng thì bỏ hãng.
  static String? get model {
    final device = PrintAgentModule.host.device;
    if (device == null) return null;
    final m = device.model.trim();
    var brand = device.manufacturer.trim();
    if (brand.isNotEmpty) {
      brand = brand[0].toUpperCase() + brand.substring(1).toLowerCase();
    }
    if (m.toLowerCase().startsWith(brand.toLowerCase())) {
      return m.isEmpty ? null : m;
    }
    final full = '$brand $m'.trim();
    return full.isEmpty ? null : full;
  }
}
