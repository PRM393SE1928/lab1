# Phase 2: real-workbook validation

## Inspected originals (read-only)

Files found in `C:\Users\DELL\Downloads`:

- `9747_HCM_SU26SE017_GSU10_HCM_Report5_TestReport.xlsx`
- `9747_HCM_SU26SE017_GSU10_HCM_Report5UnitTest.xlsx`

The Test Report contains 13 worksheets: Cover, Test Cases (a function/sheet index),
Test Statistics, and 10 module sheets. The actual case headers are on row 10,
columns A:P. Stored worksheet dimensions extend to roughly 875-1007 rows and
column Z, although most of those rows are formatted blanks.

| Source column | Field |
|---|---|
| A: Test Case ID | Original ID |
| B: Test Case Description | Description |
| C: Test Case Procedure | Steps |
| D: Expected Results | Expected result |
| E: Pre-conditions | Preconditions |
| F / I / L: Round 1 / 2 / 3 | Latest non-empty execution round; all rounds retained |
| G / J / M: Test date | Original fields, disambiguated by column |
| H / K / N: Tester | Original fields, disambiguated by column |
| O: Note; P: Execution Type | Original fields |

Merged section headings span A:P. `M09_User_Role_Permissions` also has an
unmerged heading at A11. These are sections, not test cases. The workbook reuses
`TC-NOT-UI-05`, `TC-NOT-UI-06`, and `TC-NOT-UI-07` in both Notifications and
Dashboard Reports. All six rows are preserved with distinct internal identities;
the original IDs remain visible and searchable.

| Module sheet | Cases | Observed non-empty range |
|---|---:|---|
| M01_Authentication | 30 | A2:R43 |
| M02_Project_Management | 21 | A2:R33 |
| M03_Document_Management | 113 | A2:R126 |
| M04_BIM_3D_Viewer | 59 | A2:R80 |
| M05_Approval_Workflow | 31 | A2:R44 |
| M06_Issue_Tracking_BCF | 39 | A2:R53 |
| M07_Notifications | 14 | A2:R26 |
| M08_Dashboard_Reports | 14 | A2:R26 |
| M09_User_Role_Permissions | 9 | A2:R20 |
| M10_System_Settings | 8 | A2:R19 |
| **Total** | **338** | |

The Unit Test workbook has 48 worksheets: Cover, Functions, Statistics and
45 F-prefixed function sheets. For example, F01 and F02 place individual case IDs
across F9 onward, with Condition/Precondition rows beneath them. This transposed
unit-test matrix is not the Test Case Report. Its explicit UNIT TEST DOCUMENT
cover plus function-index/sheet structure allows early rejection.

## Strategy and performance

- Search the first 30 **non-empty** rows, not just row 1 or the first 30 physical rows.
- Normalize whitespace, casing, punctuation and line breaks; rank candidate headers
  using centralized aliases. Only the ID column is mandatory.
- Skip named metadata sheets before decompressing their worksheet XML. Classify
  other sheets with no usable table as ignored. Failed sheets have separate diagnostics.
- Decode the ZIP directory once, read each needed worksheet once, stream only cell
  values and merge references. Do not expand empty dimensions or construct cell styles.
- Yield after 250 stored XML rows and between sheets so browser events can run.
  Only progress notifications occur during parsing; commit the new case list once.
- Store original fields and worksheet/row provenance. Do not infer design evaluation
  from Passed/Failed execution results. Every imported case starts Not Reviewed.

One local native measurement on the real Test Report: previous full styled-workbook
reader plus row traversal **9,539 ms**; sparse importer **2,856 ms**. The Unit Test
workbook was classified in **318 ms** after early detection. These are measurements,
not timing guarantees; debug/browser speed and concurrent load differ.

## Reproduce the checks

