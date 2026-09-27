import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';

import '../data/sample_data.dart';
import '../models/evaluation.dart';
import '../models/test_case.dart';
import '../models/requirement.dart';
import '../models/excel_import_result.dart';
import '../services/excel_service.dart';
import '../services/srs_service.dart';
import '../models/srs_section.dart';
import '../models/workspace_snapshot.dart';
import '../models/evaluation_report.dart';
import '../services/workspace_store.dart';

class AppState extends ChangeNotifier {
  List<TestCase> _testCases = List.unmodifiable(sampleTestCases);
  List<TestCase> get testCases => _testCases;
  List<Requirement> get requirements =>
      hasImportedCases ? const [] : List.unmodifiable(sampleRequirements);
  final ExcelService _excelService;
  XFile? selectedExcelFile;
  ExcelImportResult? importResult;
  String? importedFileName;
  String? importedFilePath;
  String? importError;
  String importStatus = '';
  List<SheetImportDiagnostic> importDiagnostics = const [];
  bool importing = false;
  bool selectingFile = false;
  bool selectedFileImported = false;
  int workbookRevision = 0;
  bool get hasImportedCases => importResult != null;
  bool _disposed = false;
  final Map<String, Evaluation> _saved = {};
  final Map<String, Evaluation> _drafts = {};
  String selectedId = sampleTestCases.first.id;

  AppState({
    ExcelService? excelService,
    SrsService? srsService,
    WorkspaceStore? storage,
  }) : _excelService = excelService ?? ExcelService(),
       _srsService = srsService ?? SrsService(),
       _storage = storage,
       restoring = storage != null,
       _loaded = storage == null {
    final example = Evaluation(
      testCaseId: selectedId,
      requirementId: 'SRS-AUTH-01',
      criteria: {for (final c in Criterion.values) c: ReviewStatus.pass},
      issues: 'The test case does not provide a concrete test account.',
      suggestedFix:
          'Specify a valid test account or reference a prepared test-data set.',
      reviewedAt: DateTime.now(),
    );
    example.criteria[Criterion.testDataPreconditions] = ReviewStatus.warning;
    _saved[selectedId] = example;
  }

  final WorkspaceStore? _storage;
  bool restoring;
  bool _loaded;
  bool _dirty = false;
  bool _hasPersisted = false;
  Future<void>? _writeTask;
  String? restoreError, storageError;
  bool get persistenceEnabled => _storage != null;
  String get storageStatus => !persistenceEnabled
      ? 'Session only'
      : storageError != null
      ? 'Not saved locally'
      : _dirty || _writeTask != null
      ? 'Saving locally...'
      : _hasPersisted
      ? 'Saved locally'
      : 'Local autosave ready';

  Future<void> restoreWorkspace() async {
    if (_loaded || _storage == null) return;
    restoring = true;
    restoreError = null;
    if (!_disposed) notifyListeners();
    try {
      final data = await _storage.read();
      final snapshot = data == null ? null : WorkspaceSnapshot.fromJson(data);
      if (_disposed) return;
      if (snapshot != null) {
        _hasPersisted = true;
        _testCases = List.unmodifiable(snapshot.testCases);
        srsIndex = SrsIndex(snapshot.sections);
        _saved
          ..clear()
          ..addAll(snapshot.saved);
        _drafts
          ..clear()
          ..addAll(snapshot.drafts);
        selectedId = snapshot.selectedId;
        importResult = snapshot.excel;
        importDiagnostics = snapshot.excel?.diagnostics ?? const [];
        importedFileName = snapshot.excelName;
        importedFilePath = snapshot.excelPath;
        importedSrsFileName = snapshot.srsName;
        importedSrsPath = snapshot.srsPath;
        srsStatus = snapshot.srsName == null
            ? 'No file selected'
            : 'Restored from local storage';
        workbookRevision++;
      }
      _loaded = true;
    } catch (error) {
      restoreError = 'Could not restore the local workspace. $error';
    } finally {
      restoring = false;
      if (!_disposed) notifyListeners();
    }
  }

  WorkspaceSnapshot _snapshot() => WorkspaceSnapshot(
    testCases: testCases,
    sections: srsSections,
    saved: _saved,
    drafts: _drafts,
    selectedId: selectedId,
    excel: importResult,
    excelName: importedFileName,
    excelPath: importedFilePath,
    srsName: importedSrsFileName,
    srsPath: importedSrsPath,
  );

