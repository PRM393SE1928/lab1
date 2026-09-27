import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:flutter_application_2/models/evaluation.dart';
import 'package:flutter_application_2/models/evaluation_report.dart';
import 'package:flutter_application_2/models/test_case.dart';
import 'package:flutter_application_2/models/srs_section.dart';
import 'package:flutter_application_2/providers/app_state.dart';
import 'package:flutter_application_2/services/report_builder.dart';
import 'package:flutter_application_2/services/export_service.dart';
import 'package:flutter_application_2/services/excel_parser.dart';

TestCase reportCase(
  String id, {
  String? sourceId,
  String module = 'Auth',
  String description = 'Đăng nhập',
}) => TestCase(
  id: id,
  sourceId: sourceId,
  module: module,
  description: description,
  preconditions: '',
  steps: ['Open login', 'Enter account'],
  testData: '00123',
  expectedResult: 'Welcome',
  executionResult: 'Failed',
);
EvaluationReport fixtureReport() => EvaluationReport(
  testCases: [
    reportCase('a', sourceId: 'TC-01'),
    reportCase('b', sourceId: 'TC-01'),
    reportCase('c', module: 'Files'),
  ],
  evaluations: {
    'a': Evaluation(
      testCaseId: 'a',
      requirementId: 'internal_42',
      criteria: {for (final c in Criterion.values) c: ReviewStatus.pass},
      overrideStatus: ReviewStatus.warning,
      issues: '=HYPERLINK("https://example.test")',
      suggestedFix: 'Bổ sung dữ liệu\nKhông sửa SRS',
      reviewerNotes: '+original text',
      reviewedAt: DateTime.utc(2026, 9, 27),
    ),
    'b': Evaluation(
      testCaseId: 'b',
      criteria: {for (final c in Criterion.values) c: ReviewStatus.pass},
    ),
  },
  sections: [
    const SrsSection(
      id: 'internal_42',
      title: 'Login',
      blocks: ['Original source'],
      order: 0,
      sectionNumber: '3.2.1',
      parentSection: 'Authentication',
      category: 'Functional Requirement',
    ),
  ],
  createdAt: DateTime.utc(2026, 9, 27),
  sampleData: false,
  omittedDrafts: 1,
  excelName: 'real.xlsx',
  srsName: 'real.docx',
);
String textAt(Sheet sheet, int row, int column) =>
    sheet.rows[row][column]?.value.toString() ?? '';
Object? valueOf(CellValue? value) => switch (value) {
  IntCellValue() => value.value,
  DoubleCellValue() => value.value,
  _ => value.toString(),
};

