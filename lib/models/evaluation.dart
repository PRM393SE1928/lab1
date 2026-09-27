enum ReviewStatus {
  notEvaluated('NOT EVALUATED'),
  pass('PASS'),
  warning('WARNING'),
  fail('FAIL');

  const ReviewStatus(this.label);
  final String label;
}

enum Criterion {
  requirementTraceability('Requirement Traceability', true),
  stepClarity('Step Clarity', false),
  stepCompleteness('Step Completeness', true),
  testDataPreconditions('Test Data / Preconditions', false),
  expectedResultCorrectness('Expected Result Correctness', true),
  srsConsistency('SRS Consistency', true),
  testability('Testability / Executability', true);

  const Criterion(this.label, this.critical);
  final String label;
  final bool critical;
}

class Evaluation {
  Evaluation({
    required this.testCaseId,
    this.requirementId,
    Map<Criterion, ReviewStatus>? criteria,
    this.overrideStatus,
    this.issues = '',
    this.suggestedFix = '',
    this.reviewerNotes = '',
    this.reviewedAt,
  }) : criteria = {
         for (final c in Criterion.values)
           c: criteria?[c] ?? ReviewStatus.notEvaluated,
       };
  final String testCaseId;

  /// Primary SRS section's internal key (or a sample requirement key).
  /// Mapping supplies evidence only; it never changes criterion judgments.
  String? requirementId;
  final Map<Criterion, ReviewStatus> criteria;
  ReviewStatus? overrideStatus;
  String issues;
  String suggestedFix;
  String reviewerNotes;
  DateTime? reviewedAt;

  ReviewStatus get suggestedStatus {
    if (Criterion.values.any(
      (c) => c.critical && criteria[c] == ReviewStatus.fail,
    )) {
      return ReviewStatus.fail;
    }
    if (criteria.values.contains(ReviewStatus.notEvaluated)) {
      return ReviewStatus.notEvaluated;
    }
    if (criteria.values.any(
      (s) => s == ReviewStatus.warning || s == ReviewStatus.fail,
    )) {
      return ReviewStatus.warning;
    }
    return ReviewStatus.pass;
  }

  ReviewStatus get overallStatus => overrideStatus ?? suggestedStatus;
  bool get isComplete => !criteria.values.contains(ReviewStatus.notEvaluated);
  Evaluation copy() => Evaluation(
    testCaseId: testCaseId,
    requirementId: requirementId,
    criteria: criteria,
    overrideStatus: overrideStatus,
    issues: issues,
    suggestedFix: suggestedFix,
    reviewerNotes: reviewerNotes,
    reviewedAt: reviewedAt,
  );
}
