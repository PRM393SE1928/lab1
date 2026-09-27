import '../models/requirement.dart';
import '../models/test_case.dart';

const sampleRequirements = [
  Requirement(
    id: 'SRS-AUTH-01',
    title: 'Account login',
    section: '3.1 Authentication',
    description:
        'An active registered user can log in with a valid email and password. '
        'Successful login opens the dashboard. Invalid credentials display an error and do not grant access.',
    sourceReference: 'Sample SRS, section 3.1',
  ),
  Requirement(
    id: 'SRS-REPORT-01',
    title: 'Evaluation report',
    section: '3.2 Reporting',
    description: 'The reviewer can export evaluations and summary statistics to an Excel workbook.',
    sourceReference: 'Sample SRS, section 3.2',
  ),
];
const sampleTestCases = [
  TestCase(
    id: 'TC-AUTH-001',
    module: 'Authentication',
    description: 'Verify login using valid credentials.',
    preconditions: 'Registered active account exists.',
    steps: [
      'Open Login page.',
      'Enter valid email.',
      'Enter valid password.',
      'Click Login.',
    ],
    testData: '',
    expectedResult: 'User is authenticated and redirected to the dashboard.',
    executionResult: 'Passed',
  ),
  TestCase(
    id: 'TC-AUTH-002',
    module: 'Authentication',
    description: 'Reject an incorrect password.',
    preconditions: 'Active test account exists.',
    steps: [
      'Open Login page.',
      'Enter qa@example.test and WrongPassword.',
      'Click Login.',
      'Verify an error is displayed and the dashboard is inaccessible.',
    ],
    testData: 'Email: qa@example.test; password: WrongPassword (invalid).',
    expectedResult: 'An authentication error appears and access is denied.',
    executionResult: 'Failed',
  ),
  TestCase(
    id: 'TC-AUTH-003',
    module: 'Authentication',
    description: 'Log in with an invalid password.',
    preconditions: 'Active account exists.',
    steps: ['Enter an invalid password.', 'Click Login.'],
    testData: 'qa@example.test / WrongPassword',
    expectedResult: 'The dashboard opens successfully.',
  ),
  TestCase(
    id: 'TC-REPORT-001',
    module: 'Reporting',
    description: 'Export completed evaluations.',
    preconditions: 'At least one evaluation is saved.',
    steps: [
      'Open Reports.',
      'Choose Export.',
      'Select a destination.',
      'Open the workbook.',
    ],
    testData: 'A reviewed test case with an issue and suggested fix.',
    expectedResult:
        'Workbook includes evaluation details and summary statistics.',
  ),
];
