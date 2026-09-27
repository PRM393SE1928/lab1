import 'dart:io';

import 'package:flutter_application_2/services/excel_parser.dart';
import 'package:flutter_application_2/models/excel_import_result.dart';

Future<void> main(List<String> args) async {
  for (final path in args) {
    final timer = Stopwatch()..start();
    stdout.writeln('FILE $path');
    try {
      final result = await parseExcelBytesResponsive(
        File(path).readAsBytesSync(),
      );
      for (final diagnostic in result.diagnostics) {
        stdout.writeln(diagnostic.debugSummary);
      }
      stdout.writeln(
        'TOTAL ${result.testCases.length} cases; ${result.sheetCounts.length} imported sheets; '
        '${result.ignoredSheets.length} ignored; ${result.failedSheets.length} failed; '
        '${timer.elapsedMilliseconds} ms',
      );
      for (final warning in result.warnings) {
        stdout.writeln(warning);
      }
    } on ExcelImportException catch (error) {
      stdout.writeln('NOT IMPORTED: ${error.message}');
      stdout.writeln(
        '${error.diagnostics.length} sheets classified; ${timer.elapsedMilliseconds} ms',
      );
      for (final d in error.diagnostics.where(
        (d) => d.disposition == SheetDisposition.failed,
      )) {
        stdout.writeln(d.debugSummary);
      }
    }
  }
}
