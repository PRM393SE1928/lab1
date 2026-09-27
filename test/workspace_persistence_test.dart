import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:flutter_application_2/models/evaluation.dart';
import 'package:flutter_application_2/providers/app_state.dart';
import 'package:flutter_application_2/services/workspace_store.dart';
import 'package:flutter_application_2/services/excel_service.dart';
import 'package:flutter_application_2/services/srs_service.dart';

import 'support/workbook_fixture.dart';
import 'support/docx_fixture.dart';

class MemoryWorkspaceStore implements WorkspaceStore {
  Map<String, Object?>? data;
  bool failRead = false, failWrite = false;
  int writes = 0;
  Completer<void>? gate;
  @override
  Future<Map<String, Object?>?> read() async {
    if (failRead) throw StateError('Storage unavailable');
    return data == null
        ? null
        : Map<String, Object?>.from(jsonDecode(jsonEncode(data)) as Map);
  }

  @override
  Future<void> write(Map<String, Object?> value) async {
    final copy = Map<String, Object?>.from(
      jsonDecode(jsonEncode(value)) as Map,
    );
    final pending = gate;
    gate = null;
    if (pending != null) await pending.future;
    if (failWrite) throw StateError('Disk full');
    data = copy;
    writes++;
  }

  @override
  Future<void> close() async {}
}

class StorageExcelPicker extends ExcelService {
  XFile? file;
  @override
  Future<XFile?> selectFile() async => file;
}

class StorageSrsPicker extends SrsService {
  XFile? file;
  @override
  Future<XFile?> selectFile() async => file;
}

