import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/excel_import_result.dart';
import 'package:flutter_application_2/services/excel_service.dart';

import 'support/workbook_fixture.dart';

Uint8List replaceXml(
  Uint8List bytes,
  String name,
  String Function(String) edit,
) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final original = archive.findFile(name)!;
  final data = utf8.encode(edit(utf8.decode(original.content as List<int>)));
  archive.addFile(ArchiveFile(name, data.length, data));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  test('ID-only tables import missing review fields and Test Case alias', () {
    final result = parseExcelBytes(
      workbookBytes({
        'Cases': [
          ['  TEST\nCASE:  '],
          ['TC-EMPTY-1'],
          ['TC-EMPTY-2'],
        ],
      }),
    );
    expect(result.testCases, hasLength(2));
    expect(result.testCases.first.steps, isEmpty);
    expect(result.testCases.first.expectedResult, isEmpty);
    expect(result.diagnostics.single.headerRow, 1);
  });

  test(
    'Header search counts non-empty rows rather than physical row numbers',
    () {
      final result = parseExcelBytes(
        workbookBytes({
          'Cases': [
            for (var i = 0; i < 80; i++) <Object?>[],
            ['Title'],
            ['TC ID', 'Test Case Procedure'],
            ['TC-1', 'Open page'],
          ],
        }),
      );
      expect(result.diagnostics.single.headerRow, 82);
      expect(result.testCases.single.steps, ['Open page']);
      expect(
        () => parseExcelBytes(
          workbookBytes({
            'Cases': [
              for (var i = 0; i < 30; i++) ['Metadata $i'],
              ['TC ID'],
              ['TC-1'],
            ],
          }),
        ),
        throwsA(isA<ExcelImportException>()),
      );
    },
  );

  test(
    'Row 10 headers, merged/unmerged headings, rounds and duplicate IDs',
    () {
      final bytes = workbookBytes({
        'Module': [
          ['Feature', 'Authentication'],
          for (var i = 0; i < 8; i++) <Object?>[],
          [
            'Test Case ID',
            'Test Case Description',
            'Test Case Procedure',
            'Expected Results',
            'Pre-conditions',
            'Round 1',
            'Round 2',
            'Round 3',
          ],
          ['Login section'],
          [
            'TC-1',
            'Login',
            'Open\nSubmit',
            'Home page',
            null,
            'Failed',
            'Passed',
            '',
          ],
          ['TC-2', 'Logout', null, null, null, 'Failed', 'Failed', 'Passed'],
          ['Permission section'],
          ['TC-3'],
          ['TC-4'],
          ['TC-4'],
        ],
      });
      final book = Excel.decodeBytes(bytes);
      book['Module'].merge(
        CellIndex.indexByString('A11'),
        CellIndex.indexByString('H11'),
      );
      final result = parseExcelBytes(Uint8List.fromList(book.encode()!));
      expect(result.testCases, hasLength(5));
      expect(result.testCases.first.executionResult, 'Passed');
      expect(
        result.testCases.first.additionalFields['[Import] Execution source'],
        'Round 2',
      );
      expect(result.testCases.first.additionalFields['Round 1'], 'Failed');
      expect(result.testCases[1].executionResult, 'Passed');
      expect(
        result.testCases[2].additionalFields['[Import] Section'],
        'Permission section',
      );
      expect(result.testCases.map((t) => t.id).toSet(), hasLength(5));
      expect(
        result.testCases.map((t) => t.displayId).where((id) => id == 'TC-4'),
        hasLength(2),
      );
    },
  );

  test('Ignores huge declared empty ranges without expanding them', () {
    final bytes = replaceXml(
      basicWorkbook(),
      'xl/worksheets/sheet1.xml',
      (xml) => xml.replaceFirst(
        RegExp(r'<dimension[^>]*>'),
        '<dimension ref="A1:XFD1048576"/>',
      ),
    );
    final result = parseExcelBytes(bytes);
    expect(result.testCases, hasLength(1));
    expect(result.diagnostics.single.nonEmptyRows, 2);
    expect(result.diagnostics.single.declaredRange, 'A1:XFD1048576');
  });

  test('Malformed sheet is classified as failed while other sheets import', () {
    final bytes = replaceXml(
      workbookBytes({
        'Good': [
          ['ID'],
          ['TC-1'],
        ],
        'Bad': [
          ['ID'],
          ['TC-2'],
        ],
      }),
      'xl/worksheets/sheet2.xml',
      (_) => '<worksheet><broken>',
    );
    final result = parseExcelBytes(bytes);
    expect(result.testCases.single.id, 'TC-1');
    expect(result.failedSheets.single.name, 'Bad');
  });

  test('Async parser yields to event loop and reports real stages', () async {
    final stages = <String>[];
    var ticks = 0;
    final timer = Timer.periodic(
      const Duration(milliseconds: 1),
      (_) => ticks++,
    );
    final result = await parseExcelBytesResponsive(
      basicWorkbook(),
      onProgress: stages.add,
    );
    timer.cancel();
    expect(result.testCases, hasLength(1));
    expect(ticks, greaterThan(0));
    expect(stages.first, 'Scanning worksheets...');
    expect(stages.any((s) => s.startsWith('Parsing Test Cases')), isTrue);
    expect(stages.last, 'Import completed.');
  });
}
