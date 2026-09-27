import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/evaluation.dart';
import 'package:flutter_application_2/providers/app_state.dart';
import 'package:flutter_application_2/services/excel_service.dart';

import 'support/workbook_fixture.dart';

class PickerService extends ExcelService {
  XFile? nextFile;
  @override
  Future<XFile?> selectFile() async => nextFile;
}

void main() {
  test('Successful import replaces samples and resets reviews and drafts even when IDs match', () async {
    final picker = PickerService();
    final state = AppState(excelService: picker);
    addTearDown(state.dispose);
    state.draft('TC-AUTH-001').issues = 'Old draft';
    picker.nextFile = XFile.fromData(
      basicWorkbook(id: 'TC-AUTH-001'),
      path: 'project.xlsx',
    );
    await state.selectExcelFile();
    expect(await state.importSelectedExcel(), isTrue);
    expect(state.testCases, hasLength(1));
    expect(state.reviewed, 0);
    expect(state.count(ReviewStatus.notEvaluated), 1);
    expect(state.saved('TC-AUTH-001'), isNull);
    expect(state.draft('TC-AUTH-001').issues, '');
    expect(state.draft('TC-AUTH-001').requirementId, isNull);
    expect(state.requirements, isEmpty);
    expect(state.testCases.single.executionResult, 'Passed');
    expect(state.importedFileName, 'project.xlsx');
    expect(state.selectedId, 'TC-AUTH-001');
  });

  test(
    'Cancellation and parse failure preserve current cases and evaluations',
    () async {
      final picker = PickerService();
      final state = AppState(excelService: picker);
      addTearDown(state.dispose);
      await state.selectExcelFile();
      expect(state.selectedExcelFile, isNull);
      expect(state.reviewed, 1);
      picker.nextFile = XFile.fromData(
        Uint8List.fromList([1, 2]),
        path: 'broken.xlsx',
      );
      await state.selectExcelFile();
      expect(await state.importSelectedExcel(), isFalse);
      expect(state.importError, contains('Cannot read'));
      expect(state.testCases, hasLength(4));
      expect(state.reviewed, 1);
      expect(state.hasImportedCases, isFalse);
      expect(state.importing, isFalse);
    },
  );
}
