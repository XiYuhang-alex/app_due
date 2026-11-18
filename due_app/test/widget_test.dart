import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:due_app/main.dart';

void main() {
  testWidgets('首页空列表可正常渲染', (WidgetTester tester) async {
    await tester.pumpWidget(const DueApp(initialTasks: []));
    await tester.pumpAndSettle();

    expect(find.text('全部 · 0 项'), findsOneWidget);
  });

  testWidgets('详情页删除待办需要二次确认', (WidgetTester tester) async {
    final task = Task(
      id: 'x1',
      name: '测试任务',
      due: DateTime.now().add(const Duration(hours: 2)),
      importance: Importance.normal,
      remind: false,
    );
    await tester.pumpWidget(DueApp(initialTasks: [task]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('测试任务'));
    await tester.pumpAndSettle();
    expect(find.text('待办详情'), findsOneWidget);

    await tester.tap(find.text('删除待办'));
    await tester.pumpAndSettle();
    expect(find.text('删除待办？'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('待办详情'), findsNothing);
    expect(find.text('全部 · 0 项'), findsOneWidget);
  });
}
