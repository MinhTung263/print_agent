import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/ui/widgets/agent_spinner.dart';

void main() {
  testWidgets('vòng chờ của Agent là kiểu Cupertino, không phải Material', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AgentSpinner())),
      ),
    );
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('màu theo biểu tượng xung quanh (nút nền xanh thì vòng trắng)', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IconTheme(
            data: IconThemeData(color: Colors.white),
            child: AgentSpinner(size: 20),
          ),
        ),
      ),
    );
    final indicator = t.widget<CupertinoActivityIndicator>(
      find.byType(CupertinoActivityIndicator),
    );
    expect(indicator.color, Colors.white);
    expect(t.getSize(find.byType(AgentSpinner)), const Size(20, 20));
  });

  testWidgets('màu truyền vào được ưu tiên', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AgentSpinner(color: Colors.red)),
      ),
    );
    expect(
      t
          .widget<CupertinoActivityIndicator>(
            find.byType(CupertinoActivityIndicator),
          )
          .color,
      Colors.red,
    );
  });
}
