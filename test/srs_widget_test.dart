import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/srs_section.dart';
import 'package:flutter_application_2/providers/app_state.dart';
import 'package:flutter_application_2/screens/review_screen.dart';
import 'package:flutter_application_2/screens/import_screen.dart';
import 'package:flutter_application_2/services/srs_service.dart';
import 'package:flutter_application_2/widgets/srs_widgets.dart';

import 'support/docx_fixture.dart';

class WidgetSrsService extends SrsService {
  @override
  Future<XFile?> selectFile() async =>
      XFile.fromData(docxFixture(), path: 'Project.docx');
  @override
  Future<SrsIndex> importFile(
    XFile file, {
    void Function(String)? onProgress,
  }) async => SrsIndex(parseSrsBytes(await file.readAsBytes()));
}

void main() {
  testWidgets(
    'Import controls select DOCX and require confirmation before clearing mappings',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState(srsService: WidgetSrsService());
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: state,
              builder: (_, _) =>
                  ImportScreen(state: state, onOpenReview: () {}),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Select SRS'));
      await tester.pumpAndSettle();
      expect(find.text('File name: Project.docx'), findsOneWidget);
      expect(find.text('Status: Ready to parse'), findsOneWidget);
      await tester.tap(find.text('Parse SRS'));
      // The import progress indicator remains active behind confirmation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Replace SRS?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(state.srsSections, isEmpty);
      expect(state.mappedCaseCount, 1);
      await tester.tap(find.text('Parse SRS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Replace SRS'));
      await tester.pumpAndSettle();
      expect(find.text('Status: Completed'), findsOneWidget);
      expect(find.text('Sections detected: 4'), findsOneWidget);
      expect(state.testCases, hasLength(4));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Reviewer searches, selects, sees content, changes and removes mapping',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState()
        ..srsIndex = SrsIndex(parseSrsBytes(docxFixture()));
      state.selectedId = state.testCases[1].id;
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReviewForm(state: state)),
        ),
      );
      Future<void> reveal(String label) async {
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ReviewForm),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }

      await reveal('Find Requirement');
      await tester.tap(find.text('Find Requirement'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search section, title or content'),
        'ĐĂNG  NHẬP',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 sections'), findsOneWidget);
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(find.byType(SrsSearchDialog), findsNothing);
      expect(
        state.draft(state.selectedId).requirementId,
        state.srsSections[2].id,
      );
      await reveal('Change Requirement');
      expect(find.textContaining('Keep original wording.'), findsOneWidget);
      await tester.tap(find.text('Change Requirement'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search section, title or content'),
        'reset code',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(
        state.draft(state.selectedId).requirementId,
        state.srsSections[3].id,
      );
      await reveal('Remove Mapping');
      await tester.tap(find.text('Remove Mapping'));
      await tester.pumpAndSettle();
      expect(state.draft(state.selectedId).requirementId, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
