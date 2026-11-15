// Chạy bởi single_instance_test: thử lấy khoá khi bản khác đang giữ.
import 'dart:io';

import 'package:print_agent_desktop/desktop/single_instance.dart';

Future<void> main(List<String> args) async {
  final r = await SingleInstance.acquire(Directory(args.first));
  stdout.writeln(r == null ? 'null' : 'acquired');
  exit(0);
}
