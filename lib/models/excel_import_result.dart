import 'test_case.dart';

enum SheetDisposition { imported, ignored, failed }

class SheetImportDiagnostic {
  SheetImportDiagnostic({
    required this.name,
    required this.disposition,
    this.headerRow,
    this.columnMapping = const {},
    this.importedRows = 0,
    this.storedRows = 0,
    this.nonEmptyRows = 0,
    this.usedRange = '',
    this.declaredRange = '',
    this.mergedRanges = 0,
    this.note = '',
  });
  final String name;
  final SheetDisposition disposition;
  final int? headerRow;
  final Map<String, String> columnMapping;
  final int importedRows, storedRows, nonEmptyRows, mergedRanges;
  final String usedRange, declaredRange, note;
  String get debugSummary =>
      '[Excel Import] Sheet: $name\n'
      'Status: ${disposition.name}; Header row: ${headerRow ?? "none"}\n'
      'Used: $usedRange; Declared: $declaredRange; Stored rows: $storedRows; '
      'Non-empty: $nonEmptyRows; Merges: $mergedRanges\n'
      'Mapping: ${columnMapping.entries.map((e) => "${e.key} -> column ${e.value}").join(", ")}\n'
      'Imported: $importedRows Test Cases${note.isEmpty ? "" : "\n$note"}';
}

class ExcelImportResult {
  ExcelImportResult({
    required List<TestCase> testCases,
    required Map<String, int> sheetCounts,
    required List<String> warnings,
    List<SheetImportDiagnostic> diagnostics = const [],
    this.elapsedMilliseconds = 0,
  }) : testCases = List.unmodifiable(testCases),
       sheetCounts = Map.unmodifiable(sheetCounts),
       warnings = List.unmodifiable(warnings),
       diagnostics = List.unmodifiable(diagnostics);
  final List<TestCase> testCases;
  final Map<String, int> sheetCounts;
  final List<String> warnings;
  final List<SheetImportDiagnostic> diagnostics;
  final int elapsedMilliseconds;
  int get sheetsScanned => diagnostics.length;
  List<SheetImportDiagnostic> get ignoredSheets => diagnostics
      .where((d) => d.disposition == SheetDisposition.ignored)
      .toList();
  List<SheetImportDiagnostic> get failedSheets => diagnostics
      .where((d) => d.disposition == SheetDisposition.failed)
      .toList();
}

class ExcelImportException implements Exception {
  const ExcelImportException(this.message, {this.diagnostics = const []});
  final String message;
  final List<SheetImportDiagnostic> diagnostics;
  @override
  String toString() => message;
}
