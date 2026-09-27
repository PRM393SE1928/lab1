import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/evaluation.dart';
import '../models/evaluation_report.dart';
import '../models/test_case.dart';

class ReportExportException implements Exception {
  const ReportExportException(this.message);
  final String message;
  @override
  String toString() => message;
}

const reportHeaders = [
  'Test Case ID',
  'Module',
  'Related SRS Requirement',
  'SRS Reference',
  'SRS Category',
  'Requirement Traceability',
  'Step Clarity',
  'Step Completeness',
  'Test Data / Preconditions',
  'Expected Result Correctness',
  'SRS Consistency',
  'Testability / Executability',
  'Overall Evaluation',
  'Suggested Overall Evaluation',
  'Manual Override',
  'Issues',
  'Suggested Fix',
  'Reviewer Notes',
  'Original Execution Result',
  'Description',
  'Preconditions',
  'Steps',
  'Test Data',
  'Expected Result',
  'Reviewed At (UTC)',
  'Application Case Key',
];

Uint8List buildEvaluationReport(EvaluationReport report) {
  if (report.testCases.isEmpty) {
    throw const ReportExportException('There are no test cases to export.');
  }
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'Summary');
  final detail = excel['Evaluations'],
      summary = excel['Summary'],
      modules = excel['By Module'];
  final heading = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.fromHexString('#243B64'),
    textWrapping: TextWrapping.WrapText,
    verticalAlign: VerticalAlign.Top,
  );
  final textStyle = CellStyle(
    textWrapping: TextWrapping.WrapText,
    verticalAlign: VerticalAlign.Top,
  );
  void row(Sheet sheet, List<Object> values, {bool header = false}) {
    final rowIndex = sheet.maxRows;
    final cells = <CellValue>[];
    for (final value in values) {
      if (value is int) {
        cells.add(IntCellValue(value));
      } else if (value is double) {
        cells.add(DoubleCellValue(value));
      } else {
        final text = value.toString();
        if (text.length > 32767) {
          throw ReportExportException(
            'A value in ${sheet.sheetName}, row ${rowIndex + 1}, column ${cells.length + 1} exceeds Excel’s 32,767-character limit. Shorten that field before exporting. No report was saved.',
          );
        }
        // Explicit text cells retain leading zeros and formula-like source text.
        cells.add(TextCellValue(text));
      }
    }
    sheet.appendRow(cells);
    for (var col = 0; col < cells.length; col++) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
          )
          .cellStyle = header
          ? heading
          : values[col] is double
          ? textStyle.copyWith(numberFormat: NumFormat.standard_2)
          : textStyle;
    }
    if (header) sheet.setRowHeight(rowIndex, 42);
  }

  ReviewStatus status(TestCase t) =>
      report.evaluations[t.id]?.overallStatus ?? ReviewStatus.notEvaluated;
  List<Object> stats(List<TestCase> cases) {
    int count(ReviewStatus s) => cases.where((t) => status(t) == s).length;
    final notReviewed = count(ReviewStatus.notEvaluated);
    final pass = count(ReviewStatus.pass),
        warning = count(ReviewStatus.warning),
        fail = count(ReviewStatus.fail);
    double percent(int n) => cases.isEmpty ? 0 : n * 100 / cases.length;
    return [
      cases.length,
      cases.length - notReviewed,
      notReviewed,
      pass,
      warning,
      fail,
      percent(pass),
      percent(warning),
      percent(fail),
    ];
  }

  row(detail, reportHeaders, header: true);
  // excel 4.0.6 inserts sheetFormatPr ahead of dimension/sheetViews and omits
  // its required defaultRowHeight when setting default widths. Excel repairs
  // that invalid worksheet. Explicit per-column widths avoid the broken path.
  for (var col = 0; col < reportHeaders.length; col++) {
    detail.setColumnWidth(col, 22);
  }
  for (final col in [2, 15, 16, 17, 19, 20, 21, 22, 23]) {
    detail.setColumnWidth(col, 48);
  }
  for (final t in report.testCases) {
    final e = report.evaluations[t.id];
    final section = report.sections[e?.requirementId];
    row(detail, [
      t.displayId,
      t.module,
      section?.path ?? 'Not mapped',
      section?.sectionNumber ?? '',
      section?.category ?? '',
      for (final c in Criterion.values)
        (e?.criteria[c] ?? ReviewStatus.notEvaluated).label,
      status(t).label,
      (e?.suggestedStatus ?? ReviewStatus.notEvaluated).label,
      e?.overrideStatus?.label ?? '',
      e?.issues ?? '',
      e?.suggestedFix ?? '',
      e?.reviewerNotes ?? '',
      t.executionResult,
      t.description,
      t.preconditions,
      t.steps.indexed.map((s) => '${s.$1 + 1}. ${s.$2}').join('\n'),
      t.testData,
      t.expectedResult,
      e?.reviewedAt?.toUtc().toIso8601String() ?? '',
      t.id,
    ]);
    final color = switch (status(t)) {
      ReviewStatus.pass => '#E2F0D9',
      ReviewStatus.warning => '#FFF2CC',
      ReviewStatus.fail => '#FCE4D6',
      ReviewStatus.notEvaluated => '#EEEEEE',
    };
    detail
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 12,
            rowIndex: detail.maxRows - 1,
          ),
        )
        .cellStyle = textStyle.copyWith(
      backgroundColorHexVal: ExcelColor.fromHexString(color),
      boldVal: true,
    );
  }
  row(summary, ['Test Case Evaluation Report', 'Value'], header: true);
  row(summary, [
    'Exported at (UTC)',
    report.createdAt.toUtc().toIso8601String(),
  ]);
  row(summary, [
    'Data source',
    report.sampleData
        ? 'SAMPLE DATA — demonstration only'
        : 'Imported Test Cases',
  ]);
  row(summary, ['Test Case workbook', report.excelName ?? 'Sample data']);
  row(summary, [
    'SRS document',
    report.srsName ?? (report.sampleData ? 'Sample SRS' : 'Not imported'),
  ]);
  row(summary, [
    'Evaluation scope',
    'Saved evaluations only; unsaved draft changes are excluded.',
  ]);
  row(summary, ['Cases with omitted draft changes', report.omittedDrafts]);
  row(summary, [
    'Percentage denominator',
    'All Test Cases (or all cases within each module). Values range from 0 to 100.',
  ]);
  row(summary, [
    'Original Execution Result',
    'Source execution outcome only; independent of the design evaluation.',
  ]);
  row(summary, [
    'Application Case Key',
    'Internal key to distinguish duplicate source Test Case IDs; not an SRS reference.',
  ]);
  const labels = [
    'Total Test Cases',
    'Reviewed',
    'Not Reviewed',
    'PASS',
    'WARNING',
    'FAIL',
    'PASS %',
    'WARNING %',
    'FAIL %',
  ];
  final totals = stats(report.testCases);
  for (var i = 0; i < labels.length; i++) {
    row(summary, [labels[i], totals[i]]);
  }
  row(summary, [
    'Review Progress %',
    (totals[1] as int) * 100 / report.testCases.length,
  ]);
  summary.setColumnWidth(0, 38);
  summary.setColumnWidth(1, 95);
  row(modules, ['Module', ...labels], header: true);
  final names = report.testCases.map((t) => t.module).toSet().toList()..sort();
  for (final name in names) {
    row(modules, [
      name,
      ...stats(report.testCases.where((t) => t.module == name).toList()),
    ]);
  }
  for (var col = 0; col < labels.length + 1; col++) {
    modules.setColumnWidth(col, 20);
  }
  modules.setColumnWidth(0, 42);
  excel.setDefaultSheet('Summary');
  final bytes = excel.encode();
  if (bytes == null) {
    throw const ReportExportException('Unable to generate the Excel report.');
  }
  return Uint8List.fromList(bytes);
}