```powershell
$env:TEST_REPORT_XLSX = 'C:\Users\DELL\Downloads\9747_HCM_SU26SE017_GSU10_HCM_Report5_TestReport.xlsx'
$env:UNIT_TEST_XLSX = 'C:\Users\DELL\Downloads\9747_HCM_SU26SE017_GSU10_HCM_Report5UnitTest.xlsx'
flutter analyze
flutter test
flutter test --platform chrome test/excel_hardening_test.dart
dart run tool/verify_excel_import.dart $env:TEST_REPORT_XLSX $env:UNIT_TEST_XLSX
```

The real-workbook test is skipped when those environment variables are absent.
The synthetic regression fixtures contain no copied project test-case content.

Validation outcome: dependency resolution succeeded, Flutter analysis reported no
issues, and all 25 native tests passed with both real-workbook paths supplied.
The normal `flutter build web` also succeeded.
The headless Chrome test run was blocked before executing tests: Flutter's test
server returned HTTP 404 for `/canvaskit/chromium/canvaskit.js` and `.wasm` even
though those files exist in the SDK. This is recorded separately from parser tests;
no Flutter SDK files were modified to work around the test-server issue.

Original-file SHA-256 hashes were identical before and after validation:

- Test Report: `4E339044E2D4FF1DE684AC881B05ABA3E2333520E54E2E54461B896AE72988D9`
- Unit Test: `BC406E64F830D9488BFE4D49A84EF51FF79DBDDBA7F642877E95F36D342E9BFA`

## Manual acceptance check

1. Restart the app to load the changed parser. If using the web-server target,
   refresh its browser tab after restarting the server.
2. Select **Import Files > Select Test Case File**, then choose the file ending
   `_Report5_TestReport.xlsx` (not `Report5UnitTest.xlsx`).
3. Click **Import / Parse**. Expect **338 cases, 13 scanned sheets, 10 Test Case
   sheets, 3 ignored, 0 failed**. Ignored: Cover, Test Cases, Test Statistics.
4. Open **Worksheet diagnostics**: module headers should be row 10 with steps
   mapped to C. A compact note identifies the three repeated original IDs.
5. Open **Test Case Review** and check procedure steps, preconditions, and execution
   result. Expand **Original Excel fields and source** to see all three rounds.
6. Dashboard should show **338 total, 0 reviewed, 338 not reviewed** immediately
   after import. Search a repeated ID: both module-specific cases must be available.
7. Select the Unit Test workbook and import it. Expect one friendly format message;
   the 338-case workspace and any saved evaluations must remain intact.

## Exact changed files

Modified:

- `pubspec.yaml`: archive/xml runtime dependencies; excel moved to dev dependencies.
- `pubspec.lock`: dependency classifications updated.
- `lib/models/excel_import_result.dart`: sheet classifications, diagnostics and timings.
- `lib/models/test_case.dart`: original display ID separate from unique internal ID.
- `lib/providers/app_state.dart`: progress and last-attempt diagnostics; atomic import retained.
- `lib/services/excel_column_mapping.dart`: aliases, minimum ID requirement, round recognition.
- `lib/services/excel_service.dart`: responsive reader, progress, diagnostic logging.
- `lib/screens/import_screen.dart`: concise counts, progress and expandable diagnostics.
- `lib/screens/review_screen.dart`: display/search original IDs.
- `lib/screens/issues_screen.dart`: display/search original IDs.
- `lib/screens/report_screen.dart`: display original IDs.
- `lib/widgets/test_case_list.dart`: original IDs and module context for duplicates.
- `test/excel_service_test.dart`: revised alias, ignored-sheet and duplicate behavior.
- `test/excel_import_widget_test.dart`: updated service callback signature.
- `README.md`: current import behavior and verification instructions.

Added:

- `lib/services/xlsx_reader.dart`: sparse read-only XLSX reader.
- `lib/services/excel_parser.dart`: header detection, classification and case extraction.
- `test/excel_hardening_test.dart`: layout, sparse-range, malformed-sheet and responsiveness tests.
- `test/real_excel_workbook_test.dart`: opt-in regression using the actual workbooks.
- `tool/verify_excel_import.dart`: read-only diagnostic and timing command.
- `docs/phase2_import_validation.md`: this inspection and validation report.

Phase 3 remains unimplemented. The original Excel workbooks are not edited.
