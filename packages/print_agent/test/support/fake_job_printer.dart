import 'dart:typed_data';

import 'package:print_agent/print_agent.dart';

import 'fake_host.dart';

class FakeJobPrinter implements AgentJobPrinter<FakePrinter> {
  AgentPrintFailure? failure;

  /// Lỗi trả cho N lần in đầu (rồi in được) — mô phỏng hết giấy rồi thay giấy.
  final List<AgentPrintFailure> failuresFirst = [];
  final List<PrintRelayJob> printed = [];
  Duration delay = Duration.zero;

  @override
  FakePrinter resolve(PrintRelayJob job) => FakePrinter(
    refId: job.printer.id,
    refKind: job.printer.isBuiltIn
        ? AgentPrinterKind.builtIn
        : AgentPrinterKind.lan,
    refAddress: job.printer.address,
    refName: job.printer.name ?? '',
  );

  @override
  Future<AgentPrintFailure?> printJob(
    FakePrinter printer,
    PrintRelayJob job,
  ) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failuresFirst.isNotEmpty) return failuresFirst.removeAt(0);
    printed.add(job);
    return failure;
  }

  @override
  PrintRelayPrinter? targetOf(FakePrinter printer) =>
      PrintRelayPrinter(address: printer.refAddress ?? '', id: printer.refId);

  @override
  Future<Uint8List> fitReceipt(Uint8List image, String paper) async => image;

  @override
  AgentBuiltInSpec? builtInSpec() => const AgentBuiltInSpec(
    paper: 'size58',
    templates: ['temporaryPrintForm'],
  );

  @override
  List<String> get defaultTemplates => const ['temporaryPrintForm'];

  @override
  FakePrinter peerBuiltIn(PeerBuiltInPrinter printer) => FakePrinter(
    refKind: AgentPrinterKind.builtIn,
    refAddress: printer.address,
    refName: PeerBuiltInPrinters.displayName(printer),
  );

  @override
  String messageName(FakePrinter printer) => printer.refName;

  @override
  Future<T> withProgress<T>(FakePrinter printer, Future<T> Function() a) => a();
}
