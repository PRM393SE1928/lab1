import 'dart:typed_data';

import '../models/excel_import_result.dart';
import '../models/test_case.dart';
import 'excel_column_mapping.dart';
import 'xlsx_reader.dart';

ExcelImportResult parseExcelBytes(Uint8List bytes) {
  final job = _ImportJob(bytes);
  for (final _ in job.run()) {}
  return job.result!;
}

Future<ExcelImportResult> parseExcelBytesResponsive(
  Uint8List bytes, {
  void Function(String)? onProgress,
}) async {
  final job = _ImportJob(bytes);
  for (final status in job.run()) {
    if (status != null) onProgress?.call(status);
    // compute() uses the main thread on web. Explicitly yield between bounded
    // XML row batches instead, so progress can paint and input can be handled.
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  return job.result!;
}

class _Header {
  _Header(this.row, this.labels, this.mapping);
  final int row;
  final List<String> labels;
  final Map<ExcelField, int> mapping;
}

class _ImportJob {
  _ImportJob(this.bytes);
  final Uint8List bytes;
  ExcelImportResult? result;
  final cases = <TestCase>[];
  final diagnostics = <SheetImportDiagnostic>[];
  final warnings = <String>[];
  static const ignoredNames = {
    'cover',
    'statistics',
    'teststatistics',
    'summary',
    'functions',
  };

  Iterable<String?> run() sync* {
    final timer = Stopwatch()..start();
    if (bytes.isEmpty) {
      throw const ExcelImportException('The selected file is empty.');
    }
    yield 'Scanning worksheets...';
    XlsxReader reader;
    try {
      reader = XlsxReader(bytes);
    } catch (_) {
      throw const ExcelImportException(
        'Cannot read this Excel workbook. It may be corrupted, password-protected, or not an .xlsx file. Please select the original Test Case Report workbook.',
      );
    }
    // This project's Unit Test export is a transposed function matrix. Its
    // explicit cover title plus function-index/sheet structure is conclusive;
    // don't spend time decoding 45 irrelevant function sheets.
    var unitWorkbook = false;
    final coverName = reader.sheets.keys
        .where((s) => ExcelColumnMapping.normalize(s) == 'cover')
        .firstOrNull;
    if (coverName != null &&
        reader.sheets.keys.any(
          (s) => ExcelColumnMapping.normalize(s) == 'functions',
        ) &&
        reader.sheets.keys
            .where(
              (s) => !ignoredNames.contains(ExcelColumnMapping.normalize(s)),
            )
            .every((s) => RegExp(r'^F\d+[_ ]').hasMatch(s))) {
      final cover = SparseSheet(coverName);
      for (final _ in reader.readSheet(reader.sheets[coverName]!, cover)) {
        yield null;
      }
      unitWorkbook = cover.rows
          .take(10)
          .expand((r) => r.cells.values)
          .any((s) => ExcelColumnMapping.normalize(s) == 'unittestdocument');
    }
    var scanned = 0;
    for (final entry in reader.sheets.entries) {
      scanned++;
      if (unitWorkbook ||
          ignoredNames.contains(ExcelColumnMapping.normalize(entry.key))) {
        diagnostics.add(
          SheetImportDiagnostic(
            name: entry.key,
            disposition: SheetDisposition.ignored,
            note: unitWorkbook
                ? 'Unit Test/function workbook (identified from cover and function index).'
                : 'Metadata/statistics/function index.',
          ),
        );
        continue;
      }
      yield 'Scanning worksheets ($scanned/${reader.sheets.length}): ${entry.key}';
      final sheet = SparseSheet(entry.key);
      _Header? header;
      try {
        for (final _ in reader.readSheet(entry.value, sheet)) {
          yield null;
        }
        header = _findHeader(sheet);
        if (header == null) {
          final labels = sheet.rows
              .take(30)
              .expand((r) => r.cells.values)
              .map(ExcelColumnMapping.normalize)
              .toSet();
          final unitMatrix =
              labels.contains('functioncode') &&
              (labels.contains('condition') || labels.contains('linesofcode'));
          diagnostics.add(
            _diagnostic(
              sheet,
              SheetDisposition.ignored,
              note: unitMatrix
                  ? 'Unit Test/function condition matrix, not a row-based Test Case Report.'
                  : 'No Test Case ID header in the first 30 non-empty rows; metadata/index or unsupported layout.',
            ),
          );
          continue;
        }
        yield 'Parsing Test Cases ($scanned/${reader.sheets.length}): ${entry.key}';
        final imported = <TestCase>[];
        var missingIds = 0;
        var section = '';
        var current = header;
        final body = sheet.rows.where((r) => r.number > header!.row).toList();
        final tcPatternCount = body
            .where(
              (r) => r.at(header!.mapping[ExcelField.id]).startsWith('TC-'),
            )
            .length;
        final usesTcPattern = tcPatternCount > body.length / 2;
        final sectionRows = <int>{
          for (final merge in sheet.merges)
            if (merge.firstRow == merge.lastRow &&
                merge.firstColumn <= header.mapping[ExcelField.id]! &&
                merge.lastColumn > header.mapping[ExcelField.id]!)
              merge.firstRow,
        };
        for (final row in body) {
          final rowId = row.at(current.mapping[ExcelField.id]);
          final unmergedHeading =
              usesTcPattern &&
              current.mapping.length > 1 &&
              !rowId.startsWith('TC-') &&
              RegExp(r'\s').hasMatch(rowId);
          if ((sectionRows.contains(row.number) || unmergedHeading) &&
              row.cells.length == 1) {
            section = row.cells.values.single;
            continue;
          }
          final id = row.at(current.mapping[ExcelField.id]);
          // Repeated header rows are recognized without re-mapping every data row.
          if (ExcelColumnMapping.aliases[ExcelField.id]!.any(
            (a) =>
                ExcelColumnMapping.normalize(a) ==
                ExcelColumnMapping.normalize(id),
          )) {
            final repeated = _headerAt(row);
            if (repeated != null) {
              current = repeated;
              continue;
            }
          }
          if (id.isEmpty) {
            missingIds++;
            continue;
          }
          String field(ExcelField field) => row.at(current.mapping[field]);
          final extra = <String, String>{};
          for (final cell in row.cells.entries) {
            final label =
                cell.key < current.labels.length &&
                    current.labels[cell.key].isNotEmpty
                ? current.labels[cell.key]
                : 'Column ${columnName(cell.key)}';
            var key = label;
            if (extra.containsKey(key)) {
              key = '$label (column ${columnName(cell.key)})';
            }
            extra[key] = cell.value;
          }
          extra['[Import] Worksheet'] = sheet.name;
          extra['[Import] Row'] = '${row.number}';
          if (section.isNotEmpty) extra['[Import] Section'] = section;
          var execution = field(ExcelField.executionResult);
          // Real Report5 uses Round 1 / Round 2 / Round 3, not Status.
          // Use the highest-numbered non-empty round; preserve every round.
          if (execution.isEmpty) {
            var latest = -1;
            for (var column = 0; column < current.labels.length; column++) {
              final round = ExcelColumnMapping.executionRound(
                current.labels[column],
              );
              if (round != null &&
                  round > latest &&
                  row.at(column).isNotEmpty) {
                latest = round;
                execution = row.at(column);
                extra['[Import] Execution source'] = current.labels[column];
              }
            }
          }
          imported.add(
            TestCase(
              id: id,
              module: field(ExcelField.module).isEmpty
                  ? sheet.name
                  : field(ExcelField.module),
              description: field(ExcelField.description),
              preconditions: field(ExcelField.preconditions),
              steps: List.unmodifiable(
                field(ExcelField.steps)
                    .split('\n')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty),
              ),
              testData: field(ExcelField.testData),
              expectedResult: field(ExcelField.expectedResult),
              executionResult: execution,
              additionalFields: Map.unmodifiable(extra),
            ),
          );
          if (imported.length % 250 == 0) yield null;
        }
        if (imported.isEmpty) {
          diagnostics.add(
            _diagnostic(
              sheet,
              SheetDisposition.ignored,
              header: header,
              note: 'Header found, but no rows with a Test Case ID.',
            ),
          );
          continue;
        }
        cases.addAll(imported);
        if (missingIds > 0) {
          warnings.add(
            '${sheet.name}: skipped $missingIds non-empty row(s) without a Test Case ID.',
          );
        }
        if (sheet.formulaCells > 0) {
          warnings.add(
            '${sheet.name}: ${sheet.formulaCells} formula cell(s) have no cached result; retained as formula text.',
          );
        }
        diagnostics.add(
          _diagnostic(
            sheet,
            SheetDisposition.imported,
            header: header,
            count: imported.length,
          ),
        );
      } catch (error) {
        diagnostics.add(
          _diagnostic(
            sheet,
            SheetDisposition.failed,
            header: header,
            note: error is FormatException
                ? error.message
                : 'Could not read this worksheet: $error',
          ),
        );
      }
    }
    if (cases.isEmpty) {
      throw ExcelImportException(
        'This workbook does not appear to contain the Test Case Report format. '
        "Please verify that you selected the project's Test Case Report workbook, not its Unit Test/function workbook. "
        'A reviewable table needs a Test Case ID column within its first 30 non-empty rows; other fields may be missing.',
        diagnostics: List.unmodifiable(diagnostics),
      );
    }
    final occurrences = <String, int>{};
    for (final testCase in cases) {
      occurrences.update(testCase.id, (n) => n + 1, ifAbsent: () => 1);
    }
    final duplicates = occurrences.entries.where((e) => e.value > 1).length;
    if (duplicates > 0) {
      warnings.add(
        '$duplicates repeated Excel ID(s) preserved as separate cases, identified by worksheet and row. Original IDs are unchanged.',
      );
    }
    final reserved = cases.map((t) => t.id).toSet();
    final uniqueCases = cases.map((t) {
      if (occurrences[t.id] == 1) return t;
      var key =
          '@xlsx:${Uri.encodeComponent(t.additionalFields['[Import] Worksheet']!)}:${t.additionalFields['[Import] Row']}:${Uri.encodeComponent(t.id)}';
      while (reserved.contains(key)) {
        key += ':';
      }
      reserved.add(key);
      return TestCase(
        id: key,
        sourceId: t.id,
        module: t.module,
        description: t.description,
        preconditions: t.preconditions,
        steps: t.steps,
        testData: t.testData,
        expectedResult: t.expectedResult,
        executionResult: t.executionResult,
        additionalFields: t.additionalFields,
      );
    }).toList();
    result = ExcelImportResult(
      testCases: uniqueCases,
      sheetCounts: {
        for (final d in diagnostics)
          if (d.disposition == SheetDisposition.imported)
            d.name: d.importedRows,
      },
      warnings: warnings,
      diagnostics: diagnostics,
      elapsedMilliseconds: timer.elapsedMilliseconds,
    );
    yield 'Import completed.';
  }

  SheetImportDiagnostic _diagnostic(
    SparseSheet sheet,
    SheetDisposition disposition, {
    _Header? header,
    int count = 0,
    String note = '',
  }) => SheetImportDiagnostic(
    name: sheet.name,
    disposition: disposition,
    headerRow: header?.row,
    columnMapping: header == null
        ? const {}
        : {
            for (final e in header.mapping.entries)
              e.key.name: columnName(e.value),
            for (final e in header.labels.indexed)
              if (ExcelColumnMapping.executionRound(e.$2) != null)
                e.$2: columnName(e.$1),
          },
    importedRows: count,
    storedRows: sheet.storedRows,
    nonEmptyRows: sheet.rows.length,
    usedRange: sheet.usedRange,
    declaredRange: sheet.declaredRange,
    mergedRanges: sheet.merges.length,
    note: note,
  );

  _Header? _findHeader(SparseSheet sheet) {
    _Header? best;
    var bestScore = -1;
    for (final row in sheet.rows.take(30)) {
      final candidate = _headerAt(row);
      if (candidate == null) continue;
      final idLabel = ExcelColumnMapping.normalize(
        row.at(candidate.mapping[ExcelField.id]),
      );
      // A bare ID is accepted, but explicit Test Case ID and richer headers win
      // over metadata labels. A later non-empty ID verifies an actual table.
      final hasData = sheet.rows.any(
        (r) =>
            r.number > row.number &&
            r.at(candidate.mapping[ExcelField.id]).isNotEmpty,
      );
      if (!hasData) continue;
      final score = candidate.mapping.length * 10 + (idLabel == 'id' ? 0 : 5);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  _Header? _headerAt(SparseRow row) {
    final last = row.cells.keys.fold<int>(0, (a, b) => a > b ? a : b);
    final labels = List.generate(last + 1, row.at);
    final mapping = ExcelColumnMapping.detect(labels);
    return ExcelColumnMapping.isTestCaseHeader(mapping)
        ? _Header(row.number, labels, mapping)
        : null;
  }
}
