import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../agent/agent_store.dart';

/// Tường lửa Windows chặn kết nối vào Agent thì điện thoại trong quán không gửi lệnh in về
/// máy này được (chỉ còn đường qua mạng ngoài). Bộ cài đã mở sẵn; bản chạy không qua bộ cài
/// (bản copy thẳng, đổi thư mục cài) thì thiếu quy tắc — kiểm tra lúc mở và xin quyền mở MỘT lần.
abstract final class FirewallGuard {
  /// Tên quy tắc do bộ cài tạo (trùng `easypos_print_agent.iss`).
  static const installerRule = 'Tram in EasyPOS (TCP 9101)';

  /// Quy tắc app tự thêm cho bản chạy ngoài bộ cài.
  static const portableRule = 'Tram in EasyPOS (ban chay truc tiep)';

  static const _askedKey = 'firewall.asked';

  /// Kết quả `netsh ... show rule ... verbose` cho phép [exe] chạy. Bắt buộc có dòng chương
  /// trình trỏ đúng [exe]; các điều kiện bật / cho phép / chiều vào chỉ kiểm tra khi nhãn
  /// tiếng Anh có mặt (Windows bản ngôn ngữ khác in nhãn khác — khi đó tin vào quy tắc tên
  /// đã khớp đường dẫn chương trình).
  static bool ruleCoversProgram(String netshOutput, String exe) {
    final text = netshOutput.toLowerCase();
    final want = exe.toLowerCase();
    bool fails(String block, String label, String ok) {
      final m = RegExp('$label:\\s*(\\S+)').firstMatch(block);
      return m != null && m.group(1) != ok;
    }

    // Mỗi quy tắc cách nhau bằng dòng gạch ngang.
    for (final block in text.split(RegExp(r'\n-{5,}'))) {
      if (!block.contains(want)) continue;
      if (fails(block, 'enabled', 'yes') ||
          fails(block, 'action', 'allow') ||
          fails(block, 'direction', 'in')) {
        continue;
      }
      return true;
    }
    return false;
  }

  /// Windows: chưa có quy tắc cho bản đang chạy thì xin quyền quản trị (UAC) thêm quy
  /// tắc — hỏi đúng một lần cho mỗi đường dẫn chạy (từ chối thì không hỏi lại).
  static Future<void> ensure() async {
    if (!Platform.isWindows) return;
    try {
      final exe = Platform.resolvedExecutable;
      for (final rule in [installerRule, portableRule]) {
        final r = await Process.run('netsh', [
          'advfirewall',
          'firewall',
          'show',
          'rule',
          'name=$rule',
          'verbose',
        ]).timeout(const Duration(seconds: 8));
        if (r.exitCode == 0 && ruleCoversProgram('${r.stdout}', exe)) return;
      }
      final key = '$_askedKey.${exe.toLowerCase()}';
      if (AgentStore.get(key) == '1') return;
      AgentStore.set(key, '1');
      await _addElevated(exe);
    } catch (e) {
      debugPrint('[AGENT] Không kiểm tra được tường lửa: $e');
    }
  }

  static Future<void> _addElevated(String exe) async {
    final q = exe.replaceAll("'", "''");
    final inner =
        "Start-Process netsh -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "
        "@('advfirewall','firewall','delete','rule','name=\"$portableRule\"'); "
        "Start-Process netsh -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "
        "@('advfirewall','firewall','add','rule','name=\"$portableRule\"',"
        "'dir=in','action=allow','protocol=TCP','program=\"$q\"',"
        "'profile=any','enable=yes')";
    final encoded = base64Encode([
      for (final c in inner.codeUnits) ...[c & 0xff, c >> 8],
    ]);
    await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      encoded,
    ]).timeout(const Duration(seconds: 60));
  }
}
