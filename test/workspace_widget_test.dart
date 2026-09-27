import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/main.dart';
import 'package:flutter_application_2/screens/review_screen.dart';

import 'workspace_persistence_test.dart' show MemoryWorkspaceStore;

void main() {
  testWidgets('Draft typing persists through disposal and app recreation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = MemoryWorkspaceStore();
    await tester.pumpWidget(MyApp(storage: storage));
    await tester.pumpAndSettle();
    Future<void> openNotes() async {
      await tester.tap(find.widgetWithText(ListTile, 'Test Case Review'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Reviewer Notes (optional)'),
        350,
        scrollable: find
            .descendant(
              of: find.byType(ReviewForm),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }

    await openNotes();
    await tester.enterText(
      find.widgetWithText(TextField, 'Reviewer Notes (optional)'),
      'Draft survives restart',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved locally'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MyApp(storage: storage));
    await tester.pumpAndSettle();
    await openNotes();
    expect(find.text('Draft survives restart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Load failure blocks sample overwrite and retry restores workspace',
    (tester) async {
      final storage = MemoryWorkspaceStore()..failRead = true;
      await tester.pumpWidget(MyApp(storage: storage));
      await tester.pumpAndSettle();
      expect(
        find.text('Stored data has not been overwritten.'),
        findsOneWidget,
      );
      expect(find.text('Total Test Cases'), findsNothing);
      expect(storage.writes, 0);
      storage.failRead = false;
      await tester.tap(find.text('Retry loading'));
      await tester.pumpAndSettle();
      expect(find.text('Total Test Cases'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
