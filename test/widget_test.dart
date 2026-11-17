import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badapple/main.dart';

void main() {
  testWidgets('启动后是黑底加一条白色横线', (WidgetTester tester) async {
    await tester.pumpWidget(const BadAppleApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.black);

    // 白线是一条高度很小的白色 Container。
    final Iterable<Container> containers =
        tester.widgetList<Container>(find.byType(Container));
    expect(
      containers.any((Container c) => c.color == Colors.white),
      isTrue,
    );

    // 让播放器初始化的重试定时器走完，避免测试结束时留下挂起的 Timer。
    await tester.pump(const Duration(seconds: 1));
  });
}
