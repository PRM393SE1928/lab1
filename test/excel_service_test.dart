import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/excel_import_result.dart';
import 'package:flutter_application_2/services/excel_column_mapping.dart';
import 'package:flutter_application_2/services/excel_service.dart';

import 'support/workbook_fixture.dart';

void main() {
  test(
    'Reads all recognized sheets, title rows, aliases and reordered columns',
    () {
      final result = parseExcelBytes(
        workbookBytes({
          'Cover': [
            ['University test report'],
            ['Author', 'QA team'],
          ],
          'Login': [
            ['Authentication test suite'],
            [],
            [
              'Expected\nResult',
              ' TC_ID ',
              'Test Case Description',
              'Pre-condition',
              'Procedure / Steps',
              'Test Data',
              'Execution Status',
              'Actual Result',
              'Priority',
            ],
            [
              'Dashboard',
              ' TC-01 ',
              'Valid login',
              null,
              'Open\r\nLogin\rSubmit',
              ' user\u00a0one ',
              'Passed',
              'Dashboard opened',
              'High',
            ],
            [],
            [
              'Expected Result',
              'TC ID',
              'Description',
              'Precondition',
              'Steps',
              'Test Data',
              'Status',
              'Actual Result',
              'Priority',
            ],
            [null, 'TC-02', 'Missing password'],
            ['Ignored orphan row', null, 'Missing ID'],
          ],
          'Reports': [
            ['Case ID', 'Module', 'Title', 'Expected Output', 'Result'],
            ['TC-03', 'Exports', 'Download report', 'Workbook', 'Failed'],
          ],
        }),
      );
      expect(result.testCases.map((t) => t.id), ['TC-01', 'TC-02', 'TC-03']);
      expect(result.sheetCounts, {'Login': 2, 'Reports': 1});
      final first = result.testCases.first;
      expect(first.module, 'Login');
      expect(first.preconditions, '');
      expect(first.steps, ['Open', 'Login', 'Submit']);
      expect(first.testData, 'user one');
      expect(first.executionResult, 'Passed');
      expect(first.additionalFields['Actual Result'], 'Dashboard opened');
      expect(first.additionalFields['Priority'], 'High');
      expect(first.additionalFields['[Import] Row'], '4');
      expect(result.testCases[1].steps, isEmpty);
      expect(result.testCases[1].expectedResult, '');
      expect(result.testCases.last.module, 'Exports');
      expect(result.ignoredSheets.map((s) => s.name), contains('Cover'));
      expect(result.warnings.join('\n'), isNot(contains('Cover')));
      expect(result.warnings.join('\n'), contains('without a Test Case ID'));
    },
  );

  test('Typed Excel values are normalized and formulas explicitly flagged', () {
    final result = parseExcelBytes(
      workbookBytes({
        'Cases': [
          ['ID', 'Description', 'Test Data', 'Date', 'Enabled', 'Formula'],
          [
            42,
            'Typed values',
            12.5,
            DateCellValue(year: 2026, month: 9, day: 25),
            true,
            FormulaCellValue('1+1'),
          ],
        ],
      }),
    );
    final t = result.testCases.single;
    expect(t.id, '42');
    expect(t.testData, '12.5');
    expect(t.additionalFields['Date'], '2026-09-25');
    expect(t.additionalFields['Enabled'], 'true');
    expect(t.additionalFields['Formula'], '=1+1');
    expect(result.warnings.join(), contains('formula text'));
  });

  test('Duplicate IDs across sheets retain separate internal identities', () {
    final result = parseExcelBytes(
      workbookBytes({
        for (final name in ['A', 'B'])
          name: [
            ['ID', 'Description'],
            ['TC-1', 'Case'],
          ],
      }),
    );
    expect(result.testCases.map((t) => t.displayId), ['TC-1', 'TC-1']);
    expect(result.testCases.map((t) => t.id).toSet(), hasLength(2));
    expect(result.failedSheets, isEmpty);
    expect(result.warnings.single, contains('preserved as separate cases'));
  });

  test(
    'Empty, invalid, unrecognized and header-only files report useful errors',
    () {
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
        workbookBytes({
          'Summary': [
            ['Total', 'Passed'],
            [10, 4],
          ],
        }),
        workbookBytes({
          'Cases': [
            ['ID', 'Description'],
          ],
        }),
      ]) {
        expect(
          () => parseExcelBytes(bytes),
          throwsA(isA<ExcelImportException>()),
        );
      }
      expect(
        () => parseExcelBytes(
          workbookBytes({
            'Cases': [
              ['Description', 'Steps'],
              ['Case', 'Open'],
            ],
          }),
        ),
        throwsA(
          isA<ExcelImportException>().having(
            (e) => e.message,
            'message',
            contains('Test Case ID'),
          ),
        ),
      );
    },
  );

  test('Evaluation status is never used as execution status', () {
    final result = parseExcelBytes(
      workbookBytes({
        'Cases': [
          ['ID', 'Description', 'Evaluation Status', 'Actual Result'],
          ['TC-1', 'Case', 'PASS', 'Page opened'],
        ],
      }),
    );
    expect(result.testCases.single.executionResult, 'Page opened');
    expect(
      result.testCases.single.additionalFields['Evaluation Status'],
      'PASS',
    );
    expect(
      ExcelColumnMapping.detect([
        'Execution Status',
      ])[ExcelField.executionResult],
      0,
    );
  });

  test(
    'File service validates extension and imports actual XLSX bytes',
    () async {
      final service = ExcelService();
      await expectLater(
        service.importFile(XFile.fromData(Uint8List(0), path: 'test.xls')),
        throwsA(isA<ExcelImportException>()),
      );
      final result = await service.importFile(
        XFile.fromData(basicWorkbook(), path: 'test.xlsx'),
      );
      expect(result.testCases.single.id, 'REAL-001');
    },
  );
}
