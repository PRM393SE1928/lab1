import 'evaluation.dart';
import 'excel_import_result.dart';
import 'srs_section.dart';
import 'test_case.dart';

typedef Json = Map<String, Object?>;
Json _map(Object? value) => Map<String, Object?>.from(value as Map);
List<T> _list<T>(Object? value, T Function(Json) decode) =>
    (value as List).map((v) => decode(_map(v))).toList();
List<String> _strings(Object? value) => List<String>.from(value as List);
Map<String, String> _stringsMap(Object? value) =>
    Map<String, String>.from(value as Map);

/// Versioned durable data only. File handles, busy flags and search caches are
/// intentionally rebuilt rather than stored.
class WorkspaceSnapshot {
  WorkspaceSnapshot({
    required this.testCases,
    required this.sections,
    required this.saved,
    required this.drafts,
    required this.selectedId,
    this.excel,
    this.excelName,
    this.excelPath,
    this.srsName,
    this.srsPath,
  });
  final List<TestCase> testCases;
  final List<SrsSection> sections;
  final Map<String, Evaluation> saved, drafts;
  final String selectedId;
  final ExcelImportResult? excel;
  final String? excelName, excelPath, srsName, srsPath;

  Json toJson() => {
    'version': 1,
    'testCases': testCases.map(_caseJson).toList(),
    'sections': sections
        .map(
          (s) => <String, Object?>{
            'id': s.id,
            'title': s.title,
            'blocks': s.blocks,
            'order': s.order,
            'sectionNumber': s.sectionNumber,
            'parentSection': s.parentSection,
            'category': s.category,
            'keywords': s.keywords,
          },
        )
        .toList(),
    'saved': saved.values.map(_evaluationJson).toList(),
    'drafts': drafts.values.map(_evaluationJson).toList(),
    'selectedId': selectedId,
    'excelName': excelName,
    'excelPath': excelPath,
    'srsName': srsName,
    'srsPath': srsPath,
    'excel': excel == null
        ? null
        : <String, Object?>{
            'sheetCounts': excel!.sheetCounts,
            'warnings': excel!.warnings,
            'elapsedMilliseconds': excel!.elapsedMilliseconds,
            'diagnostics': excel!.diagnostics
                .map(
                  (d) => <String, Object?>{
                    'name': d.name,
                    'disposition': d.disposition.name,
                    'headerRow': d.headerRow,
                    'columnMapping': d.columnMapping,
                    'importedRows': d.importedRows,
                    'storedRows': d.storedRows,
                    'nonEmptyRows': d.nonEmptyRows,
                    'usedRange': d.usedRange,
                    'declaredRange': d.declaredRange,
                    'mergedRanges': d.mergedRanges,
                    'note': d.note,
                  },
                )
                .toList(),
          },
  };