void main() {
  test('Restart restores real imports, mappings, saved judgments and independent drafts', () async {
    final store = MemoryWorkspaceStore();
    final excel = StorageExcelPicker()
      ..file = XFile.fromData(
        basicWorkbook(id: 'REAL-001'),
        path: 'cases.xlsx',
      );
    final srs = StorageSrsPicker()
      ..file = XFile.fromData(docxFixture(), path: 'requirements.docx');
    final state = AppState(
      storage: store,
      excelService: excel,
      srsService: srs,
    );
    await state.restoreWorkspace();
    await state.selectExcelFile();
    expect(await state.importSelectedExcel(), isTrue);
    await state.selectSrsFile();
    expect(await state.importSelectedSrs(), isTrue);
    state.mapRequirement('REAL-001', state.srsSections[2].id);
    final draft = state.draft('REAL-001');
    for (final c in Criterion.values) {
      draft.criteria[c] = ReviewStatus.pass;
    }
    draft.overrideStatus = ReviewStatus.warning;
    draft.issues = 'Thiếu dữ liệu';
    draft.suggestedFix = 'Bổ sung tài khoản';
    expect(state.save('REAL-001'), isNull);
    await state.flushWorkspace();
    final reviewedAt = state.saved('REAL-001')!.reviewedAt;
    draft.reviewerNotes = 'Unsaved evaluation draft';
    draft.criteria[Criterion.stepClarity] = ReviewStatus.fail;
    state.draftChanged();
    await state.flushWorkspace();
    state.dispose();
    final restored = AppState(storage: store);
    addTearDown(restored.dispose);
    await restored.restoreWorkspace();
    expect(restored.restoreError, isNull);
    expect(restored.testCases.single.id, 'REAL-001');
    expect(restored.testCases.single.executionResult, 'Passed');
    expect(restored.hasImportedCases, isTrue);
    expect(restored.importedFileName, 'cases.xlsx');
    expect(restored.importedSrsFileName, 'requirements.docx');
    expect(restored.selectedExcelFile, isNull);
    expect(restored.selectedSrsFile, isNull);
    expect(restored.srsIndex.search('ĐĂNG NHẬP'), hasLength(1));
    expect(
      restored.draft('REAL-001').requirementId,
      restored.srsSections[2].id,
    );
    expect(
      restored.draft('REAL-001').reviewerNotes,
      'Unsaved evaluation draft',
    );
    expect(restored.saved('REAL-001')!.reviewerNotes, isEmpty);
    expect(
      restored.saved('REAL-001')!.criteria[Criterion.stepClarity],
      ReviewStatus.pass,
    );
    expect(
      restored.draft('REAL-001').criteria[Criterion.stepClarity],
      ReviewStatus.fail,
    );
    expect(
      restored.saved('REAL-001')!.reviewedAt!.isAtSameMomentAs(reviewedAt!),
      isTrue,
    );
    expect(restored.status('REAL-001'), ReviewStatus.warning);
    expect(restored.storageStatus, 'Saved locally');
  });

  test('Read failure, corrupt records and future versions never overwrite stored data', () async {
    for (final invalid in [
      <String, Object?>{'version': 99},
      <String, Object?>{'version': 1},
    ]) {
      final store = MemoryWorkspaceStore()..data = invalid;
      final state = AppState(storage: store);
      await state.restoreWorkspace();
      expect(state.restoreError, isNotNull);
      state.draftChanged();
      await state.flushWorkspace();
      expect(store.writes, 0);
      expect(store.data, invalid);
      state.dispose();
    }
    final store = MemoryWorkspaceStore()..failRead = true;
    final state = AppState(storage: store);
    addTearDown(state.dispose);
    await state.restoreWorkspace();
    expect(state.restoreError, isNotNull);
    store.failRead = false;
    await state.restoreWorkspace();
    expect(state.restoreError, isNull);
  });

  test(
    'Delayed writes cannot overwrite newer drafts; save failure can retry',
    () async {
      final store = MemoryWorkspaceStore();
      final state = AppState(storage: store);
      addTearDown(state.dispose);
      await state.restoreWorkspace();
      final gate = Completer<void>();
      store.gate = gate;
      state.draft(state.selectedId).reviewerNotes = 'old';
      state.draftChanged();
      state.draft(state.selectedId).reviewerNotes = 'new';
      state.draftChanged();
      gate.complete();
      await state.flushWorkspace();
      expect((store.data!['drafts'] as List).single['reviewerNotes'], 'new');
      store.failWrite = true;
      state.draft(state.selectedId).reviewerNotes = 'keep on failure';
      state.draftChanged();
      await state.flushWorkspace();
      expect(state.storageError, contains('Disk full'));
      expect(state.storageStatus, 'Not saved locally');
      expect((store.data!['drafts'] as List).single['reviewerNotes'], 'new');
      store.failWrite = false;
      await state.flushWorkspace();
      expect(state.storageError, isNull);
      expect(
        (store.data!['drafts'] as List).single['reviewerNotes'],
        'keep on failure',
      );
    },
  );

  test('Failed imports preserve durable workspace; replacements persist their resets', () async {
    final store = MemoryWorkspaceStore();
    final excel = StorageExcelPicker()
      ..file = XFile.fromData(Uint8List.fromList([1, 2]), path: 'bad.xlsx');
    final srs = StorageSrsPicker()
      ..file = XFile.fromData(docxFixture(), path: 'new.docx');
    final state = AppState(
      storage: store,
      excelService: excel,
      srsService: srs,
    );
    addTearDown(state.dispose);
    await state.restoreWorkspace();
    state.draftChanged();
    await state.flushWorkspace();
    final before = jsonEncode(store.data);
    await state.selectExcelFile();
    expect(await state.importSelectedExcel(), isFalse);
    expect(jsonEncode(store.data), before);
    await state.selectSrsFile();
    expect(
      await state.importSelectedSrs(confirmReplacement: (_) async => false),
      isFalse,
    );
    expect(jsonEncode(store.data), before);
    expect(
      await state.importSelectedSrs(confirmReplacement: (_) async => true),
      isTrue,
    );
    expect((store.data!['saved'] as List).first['requirementId'], isNull);
    excel.file = XFile.fromData(basicWorkbook(), path: 'new.xlsx');
    await state.selectExcelFile();
    expect(await state.importSelectedExcel(), isTrue);
    expect(store.data!['saved'], isEmpty);
    expect(store.data!['drafts'], isEmpty);
    expect(store.data!['sections'], isNotEmpty);
  });

  test(
    'Disk database survives closing/reopening and rejects stale writers',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'review_store_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = '${directory.path}/workspace.db';
      final first = DatabaseWorkspaceStore(
        () => databaseFactoryIo.openDatabase(file),
      );
      expect(await first.read(), isNull);
      await first.write({'version': 1, 'text': 'Đăng nhập'});
      await first.close();
      final second = DatabaseWorkspaceStore(
        () => databaseFactoryIo.openDatabase(file),
      );
      expect((await second.read())!['text'], 'Đăng nhập');
      final stale = DatabaseWorkspaceStore(
        () => databaseFactoryIo.openDatabase(file),
      );
      await stale.read();
      await second.write({'version': 1, 'text': 'latest'});
      await expectLater(
        stale.write({'version': 1, 'text': 'old'}),
        throwsStateError,
      );
      expect((await second.read())!['text'], 'latest');
      await stale.close();
      await second.close();
    },
  );
}
