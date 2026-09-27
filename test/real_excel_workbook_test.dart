import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/evaluation.dart';
import 'package:flutter_application_2/providers/app_state.dart';

void main() {
  final report = Platform.environment['TEST_REPORT_XLSX'];
  final unit = Platform.environment['UNIT_TEST_XLSX'];
  test(
    'Real Report5 imports all 338 cases; Unit Test workbook preserves workspace',
    () async {
      final state = AppState();
      addTearDown(state.dispose);
      state.selectedExcelFile = XFile(report!);
      expect(
        await state.importSelectedExcel(),
        isTrue,
        reason: state.importError,
      );
      final result = state.importResult!;
      expect(result.testCases, hasLength(338));
      expect(result.testCases.map((t) => t.id).toSet(), hasLength(338));
      expect(result.sheetCounts, {
        'M01_Authentication': 30,
        'M02_Project_Management': 21,
        'M03_Document_Management': 113,
        'M04_BIM_3D_Viewer': 59,
        'M05_Approval_Workflow': 31,
        'M06_Issue_Tracking_BCF': 39,
        'M07_Notifications': 14,
        'M08_Dashboard_Reports': 14,
        'M09_User_Role_Permissions': 9,
        'M10_System_Settings': 8,
      });
      expect(result.sheetsScanned, 13);
      expect(result.ignoredSheets.map((s) => s.name), [
        'Cover',
        'Test Cases',
        'Test Statistics',
      ]);
      expect(result.failedSheets, isEmpty);
      expect(
        result.diagnostics
            .where((d) => d.importedRows > 0)
            .every((d) => d.headerRow == 10),
        isTrue,
      );
      expect(result.testCases.first.steps, hasLength(3));
      expect(result.testCases.first.executionResult, 'Passed');
      expect(state.reviewed, 0);
      final repeated = result.testCases
          .where((t) => t.displayId == 'TC-NOT-UI-05')
          .toList();
      expect(repeated, hasLength(2));
      final evaluation = state.draft(repeated.first.id);
      for (final criterion in Criterion.values) {
        evaluation.criteria[criterion] = ReviewStatus.warning;
      }
      evaluation.issues = 'Needs review';
      expect(state.save(repeated.first.id), isNull);
      expect(state.status(repeated.last.id), ReviewStatus.notEvaluated);
      state.selectedExcelFile = XFile(unit!);
      expect(await state.importSelectedExcel(), isFalse);
      expect(state.importError, contains('Test Case Report workbook'));
      expect(state.importDiagnostics, hasLength(48));
      expect(state.importResult, same(result));
      expect(state.testCases, hasLength(338));
      expect(state.reviewed, 1);
    },
    skip: report == null || unit == null
        ? 'Set TEST_REPORT_XLSX and UNIT_TEST_XLSX for read-only real-workbook validation.'
        : false,
  );
}
