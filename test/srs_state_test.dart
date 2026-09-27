import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/evaluation.dart';
import 'package:flutter_application_2/providers/app_state.dart';
import 'package:flutter_application_2/services/srs_service.dart';

import 'support/docx_fixture.dart';

class SrsPicker extends SrsService {
  XFile? next;
  @override
  Future<XFile?> selectFile() async => next;
}

void main() {
  test('Mapping changes/removal survive case navigation without changing judgments', () async {
    final picker = SrsPicker()
      ..next = XFile.fromData(docxFixture(), path: 'SRS.docx');
    final state = AppState(srsService: picker);
    addTearDown(state.dispose);
    await state.selectSrsFile();
    expect(state.srsStatus, 'Ready to parse');
    expect(
      await state.importSelectedSrs(confirmReplacement: (_) async => true),
      isTrue,
    );
    final a = state.testCases[1].id, b = state.testCases[2].id;
    final first = state.srsSections[2].id, second = state.srsSections[3].id;
    state.mapRequirement(a, first);
    state.selectedId = b;
    state.mapRequirement(b, second);
    state.selectedId = a;
    expect(state.draft(a).requirementId, first);
    expect(state.draft(b).requirementId, second);
    expect(
      state
          .draft(a)
          .criteria
          .values
          .every((s) => s == ReviewStatus.notEvaluated),
      isTrue,
    );
    expect(state.status(a), ReviewStatus.notEvaluated);
    state.mapRequirement(a, second);
    expect(state.draft(a).requirementId, second);
    state.mapRequirement(a, null);
    expect(state.draft(a).requirementId, isNull);
    expect(state.draft(b).requirementId, second);
    expect(() => state.mapRequirement(a, 'unknown'), throwsArgumentError);
  });
  test('Replacement requires approval; failed imports preserve saved and draft work', () async {
    final picker = SrsPicker()
      ..next = XFile.fromData(docxFixture(), path: 'SRS.docx');
    final state = AppState(srsService: picker);
    addTearDown(state.dispose);
    await state.selectSrsFile();
    // The existing sample mapping also requires confirmation.
    expect(await state.importSelectedSrs(), isFalse);
    expect(state.saved(state.selectedId)!.requirementId, 'SRS-AUTH-01');
    expect(
      await state.importSelectedSrs(confirmReplacement: (_) async => true),
      isTrue,
    );
    final id = state.selectedId;
    state.mapRequirement(id, state.srsSections[2].id);
    state.draft(id).reviewerNotes = 'Keep my draft';
    expect(state.save(id), isNull);
    final cases = state.testCases;
    final index = state.srsIndex;
    picker.next = XFile.fromData(
      Uint8List.fromList([1, 2]),
      path: 'broken.docx',
    );
    await state.selectSrsFile();
    expect(
      await state.importSelectedSrs(confirmReplacement: (_) async => true),
      isFalse,
    );
    expect(state.testCases, same(cases));
    expect(state.srsIndex, same(index));
    expect(state.draft(id).reviewerNotes, 'Keep my draft');
    expect(state.saved(id)!.requirementId, index.sections[2].id);
    expect(state.srsError, contains('not changed'));
    picker.next = XFile.fromData(docxFixture(), path: 'Replacement.docx');
    await state.selectSrsFile();
    expect(
      await state.importSelectedSrs(
        confirmReplacement: (n) async {
          expect(n, 1);
          return false;
        },
      ),
      isFalse,
    );
    expect(state.srsIndex, same(index));
    expect(
      await state.importSelectedSrs(confirmReplacement: (_) async => true),
      isTrue,
    );
    expect(state.saved(id)!.requirementId, isNull);
    expect(state.draft(id).requirementId, isNull);
    expect(state.draft(id).reviewerNotes, 'Keep my draft');
    expect(state.status(id), ReviewStatus.warning);
    expect(state.testCases, same(cases));
  });
}
