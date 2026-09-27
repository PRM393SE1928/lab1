# Phase 5: Excel evaluation export

## Changed files

Created:
- `lib/models/evaluation_report.dart`: detached snapshot of cases and saved evaluations.
- `lib/services/report_builder.dart`: workbook generation, formatting and statistics.
- `lib/services/export_service.dart`: desktop destination picker, generation and file/browser saving.
- `test/export_service_test.dart`: workbook readback, statistics, Unicode, source results, snapshot isolation, limits, disk saving and real-file export.
- `test/export_widget_test.dart`: export workflow, busy state, cancellation, errors/retry and source overwrite protection.
- `tool/browser_export_probe.cjs`: headless Chrome test of the actual Reports export button/download, using a separate browser profile and test download directory.
- `docs/phase5_export.md`: this document.

Modified:
- `lib/providers/app_state.dart`: report snapshot and changed-draft count; no changes to persistence schema.
- `lib/screens/report_screen.dart`: enabled Export Excel, progress/result feedback and scope explanation.
- `pubspec.yaml` / `pubspec.lock`: existing `excel: ^4.0.6` moved from development to runtime dependencies. No new package version introduced.
- `tool/serve_web.cjs`: general server startup label.
- `README.md`: export instructions.

Excel import, SRS parsing, evaluation rules and persisted Phase 4 records remain compatible.

## Workbook contents

**Evaluations**: Test Case ID, Module, Related SRS Requirement, SRS Reference/Category,
all seven criteria, Overall Evaluation, Suggested Overall Evaluation, Manual Override,
Issues, Suggested Fix, Reviewer Notes, Original Execution Result, Description, Preconditions,
Steps, Test Data, Expected Result, Reviewed At (UTC), and Application Case Key.

The source Test Case ID is retained, including duplicates. A separately labelled application
key distinguishes duplicate rows. SRS traceability uses source paths and explicit references,
never internal generated SRS keys. Original execution outcomes are not interpreted as judgments.
Unreviewed cases have NOT EVALUATED criteria/results and empty reviewer fields.

**Summary**: source filenames, UTC export time, sample/real-data identification, saved-only
scope, omitted-draft count, total/reviewed/not-reviewed counts, PASS/WARNING/FAIL counts and
percentages, and review progress. Percentage cells are numeric values from 0 to 100 with two
decimal places. Denominator is all Test Cases, matching Dashboard.

**By Module**: the same counts and percentages grouped by module; percentages use all cases
in that module. Blank modules are retained as a blank group instead of inventing source text.

Headers use contrasting colors, long text wraps, columns have usable widths, and overall
status cells are color-coded. Text is explicitly written as text, including strings beginning
with `=`, leading-zero IDs/test data, Unicode and newlines. Source text is not evaluated as
spreadsheet formulas. Sample reports have a SAMPLE filename prefix and summary notice.

## Scope and error handling

Export captures a snapshot when clicked, so later edits cannot mix versions in one workbook.
Only Save Evaluation results are included. Autosaved draft data remains a draft and does not
silently enter a submitted report. Manual overrides are exported alongside suggested results.

On Windows the native Save As picker requests a report destination; selecting the imported
workbook itself is rejected. Other overwrite confirmation is handled by the operating-system
picker. On Chrome, the browser handles downloading and possible filename collision suffixes.
The success message says download requested rather than claiming the browser has stored it.

Cancel/failure leave the workspace intact; failed exports can be retried. Duplicate clicks
are disabled while an export is running. No cloud upload or automatic evaluation is involved.
Excel cells longer than 32,767 characters fail with row/column information instead of silently
truncating the source/reviewer text. Large generation can briefly occupy Chrome's main thread;
desktop generation uses Flutter compute in a background isolate.

## Validation

- `flutter pub get`: passed.
- `flutter analyze`: no issues.
- Full suite: **53/53 tests passed**, including real Excel/SRS checks and export/readback of
  every Test Case from the real Report5 workbook.
- Native export test writes a real temporary XLSX and reads it back successfully. The native
  Windows Save As dialog still needs the manual check below.
- Web release build passed with local render resources (`--no-web-resources-cdn`).
  The pre-existing CupertinoIcons font warning remains non-fatal.
- Actual Chrome end-to-end check passed: opened the built app, clicked Reports and Export
  Excel, and downloaded an 8,601-byte XLSX. ZIP/XML readback confirmed all three sheets and
  four sample case rows plus the header. The probe used a separate browser profile, so it
  did not modify the user's persistent workspace.
- Updated app served at `http://127.0.0.1:8081`.

## Manual test

### Excel XML repair fix

The default column width API in excel 4.0.6 emitted `sheetFormatPr` before
`dimension`/`sheetViews`, without `defaultRowHeight`, on Evaluations and By Module.
Report generation now sets widths per column, avoiding that malformed element.
A regression test checks worksheet element order and required row height when present.

Validation after this fix: all 11 export service/widget tests passed (including the
real workbook check), Flutter analysis was clean, and the web release build passed.
Chrome downloaded the updated 8,642-byte sample report. Microsoft Excel opened it
read-only in normal load mode and retained all three sheets: Summary (20 rows),
Evaluations (5 rows), and By Module (3 rows). The compatibility check is reproducible
with `tool/verify_excel_compatibility.ps1 -ReportPath <xlsx>`; it never saves the file.
Previously downloaded reports must be exported again from the updated application.

1. Open the updated app at `http://127.0.0.1:8081`. If an old tab is open, wait for Saved locally
   before refreshing. Keep the same host/port/profile to retain your Phase 4 workspace.
2. Import your Test Case workbook/SRS if no workspace has been saved yet.
3. Map a case, complete all seven criteria, add issues when required, and click Save Evaluation.
4. Edit one note without Save Evaluation. Reports should identify a case with excluded draft changes.
5. Click Export Excel and open the downloaded `.xlsx`.
6. Check the three sheets, counts versus Dashboard, SRS path/reference, original execution
   column, seven criterion columns, saved notes and any override. The draft-only note must be absent.
7. Save that draft evaluation and export again; the new report should include it.
8. Confirm unreviewed cases remain present and duplicate source IDs retain distinct rows.
9. On Windows, choose a new destination, cancel once, then save. Choosing the imported source
   workbook must be rejected. Export must not reset reviews or modify the imported files.
10. Reload the app: Phase 4 persistence and saved report data should remain unchanged.

To start the built app: `node tool/serve_web.cjs`.
