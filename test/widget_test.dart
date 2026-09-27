import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/main.dart';
import 'package:flutter_application_2/screens/review_screen.dart';

void main() {
  Future<void> start(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
  }

  Future<void> navigate(
    WidgetTester tester,
    String label, {
    bool compact = false,
  }) async {
    await tester.tap(
      compact ? find.byTooltip(label) : find.widgetWithText(ListTile, label),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Desktop navigation and issue links open the review form', (
    tester,
  ) async {
    await start(tester, const Size(1280, 800));
    expect(find.text('Total Test Cases'), findsOneWidget);
    expect(find.textContaining('25.0%'), findsOneWidget);
    for (final page in ['Import Files', 'Reports', 'Issues']) {
      await navigate(tester, page);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('TC-AUTH-001'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Test Case Information'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Review edits survive navigation and save to the issues table', (
    tester,
  ) async {
    await start(tester, const Size(1280, 900));
    await navigate(tester, 'Test Case Review');
    final issues = find.widgetWithText(TextField, 'Issues');
    await tester.scrollUntilVisible(
      issues,
      450,
      scrollable: find
          .descendant(
            of: find.byType(Card).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(issues, 'Missing a concrete account.');
    await navigate(tester, 'Dashboard');
    await navigate(tester, 'Test Case Review');
    final formScroll = find
        .descendant(
          of: find.byType(ReviewForm),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Issues'),
      450,
      scrollable: formScroll,
    );
    expect(find.text('Missing a concrete account.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save Evaluation'),
      350,
      scrollable: formScroll,
    );
    await tester.drag(formScroll, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Evaluation'));
    await tester.pumpAndSettle();
    expect(find.text('Evaluation saved for this session.'), findsOneWidget);
    await navigate(tester, 'Issues');
    expect(find.text('Missing a concrete account.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(900, 650), const Size(640, 600)]) {
    testWidgets('Screens fit at ${size.width} pixels', (tester) async {
      await start(tester, size);
      for (final page in [
        'Import Files',
        'Test Case Review',
        'Issues',
        'Reports',
        'Dashboard',
      ]) {
        await navigate(tester, page, compact: true);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
