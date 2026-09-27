import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/excel_import_result.dart';
import 'package:flutter_application_2/providers/app_state.dart';
import 'package:flutter_application_2/screens/app_shell.dart';
import 'package:flutter_application_2/screens/import_screen.dart';
import 'package:flutter_application_2/screens/review_screen.dart';
import 'package:flutter_application_2/services/excel_service.dart';
import 'package:flutter_application_2/widgets/summary_card.dart';

import 'support/workbook_fixture.dart';

class WidgetExcelService extends ExcelService {
  WidgetExcelService({String id = 'REAL-001'}) : bytes = basicWorkbook(id: id);
  final Uint8List bytes;
  @override
  Future<XFile?> selectFile() async =>
      XFile.fromData(bytes, path: 'project.xlsx');
  @override
  Future<ExcelImportResult> importFile(
    XFile file, {
    void Function(String)? onProgress,
  }) async => parseExcelBytes(bytes);
}

void main() {
  testWidgets(
    'Select and import XLSX updates dashboard and review without sample mappings',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState(excelService: WidgetExcelService());
      addTearDown(state.dispose);
      await tester.pumpWidget(MaterialApp(home: AppShell(state: state)));
      await tester.tap(find.widgetWithText(ListTile, 'Import Files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select Test Case File'));
      await tester.pumpAndSettle();
      expect(find.text('File name: project.xlsx'), findsOneWidget);
      await tester.tap(find.text('Import / Parse'));
      await tester.pumpAndSettle();
      expect(state.hasImportedCases, isTrue);
      await tester.scrollUntilVisible(
        find.text('Open Test Case Review'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ImportScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Open Test Case Review'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Test Case Review'));
      await tester.pumpAndSettle();
      expect(find.text('Verify real login'), findsWidgets);
      expect(find.text('TC-AUTH-001'), findsNothing);
      expect(state.requirements, isEmpty);
      await tester.tap(find.widgetWithText(ListTile, 'Dashboard'));
      await tester.pumpAndSettle();
      final cards = tester.widgetList<SummaryCard>(find.byType(SummaryCard));
      expect(cards.firstWhere((c) => c.label == 'Total Test Cases').value, '1');
      expect(cards.firstWhere((c) => c.label == 'Reviewed').value, '0');
      expect(cards.firstWhere((c) => c.label == 'PASS').value, '0');
      await tester.tap(find.widgetWithText(ListTile, 'Import Files'));
      await tester.pumpAndSettle();
      expect(find.text('File name: project.xlsx'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Import refreshes an open review even when the case ID is reused',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState(
        excelService: WidgetExcelService(id: 'TC-AUTH-001'),
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(MaterialApp(home: AppShell(state: state)));
      await tester.tap(find.widgetWithText(ListTile, 'Test Case Review'));
      await tester.pumpAndSettle();
      final oldForm = tester.state(find.byType(ReviewForm));
      await state.selectExcelFile();
      await state.importSelectedExcel();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ReviewForm)), isNot(same(oldForm)));
      expect(find.text('Verify real login'), findsWidgets);
      expect(state.draft('TC-AUTH-001').issues, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
