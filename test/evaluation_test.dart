import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:flutter_application_2/models/evaluation.dart';
import 'package:flutter_application_2/providers/app_state.dart';

void main() {
  Evaluation complete() => Evaluation(
    testCaseId: 'test',
    criteria: {for (final c in Criterion.values) c: ReviewStatus.pass},
  );

  test('Critical failures take precedence, including incomplete reviews', () {
    for (final c in Criterion.values.where((c) => c.critical)) {
      final e = complete();
      e.criteria[c] = ReviewStatus.fail;
      e.criteria[Criterion.stepClarity] = ReviewStatus.notEvaluated;
      expect(e.suggestedStatus, ReviewStatus.fail);
    }
  });
  test('Minor problems warn, incomplete criteria cannot suggest pass', () {
    final e = complete();
    expect(e.suggestedStatus, ReviewStatus.pass);
    e.criteria[Criterion.stepClarity] = ReviewStatus.fail;
    expect(e.suggestedStatus, ReviewStatus.warning);
    e.criteria[Criterion.testDataPreconditions] = ReviewStatus.notEvaluated;
    expect(e.suggestedStatus, ReviewStatus.notEvaluated);
  });
  test('Manual override preserves the suggestion', () {
    final e = complete();
    e.criteria[Criterion.srsConsistency] = ReviewStatus.fail;
    e.overrideStatus = ReviewStatus.warning;
    expect(e.suggestedStatus, ReviewStatus.fail);
    expect(e.overallStatus, ReviewStatus.warning);
  });
  test('Save validates completion and traceability, then isolates drafts', () {
    final state = AppState();
    addTearDown(state.dispose);
    const id = 'TC-AUTH-002';
    final e = state.draft(id);
    expect(state.save(id), isNotNull);
    for (final c in Criterion.values) {
      e.criteria[c] = ReviewStatus.pass;
    }
    expect(state.save(id), contains('Map a requirement'));
    e.requirementId = 'SRS-AUTH-01';
    expect(state.save(id), isNull);
    expect(state.reviewed, 2);
    expect(state.status(id), ReviewStatus.pass);
    expect(
      state.testCases.firstWhere((t) => t.id == id).executionResult,
      'Failed',
    );
    e.criteria[Criterion.srsConsistency] = ReviewStatus.fail;
    expect(state.status(id), ReviewStatus.pass);
    expect(state.save(id), contains('Describe the issue'));
    e.issues = 'Contradicts SRS.';
    expect(state.save(id), isNull);
    expect(state.status(id), ReviewStatus.fail);
    expect(state.reviewed, 2);
    final snapshot = state.saved(id)!;
    snapshot.issues = 'Changed outside state';
    expect(state.saved(id)!.issues, 'Contradicts SRS.');
  });
}
