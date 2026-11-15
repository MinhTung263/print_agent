/// Module máy Agent EasyPOS — app chủ gọi [PrintAgentModule.init] với một
/// [AgentHost] rồi dùng các dịch vụ / giao diện bên dưới.
library;

export 'package:print_agent_core/print_agent_core.dart';

export 'src/data/agent_device_identity.dart';
export 'src/data/agent_device_name.dart';
export 'src/data/agent_held_job_store.dart';
export 'src/data/agent_job_handler.dart';
export 'src/data/agent_job_log_store.dart';
export 'src/data/agent_map_layout.dart';
export 'src/data/agent_print_activity_store.dart';
export 'src/data/agent_printer_reconnect.dart';
export 'src/data/agent_printer_remote.dart';
export 'src/data/agent_printer_switches.dart';
export 'src/data/agent_printer_watchdog.dart';
export 'src/data/agent_service.dart';
export 'src/data/known_agents.dart';
export 'src/data/peer_built_in_printers.dart';
export 'src/domain/agent_identity.dart';
export 'src/domain/agent_primary.dart';
export 'src/domain/entities/agent_job_log.dart';
export 'src/domain/entities/agent_print_activity.dart';
export 'src/domain/entities/agent_printer_ref.dart';
export 'src/domain/entities/agent_printer_status.dart';
export 'src/domain/entities/known_agent.dart';
export 'src/domain/entities/peer_built_in_printer.dart';
export 'src/domain/ports/agent_host.dart';
export 'src/domain/ports/agent_job_printer.dart';
export 'src/print_agent_module.dart';
export 'src/domain/ports/agent_printer_gateway.dart';

// Giao diện (dùng chung app EasyPOS và Agent máy tính).
export 'src/presentation/kit/agent_ui_kit.dart';
export 'src/presentation/kit/material_agent_ui_kit.dart';
export 'src/presentation/agent_leave_guard.dart';
export 'src/presentation/agent_service_station.dart';
export 'src/presentation/ports/agent_station.dart';
export 'src/presentation/utils/agent_map_lines.dart';
export 'src/presentation/utils/agent_time_format.dart';
export 'src/presentation/widgets/agent_layout.dart';
export 'src/presentation/widgets/common/agent_device_avatar.dart';
export 'src/presentation/widgets/job_log/agent_job_log_card.dart';
export 'src/presentation/widgets/job_log/agent_job_log_sheet.dart';
export 'src/presentation/widgets/job_log/agent_job_row.dart';
export 'src/presentation/widgets/network_map/agent_map_activity.dart';
export 'src/presentation/widgets/network_map/agent_map_activity_layer.dart';
export 'src/presentation/widgets/network_map/agent_map_node.dart';
export 'src/presentation/widgets/network_map/agent_map_node_view.dart';
export 'src/presentation/widgets/network_map/agent_map_painters.dart';
export 'src/presentation/widgets/network_map/agent_network_map.dart';
export 'src/presentation/widgets/sheets/agent_peer_printer_row.dart';
export 'src/presentation/models/agent_cloud_info.dart';
export 'src/presentation/pages/agent_page.dart';
export 'src/presentation/widgets/entry/agent_app_bar_button.dart';
export 'src/presentation/widgets/entry/agent_entry_card.dart';
export 'src/presentation/widgets/toggles/print_station_toggle.dart';
export 'src/presentation/widgets/peer_built_in/peer_built_in_printers_section.dart';
