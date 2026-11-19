import '../domain/entities/agent_print_route.dart';
import '../domain/ports/agent_print_routing_store.dart';

/// Kho trong bộ nhớ: chạy thử / test khi chưa nối API tài khoản.
class AgentPrintRoutingMemoryStore implements AgentPrintRoutingStore {
  AgentPrintRoutingMemoryStore({
    List<AgentPrintRoute> routes = const [],
    List<AgentPrintTemplate> templates = const [],
    List<String> printers = const [],
    String? defaultPrinter,
    bool preview = true,
    bool askCopies = false,
  }) : _routes = List.of(routes),
       _templates = List.of(templates),
       _printers = List.of(printers),
       _defaultPrinter = defaultPrinter,
       _preview = preview,
       _askCopies = askCopies;

  List<AgentPrintRoute> _routes;
  final List<AgentPrintTemplate> _templates;
  final List<String> _printers;
  final String? _defaultPrinter;
  bool _preview;
  bool _askCopies;

  @override
  Future<List<AgentPrintRoute>> load() async => List.of(_routes);

  @override
  Future<void> save(List<AgentPrintRoute> routes) async =>
      _routes = List.of(routes);

  @override
  Future<List<AgentPrintTemplate>> templates() async => List.of(_templates);

  @override
  Future<List<String>> printers() async => List.of(_printers);

  @override
  Future<String?> defaultPrinter() async => _defaultPrinter;

  @override
  Future<bool> previewBeforePayment() async => _preview;

  @override
  Future<void> setPreviewBeforePayment(bool value) async => _preview = value;

  @override
  Future<bool> askCopiesEachPrint() async => _askCopies;

  @override
  Future<void> setAskCopiesEachPrint(bool value) async => _askCopies = value;
}
