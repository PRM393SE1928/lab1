class TestCase {
  const TestCase({
    required this.id,
    this.sourceId,
    required this.module,
    required this.description,
    required this.preconditions,
    required this.steps,
    required this.testData,
    required this.expectedResult,
    this.executionResult = '',
    this.additionalFields = const {},
  });
  final String id;

  /// Original Excel ID when a duplicate needed a distinct internal key.
  final String? sourceId;
  String get displayId => sourceId ?? id;
  final String module;
  final String description;
  final String preconditions;
  final List<String> steps;
  final String testData;
  final String expectedResult;
  final String executionResult;
  final Map<String, String> additionalFields;
}
