/// Thành phần giao diện module Agent dùng — CÙNG TÊN + tham số với design
/// system của app EasyPOS (sds) để code màn Agent giữ nguyên, nhưng dựng qua
/// [AgentUiKit] do app chủ cung cấp. KHÔNG export ra ngoài module (tránh trùng
/// tên với sds trong app).
library;

export 'package:get/get.dart';

export '../../l10n/agent_locale_keys.dart';
export 'agent_ui_kit.dart';
export 'kit_tokens.dart';
export 'kit_widgets.dart';