void main() {
  test('Worksheet layout follows OOXML element order and required format attributes', () {
    final archive = ZipDecoder().decodeBytes(
      buildEvaluationReport(fixtureReport()),
    );
    for (final entry in archive.files.where(
      (e) => e.name.startsWith('xl/worksheets/') && e.name.endsWith('.xml'),
    )) {
      final root = XmlDocument.parse(utf8.decode(entry.content as List<int>))
          .rootElement;
      final children = root.childElements.toList();
      final order = [
        'sheetPr',
        'dimension',
        'sheetViews',
        'sheetFormatPr',
        'cols',
        'sheetData',
        'sheetCalcPr',
        'sheetProtection',
        'protectedRanges',
        'scenarios',
        'autoFilter',
        'sortState',
        'dataConsolidate',
        'customSheetViews',
        'mergeCells',
        'phoneticPr',
        'conditionalFormatting',
        'dataValidations',
        'hyperlinks',
        'printOptions',
        'pageMargins',
        'pageSetup',
        'headerFooter',
      ];
      final positions = children
          .map((e) => order.indexOf(e.name.local))
          .where((i) => i >= 0)
          .toList();
      expect(
        positions,
        orderedEquals([...positions]..sort()),
        reason: entry.name,
      );
      for (final format in children.where(
        (e) => e.name.local == 'sheetFormatPr',
      )) {
        expect(
          double.tryParse(format.getAttribute('defaultRowHeight') ?? ''),
          isNotNull,
          reason: entry.name,
        );
      }
      final widths = root.findAllElements('col').toList();
      expect(widths, isNotEmpty);
      if (entry.name.endsWith('sheet2.xml')) {
        expect(widths.last.getAttribute('max'), '${reportHeaders.length}');
      }
    }
  });
  test('Report has required fields, real SRS reference, safe text and distinct duplicate cases', () {
    final bytes = buildEvaluationReport(fixtureReport());
    final book = Excel.decodeBytes(bytes);
    expect(
      book.tables.keys,
      unorderedEquals(['Summary', 'Evaluations', 'By Module']),
    );
    final sheet = book['Evaluations'];
    expect(sheet.rows.first.map((c) => c?.value.toString()), reportHeaders);
    expect(sheet.maxRows, 4);
    expect(textAt(sheet, 1, 0), 'TC-01');
    expect(textAt(sheet, 2, 0), 'TC-01');
    expect(textAt(sheet, 1, 25), 'a');
    expect(textAt(sheet, 2, 25), 'b');
    expect(textAt(sheet, 1, 2), 'Authentication > Login');
    expect(textAt(sheet, 1, 3), '3.2.1');
    expect(textAt(sheet, 1, 12), 'WARNING');
    expect(textAt(sheet, 1, 13), 'PASS');
    expect(textAt(sheet, 1, 14), 'WARNING');
    expect(textAt(sheet, 1, 18), 'Failed');
    expect(textAt(sheet, 3, 12), 'NOT EVALUATED');
    expect(textAt(sheet, 1, 16), 'Bổ sung dữ liệu\nKhông sửa SRS');
    expect(textAt(sheet, 1, 22), '00123');
    expect(sheet.rows[1][15]!.value, isA<TextCellValue>());
    final zip = ZipDecoder().decodeBytes(bytes, verify: true);
    for (final entry in zip.files.where(
      (e) => e.name.startsWith('xl/worksheets/'),
    )) {
      expect(utf8.decode(entry.content as List<int>), isNot(contains('<f>')));
    }
  });
  test(
    'Summary and module statistics use all cases and saved overall overrides',
    () {
      final book = Excel.decodeBytes(buildEvaluationReport(fixtureReport()));
      final summary = {
        for (final row in book['Summary'].rows)
          row[0]!.value.toString(): valueOf(row[1]?.value),
      };
      expect(summary['Total Test Cases'], 3);
      expect(summary['Reviewed'], 2);
      expect(summary['Not Reviewed'], 1);
      expect(summary['PASS'], 1);
      expect(summary['WARNING'], 1);
      expect(summary['FAIL'], 0);
      expect(summary['PASS %'], closeTo(100 / 3, 0.0001));
      expect(summary['Cases with omitted draft changes'], 1);
      final byModule = book['By Module'];
      expect(textAt(byModule, 1, 0), 'Auth');
      expect(textAt(byModule, 1, 1), '2');
      expect(valueOf(byModule.rows[1][7]?.value), 50);
      expect(textAt(byModule, 2, 0), 'Files');
      expect(textAt(byModule, 2, 3), '1');
    },
  );
  test(
    'Snapshot excludes unsaved drafts and stays stable after further edits',
    () {
      final state = AppState();
      addTearDown(state.dispose);
      final id = state.selectedId;
      state.draft(id).issues = 'Unsaved secret';
      final snapshot = state.captureReport();
      expect(snapshot.omittedDrafts, 1);
      final oldIssue = snapshot.evaluations[id]!.issues;
      expect(oldIssue, isNot('Unsaved secret'));
      state.draft(id).issues = 'Later saved issue';
      expect(state.save(id), isNull);
      expect(snapshot.evaluations[id]!.issues, oldIssue);
      expect(
        state.captureReport().evaluations[id]!.issues,
        'Later saved issue',
      );
      expect(state.unsavedDraftCount, 0);
    },
  );
  test('Empty reports and oversized cells produce useful errors instead of data loss', () {
    EvaluationReport make(List<TestCase> cases) => EvaluationReport(
      testCases: cases,
      evaluations: {},
      sections: [],
      createdAt: DateTime.now(),
      sampleData: false,
    );
    expect(
      () => buildEvaluationReport(make([])),
      throwsA(isA<ReportExportException>()),
    );
    expect(
      () => buildEvaluationReport(
        make([reportCase('a', description: 'x' * 32768)]),
      ),
      throwsA(isA<ReportExportException>()),
    );
  });
  test('Service creates a readable XLSX on disk', () async {
    final directory = await Directory.systemTemp.createTemp('report_export_');
    addTearDown(() => directory.delete(recursive: true));
    final service = ExportService();
    final bytes = await service.generate(fixtureReport());
    final destination = '${directory.path}/report.xlsx';
    await service.save(bytes, destination);
    final book = Excel.decodeBytes(await File(destination).readAsBytes());
    expect(book['Evaluations'].maxRows, 4);
  });
  final realPath = Platform.environment['TEST_REPORT_XLSX'];
  test(
    'Real imported workbook exports every case and source execution without sample data',
    () async {
      final imported = parseExcelBytes(await File(realPath!).readAsBytes());
      final report = EvaluationReport(
        testCases: imported.testCases,
        evaluations: {},
        sections: [],
        createdAt: DateTime.now(),
        sampleData: false,
        excelName: 'Report5.xlsx',
      );
      final book = Excel.decodeBytes(buildEvaluationReport(report));
      final rows = book['Evaluations'].rows;
      expect(rows.length, imported.testCases.length + 1);
      for (var i = 0; i < imported.testCases.length; i++) {
        expect(
          rows[i + 1][0]!.value.toString(),
          imported.testCases[i].displayId,
        );
        expect(
          rows[i + 1][18]?.value?.toString() ?? '',
          imported.testCases[i].executionResult,
        );
        expect(rows[i + 1][12]!.value.toString(), 'NOT EVALUATED');
      }
    },
    skip: realPath == null
        ? 'Set TEST_REPORT_XLSX for real-file export validation.'
        : false,
  );
}