  /// UI edits call this after changing a draft. Serial writes coalesce edits
  /// arriving during a pending transaction without allowing older writes last.
  void draftChanged() {
    if (_storage != null && _loaded) {
      _dirty = true;
      unawaited(flushWorkspace());
    }
    if (!_disposed) notifyListeners();
  }

  void selectTestCase(String id) {
    if (selectedId == id) return;
    selectedId = id;
    draftChanged();
  }

  Future<void> flushWorkspace() {
    if (_storage == null || !_loaded || !_dirty) {
      return _writeTask ?? Future.value();
    }
    return _writeTask ??= _writeWorkspace().whenComplete(() {
      _writeTask = null;
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> _writeWorkspace() async {
    while (_dirty) {
      _dirty = false;
      try {
        // Capture detached JSON now; mutable drafts must not change a pending write.
        final data = _snapshot().toJson();
        await _storage!.write(data);
        _hasPersisted = true;
        storageError = null;
      } catch (error) {
        _dirty = true;
        storageError =
            'Your changes are still in this tab but could not be saved locally. $error';
        break;
      }
    }
  }

  final SrsService _srsService;
  SrsIndex srsIndex = SrsIndex(const []);
  static final _sampleIndex = SrsIndex([
    for (final r in sampleRequirements)
      SrsSection(
        id: r.id,
        title: r.title,
        blocks: [r.description],
        order: sampleRequirements.indexOf(r),
        parentSection: 'Sample SRS > ${r.section}',
        sectionNumber: r.sourceReference,
      ),
  ]);
  SrsIndex get requirementIndex =>
      srsSections.isNotEmpty || hasImportedCases ? srsIndex : _sampleIndex;
  List<SrsSection> get srsSections => srsIndex.sections;
  XFile? selectedSrsFile;
  String? importedSrsFileName, importedSrsPath, srsError;
  String srsStatus = 'No file selected';
  bool srsBusy = false;
  int get mappedCaseCount => {..._saved.keys, ..._drafts.keys}
      .where(
        (id) =>
            _saved[id]?.requirementId != null ||
            _drafts[id]?.requirementId != null,
      )
      .length;

  SrsSection? sectionFor(String? id) => requirementIndex.byId[id];
  String mappingLabel(String? id) =>
      sectionFor(id)?.path ??
      requirements.where((r) => r.id == id).firstOrNull?.title ??
      'Not mapped';
  void mapRequirement(String caseId, String? sectionId) {
    if (sectionId != null && !requirementIndex.byId.containsKey(sectionId)) {
      throw ArgumentError('Unknown SRS section');
    }
    draft(caseId).requirementId = sectionId;
    draftChanged();
  }

  Future<void> selectSrsFile() async {
    if (srsBusy) return;
    srsBusy = true;
    notifyListeners();
    try {
      final file = await _srsService.selectFile();
      if (!_disposed && file != null) {
        selectedSrsFile = file;
        srsStatus = 'Ready to parse';
        srsError = null;
      }
    } catch (_) {
      if (!_disposed) srsError = 'Could not open the SRS file picker.';
    } finally {
      srsBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> importSelectedSrs({
    Future<bool> Function(int)? confirmReplacement,
  }) async {
    final file = selectedSrsFile;
    if (file == null || srsBusy) return false;
    srsBusy = true;
    srsError = null;
    notifyListeners();
    try {
      final next = await _srsService.importFile(
        file,
        onProgress: (status) {
          if (!_disposed) {
            srsStatus = status;
            notifyListeners();
          }
        },
      );
      if (_disposed) return false;
      if (next.sections.isEmpty) {
        throw const SrsImportException('No useful SRS sections found.');
      }
      final count = mappedCaseCount;
      if (count > 0 &&
          (confirmReplacement == null || !await confirmReplacement(count))) {
        if (!_disposed) srsStatus = 'Replacement cancelled. Current SRS kept.';
        return false;
      }
      if (_disposed) return false;
      // Commit only after parsing and explicit approval of mapping invalidation.
      for (final e in [..._saved.values, ..._drafts.values]) {
        e.requirementId = null;
      }
      srsIndex = next;
      importedSrsFileName = file.name;
      importedSrsPath = file.path;
      srsStatus = 'Completed';
      draftChanged();
      await flushWorkspace();
      return true;
    } catch (error) {
      if (!_disposed) {
        srsStatus = 'Failed';
        srsError =
            '${error is SrsImportException ? error.message : 'Unable to parse this DOCX file.'} The existing Test Case workspace and SRS were not changed.';
      }
      return false;
    } finally {
      srsBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> selectExcelFile() async {
    if (selectingFile || importing) return;
    selectingFile = true;
    notifyListeners();
    try {
      final file = await _excelService.selectFile();
      if (_disposed) return;
      if (file != null) {
        selectedExcelFile = file;
        selectedFileImported = false;
        importError = null;
      }
    } catch (_) {
      if (!_disposed) {
        importError =
            'Could not open the file picker. Try selecting the workbook again.';
      }
    } finally {
      selectingFile = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> importSelectedExcel() async {
    final file = selectedExcelFile;
    if (file == null || importing || selectingFile) return false;
    importing = true;
    importError = null;
    importStatus = 'Reading workbook...';
    importDiagnostics = const [];
    notifyListeners();
    try {
      final result = await _excelService.importFile(
        file,
        onProgress: (status) {
          if (!_disposed && importStatus != status) {
            importStatus = status;
            notifyListeners();
          }
        },
      );
      if (_disposed) return false;
      if (result.testCases.isEmpty) {
        throw const ExcelImportException(
          'The workbook contains no test cases.',
        );
      }
      // Commit only after the entire workbook has parsed successfully.
      _testCases = result.testCases;
      _saved.clear();
      _drafts.clear();
      selectedId = _testCases.first.id;
      importResult = result;
      importDiagnostics = result.diagnostics;
      importedFileName = file.name;
      importedFilePath = file.path;
      selectedFileImported = true;
      workbookRevision++;
      draftChanged();
      await flushWorkspace();
      return true;
    } on ExcelImportException catch (error) {
      if (!_disposed) {
        importError = error.message;
        importDiagnostics = error.diagnostics;
      }
      return false;
    } catch (_) {
      if (!_disposed) {
        importError = 'Could not import this workbook. Please verify that you selected the Test Case Report workbook. The current workspace has been kept.';
      }
      return false;
    } finally {
      importing = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_closeStorage());
    super.dispose();
  }

  Future<void> _closeStorage() async {
    await flushWorkspace();
    try {
      await _storage?.close();
    } catch (_) {
      /* Reported through the save/load status before disposal. */
    }
  }

  Evaluation draft(String id) => _drafts.putIfAbsent(
    id,
    () => _saved[id]?.copy() ?? Evaluation(testCaseId: id),
  );
  Evaluation? saved(String id) => _saved[id]?.copy();
  int get unsavedDraftCount => _drafts.entries.where((entry) {
    final a = entry.value,
        b = _saved[entry.key] ?? Evaluation(testCaseId: entry.key);
    return a.requirementId != b.requirementId ||
        a.overrideStatus != b.overrideStatus ||
        a.issues != b.issues ||
        a.suggestedFix != b.suggestedFix ||
        a.reviewerNotes != b.reviewerNotes ||
        Criterion.values.any((c) => a.criteria[c] != b.criteria[c]);
  }).length;

  EvaluationReport captureReport() => EvaluationReport(
    testCases: testCases,
    evaluations: _saved,
    sections: requirementIndex.sections,
    createdAt: DateTime.now(),
    sampleData: !hasImportedCases,
    excelName: importedFileName,
    srsName: importedSrsFileName,
    omittedDrafts: unsavedDraftCount,
  );
  ReviewStatus status(String id) =>
      _saved[id]?.overallStatus ?? ReviewStatus.notEvaluated;
  int count(ReviewStatus status) =>
      testCases.where((t) => this.status(t.id) == status).length;
  int get reviewed => testCases.length - count(ReviewStatus.notEvaluated);
  List<String> get modules =>
      (testCases.map((t) => t.module).toSet().toList()..sort());

  String? save(String id) {
    final evaluation = draft(id);
    if (!evaluation.isComplete) {
      return 'Evaluate all seven criteria before saving.';
    }
    if (evaluation.overallStatus == ReviewStatus.notEvaluated) {
      return 'Choose a reviewed overall status.';
    }
    if (evaluation.criteria[Criterion.requirementTraceability] ==
            ReviewStatus.pass &&
        evaluation.requirementId == null) {
      return 'Map a requirement before marking traceability PASS.';
    }
    if ((evaluation.overallStatus == ReviewStatus.warning ||
            evaluation.overallStatus == ReviewStatus.fail) &&
        evaluation.issues.trim().isEmpty) {
      return 'Describe the issue for a WARNING or FAIL evaluation.';
    }
    evaluation.reviewedAt = DateTime.now();
    _saved[id] = evaluation.copy();
    draftChanged();
    return null;
  }
}
