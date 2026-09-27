/// Workbook header aliases live here; the UI never depends on column indexes.
enum ExcelField {
  id,
  module,
  description,
  preconditions,
  steps,
  testData,
  expectedResult,
  executionResult,
}

class ExcelColumnMapping {
  static const aliases = <ExcelField, List<String>>{
    ExcelField.id: [
      'Test Case ID',
      'Test Case',
      'TestCaseID',
      'Test ID',
      'TC ID',
      'TCID',
      'Case ID',
      'ID',
      'Test Case No',
      'Test Case Number',
    ],
    ExcelField.module: [
      'Module',
      'Module Name',
      'Feature',
      'Feature Name',
      'Function',
      'Function Name',
      'Component',
      'Test Suite',
    ],
    ExcelField.description: [
      'Description',
      'Test Case Description',
      'Test Description',
      'Test Case Name',
      'Test Case Title',
      'Title',
      'Test Scenario',
      'Scenario',
      'Test Objective',
      'Objective',
    ],
    ExcelField.preconditions: [
      'Precondition',
      'Preconditions',
      'Pre-condition',
      'Pre-conditions',
      'Prerequisite',
      'Prerequisites',
      'Precondition(s)',
      'Pre Condition',
    ],
    ExcelField.steps: [
      'Steps',
      'Test Steps',
      'Test Step',
      'Procedure',
      'Test Procedure',
      'Test Case Procedure',
      'Procedure / Steps',
      'Steps to Execute',
      'Steps to Reproduce',
      'Action',
      'Actions',
    ],
    ExcelField.testData: ['Test Data', 'Input Data', 'Input', 'Inputs', 'Data'],
    ExcelField.expectedResult: [
      'Expected Result',
      'Expected Results',
      'Expected Outcome',
      'Expected Output',
      'Expected',
      'Expected Behavior',
      'Expected Behaviour',
    ],
    // Execution status is deliberately separate from design evaluation.
    ExcelField.executionResult: [
      'Execution Status',
      'Execution Result',
      'Test Execution Result',
      'Test Result',
      'Test Status',
      'Status',
      'Result',
      'Pass/Fail',
      'Passed/Failed',
      'Actual Result',
      'Actual Results',
    ],
  };

  static String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static final _lookup = <String, ExcelField>{
    for (final entry in aliases.entries)
      for (final alias in entry.value) normalize(alias): entry.key,
  };

  static Map<ExcelField, int> detect(List<String> row) {
    final result = <ExcelField, int>{};
    for (var i = 0; i < row.length; i++) {
      final field = _lookup[normalize(row[i])];
      if (field != null) {
        // Prefer explicit status over Actual Result, and explicit ID over
        // ambiguous "Test Case", when both occur in the same header.
        final existing = result[field];
        if (existing == null ||
            aliases[field]!.indexWhere(
                  (a) => normalize(a) == normalize(row[i]),
                ) <
                aliases[field]!.indexWhere(
                  (a) => normalize(a) == normalize(row[existing]),
                )) {
          result[field] = i;
        }
      }
    }
    return result;
  }

  static bool isTestCaseHeader(Map<ExcelField, int> mapping) =>
      mapping.containsKey(ExcelField.id);

  static int? executionRound(String header) => int.tryParse(
    RegExp(r'^(?:testing)?round(\d+)(?:result|status)?$')
            .firstMatch(normalize(header))
            ?.group(1) ??
        '',
  );
}