  factory WorkspaceSnapshot.fromJson(Json data) {
    if (data['version'] != 1) {
      throw const FormatException(
        'This workspace uses an unsupported storage version. Its data has been kept.',
      );
    }
    try {
      final cases = _list(
        data['testCases'],
        (j) => TestCase(
          id: j['id'] as String,
          sourceId: j['sourceId'] as String?,
          module: j['module'] as String,
          description: j['description'] as String,
          preconditions: j['preconditions'] as String,
          steps: _strings(j['steps']),
          testData: j['testData'] as String,
          expectedResult: j['expectedResult'] as String,
          executionResult: j['executionResult'] as String,
          additionalFields: _stringsMap(j['additionalFields']),
        ),
      );
      final sections = _list(
        data['sections'],
        (j) => SrsSection(
          id: j['id'] as String,
          title: j['title'] as String,
          blocks: _strings(j['blocks']),
          order: j['order'] as int,
          sectionNumber: j['sectionNumber'] as String?,
          parentSection: j['parentSection'] as String?,
          category: j['category'] as String,
          keywords: _strings(j['keywords']),
        ),
      );
      Map<String, Evaluation> evaluations(Object? value) {
        final list = _list(value, _evaluationFromJson);
        final result = {for (final e in list) e.testCaseId: e};
        if (result.length != list.length) {
          throw const FormatException('Duplicate evaluations');
        }
        return result;
      }

      final saved = evaluations(data['saved']),
          drafts = evaluations(data['drafts']);
      final caseIds = cases.map((t) => t.id).toSet();
      final sectionIds = sections.map((s) => s.id).toSet();
      if (cases.isEmpty ||
          caseIds.length != cases.length ||
          sectionIds.length != sections.length) {
        throw const FormatException('Invalid workspace identifiers');
      }
      final references = {
        ...sectionIds,
        if (data['excel'] == null && sections.isEmpty) ...[
          'SRS-AUTH-01',
          'SRS-REPORT-01',
        ],
      };
      for (final e in [...saved.values, ...drafts.values]) {
        if (!caseIds.contains(e.testCaseId) ||
            (e.requirementId != null &&
                !references.contains(e.requirementId))) {
          throw const FormatException('Invalid workspace mapping');
        }
      }
      final rawExcel = data['excel'];
      ExcelImportResult? excel;
      if (rawExcel != null) {
        final j = _map(rawExcel);
        excel = ExcelImportResult(
          testCases: cases,
          sheetCounts: Map<String, int>.from(j['sheetCounts'] as Map),
          warnings: _strings(j['warnings']),
          elapsedMilliseconds: j['elapsedMilliseconds'] as int,
          diagnostics: _list(
            j['diagnostics'],
            (d) => SheetImportDiagnostic(
              name: d['name'] as String,
              disposition: SheetDisposition.values.byName(
                d['disposition'] as String,
              ),
              headerRow: d['headerRow'] as int?,
              columnMapping: _stringsMap(d['columnMapping']),
              importedRows: d['importedRows'] as int,
              storedRows: d['storedRows'] as int,
              nonEmptyRows: d['nonEmptyRows'] as int,
              usedRange: d['usedRange'] as String,
              declaredRange: d['declaredRange'] as String,
              mergedRanges: d['mergedRanges'] as int,
              note: d['note'] as String,
            ),
          ),
        );
      }
      final selected = data['selectedId'] as String;
      return WorkspaceSnapshot(
        testCases: cases,
        sections: sections,
        saved: saved,
        drafts: drafts,
        selectedId: caseIds.contains(selected) ? selected : cases.first.id,
        excel: excel,
        excelName: data['excelName'] as String?,
        excelPath: data['excelPath'] as String?,
        srsName: data['srsName'] as String?,
        srsPath: data['srsPath'] as String?,
      );
    } catch (_) {
      throw const FormatException(
        'Stored workspace is incomplete or damaged. Its data has been kept; no replacement was written.',
      );
    }
  }
}

Json _caseJson(TestCase t) => {
  'id': t.id,
  'sourceId': t.sourceId,
  'module': t.module,
  'description': t.description,
  'preconditions': t.preconditions,
  'steps': t.steps,
  'testData': t.testData,
  'expectedResult': t.expectedResult,
  'executionResult': t.executionResult,
  'additionalFields': t.additionalFields,
};
Json _evaluationJson(Evaluation e) => {
  'testCaseId': e.testCaseId,
  'requirementId': e.requirementId,
  'criteria': {for (final c in e.criteria.entries) c.key.name: c.value.name},
  'overrideStatus': e.overrideStatus?.name,
  'issues': e.issues,
  'suggestedFix': e.suggestedFix,
  'reviewerNotes': e.reviewerNotes,
  'reviewedAt': e.reviewedAt?.toUtc().toIso8601String(),
};
Evaluation _evaluationFromJson(Json j) {
  final criteria = _map(j['criteria']);
  return Evaluation(
    testCaseId: j['testCaseId'] as String,
    requirementId: j['requirementId'] as String?,
    criteria: {
      for (final c in Criterion.values)
        c: ReviewStatus.values.byName(criteria[c.name] as String),
    },
    overrideStatus: j['overrideStatus'] == null
        ? null
        : ReviewStatus.values.byName(j['overrideStatus'] as String),
    issues: j['issues'] as String,
    suggestedFix: j['suggestedFix'] as String,
    reviewerNotes: j['reviewerNotes'] as String,
    reviewedAt: j['reviewedAt'] == null
        ? null
        : DateTime.parse(j['reviewedAt'] as String),
  );
}
