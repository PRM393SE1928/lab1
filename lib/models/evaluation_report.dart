import 'evaluation.dart';
import 'srs_section.dart';
import 'test_case.dart';

/// A detached view of saved evaluations at the moment Export is clicked.
class EvaluationReport {
  EvaluationReport({
    required List<TestCase> testCases,
    required Map<String, Evaluation> evaluations,
    required List<SrsSection> sections,
    required this.createdAt,
    required this.sampleData,
    this.excelName,
    this.srsName,
    this.omittedDrafts = 0,
  }) : testCases = List.unmodifiable(testCases),
       evaluations = Map.unmodifiable(
         evaluations.map((key, value) => MapEntry(key, value.copy())),
       ),
       sections = Map.unmodifiable({for (final s in sections) s.id: s});
  final List<TestCase> testCases;
  final Map<String, Evaluation> evaluations;
  final Map<String, SrsSection> sections;
  final DateTime createdAt;
  final String? excelName, srsName;
  final bool sampleData;
  final int omittedDrafts;
}
