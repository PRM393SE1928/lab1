# Test Case Analysis & Evaluation

A Flutter Material 3 desktop application for evaluating test-case design against SRS requirements.

## Implemented features

- Persistent sidebar with Dashboard, Import Files, Test Case Review, Issues, and Reports.
- Four sample test cases and two sample requirements.
- Seven evaluation criteria, critical-failure rules, and manual overall override.
- Search and module/status filters, requirement selection, issue/fix/notes editing.
- Save validation, draft retention, live statistics, issue links, report preview.
- Real `.xlsx` selection and import across all recognized worksheets (Phase 2).
- Real `.docx` SRS import, local search, and manual primary-section mapping (Phase 3).
- Local workspace persistence and automatic restore (Phase 4).
- Excel evaluation report export with summary and module statistics (Phase 5).

Original execution results are independent from design evaluation. Only saved evaluations
affect statistics and reports. Imports, mappings, evaluations and drafts are saved locally.
Wait for **Saved locally** before closing the tab or application.

Imported cases do not use sample SRS requirements.

## Export an evaluation report

1. Finish reviewing cases and click **Save Evaluation** for judgments you want included.
2. Open **Reports**, check the summary and any excluded-draft count, then click **Export Excel**.
3. Chrome downloads the `.xlsx`; Windows opens a Save As dialog. Choose a new report file.
4. Inspect **Summary**, **Evaluations**, and **By Module** in Excel or LibreOffice.

Reports include every imported case, including Not Reviewed cases. Only saved evaluation
judgments and mappings are exported; draft changes remain separate. The original execution
result is a separate column. Percentages use all cases (within the module for module rows).
Source SRS paths/references appear as traceability evidence, never generated section keys.
Sample workspaces are clearly marked SAMPLE in the filename and summary.

See [Phase 5 changed files, report format and test instructions](docs/phase5_export.md).

## Import and map your SRS

1. Open **Import Files → Select SRS**, choose your `.docx`, then click **Parse SRS**.
2. Check **Completed**, the active filename, section count, and searchable block count.
3. Open **Test Case Review**, choose a case, and click **Find Requirement**.
4. Search by title, reference, or text (for example `3.2.1` or `login`). Optionally filter by category.
5. Click **Select** and review the source content. Use **Change Requirement** or **Remove Mapping** as needed.
6. Choose the seven evaluation criteria yourself and save the evaluation. Mapping alone does not change any criterion.

Mappings and drafts survive navigation and restart after local saving completes. Saved reports display the source section path.
Replacing SRS requires confirmation when saved or draft mappings exist; cancellation or failure keeps
the previous SRS and all review work. Successful replacement clears mappings but keeps judgments and notes.

DOCX is read locally using ZIP/XML, with parsing on a background isolate on desktop.
Word headings, numbered headings, table rows, and Unicode are preserved as structured sections.
If a combined report has an explicit **Software Requirement Specification** chapter, only that chapter
is indexed. Otherwise the document's headings are used. Search uses a cached, whitespace-normalized,
case-insensitive index; all entered tokens must match. Source wording is not rewritten.

See [Phase 3 implementation, validation, limitations and manual test steps](docs/phase3_srs_validation.md).

## Local workspace storage (Phase 4)

Chrome uses IndexedDB; Windows uses `%APPDATA%\TestCaseReview\review_workspace.db`.
The storage layer uses Sembast transactions on both platforms. No cloud service or account is required.
Browser data belongs to the same browser profile and exact address, including the port.
Use a stable address, such as `http://127.0.0.1:8081`, on every run:

```powershell
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8081
```

Changing the port or using `localhost` instead of `127.0.0.1` opens a different browser workspace.
Clearing site data removes that browser's database. Private-browsing storage is temporary.
Windows and Chrome have separate local workspaces.

The app restores parsed data without reopening the original XLSX/DOCX. Select a source file
again only when replacing an import. Source file bytes and picker handles are not stored.
Existing Phase 3 tabs contain session-only data; that old in-memory data is not automatically
migrated. Import your files once after starting the Phase 4 build.

See [Phase 4 implementation and current validation status](docs/phase4_persistence.md).

Phase 4 validation: analyzer clean, 43 tests passed, web release build passed, and actual
Chrome IndexedDB write/read after navigation passed. To serve the already-built app,
run `node tool/serve_web.cjs` and open `http://127.0.0.1:8081`.

## Import your workbook

1. Open **Import Files**, then **Select Test Case File** and choose an `.xlsx` file.
2. Click **Import / Parse**. Check the per-sheet counts and any import notes.
3. Click **Open Test Case Review**, or visit Dashboard to see the new statistics.

A successful import replaces all current test cases and clears their evaluations and
drafts. Imported cases start as **Not Reviewed**, even when the original execution
status is Passed/Failed. Failed imports and cancelled file selection preserve the workspace.

Only a **Test Case ID** column is required; incomplete cases remain reviewable.
The first 30 non-empty rows are searched for header candidates; explicit ID labels
and richer mappings rank above ambiguous metadata. Blank/title rows need no edits.
Aliases include Test Case, TC ID, Test Case Procedure, Actual Results, and Status.
They are centralized in `lib/services/excel_column_mapping.dart`.

Cover/statistics/summary/function-index sheets are classified as ignored. Other sheets
without a detected header are listed in collapsed diagnostics, not repeated red errors.
Malformed sheets are classified as failed; usable sheets can still import. If no cases
are found, the current workspace is retained and a friendly message asks you to verify
the Test Case Report file. The inspected Unit Test/function-matrix workbook is detected
from its cover and function-sheet structure and is not imported.

Merged section headings are skipped. In the project's TC-prefixed tables, standalone
non-TC text headings are treated as sections as well. Repeated IDs retain their original
display text but receive distinct internal keys based on worksheet and row. Their
evaluations cannot overwrite each other. Missing modules use the worksheet name.

All non-empty source columns, including Actual Result, are retained under
**Original Excel fields and source** in the review screen. Explicit execution status
takes precedence; otherwise the latest non-empty numbered Round supplies the execution
result. Every round is retained. Actual Result is a fallback when no status column exists.
Formula cells use their stored cached results when present; uncached formulas are
retained as text and noted. No formulas are executed. Dates use the workbook's date system.
Password-protected, legacy `.xls`, and CSV files are not supported. Multi-row test cases
with vertically merged IDs are not combined automatically.

The import reads bytes once, indexes the ZIP once, then streams cell values from XML.
It never expands declared empty ranges or creates styled-cell objects. Async batches
yield to the browser event loop; progress shows reading, scanning, parsing, and completion.
The case list is committed to AppState once after successful parsing.

See [real-workbook validation and exact changed files](docs/phase2_import_validation.md).

## Run on Windows

Install Flutter and Visual Studio with the Desktop development with C++ workload.

```powershell
cd D:\FlutterTutorial\flutter_application_1\flutter_application_2
flutter pub get
flutter run -d windows
```

If Flutter is not on PATH, use `D:\Flutter\flutter\bin\flutter.bat`.

## Verify

```powershell
flutter analyze
flutter test
flutter build windows
```

## Structure

- `lib/models`: requirement, test case, and evaluation data.
- `lib/data`: clearly identified sample data.
- `lib/providers`: ChangeNotifier state and session save validation.
- `lib/screens`: desktop shell and five screens.
- `lib/widgets`: sidebar, list, criteria controls, badges, and summary cards.
- `lib/services`: native file selection, Excel decoding/column mapping, and DOCX SRS parsing.

Import uses `archive` and `xml` for a read-only sparse XLSX reader, and `file_selector`
for native file selection. `excel` generates export workbooks and test fixtures.
Tests cover parsing, state replacement, failure preservation, and the UI workflow.
Optional real-file regression checks run when `TEST_REPORT_XLSX` and `UNIT_TEST_XLSX`
environment variables point to the inspected project files; those files are read-only.
Set `SRS_DOCX` to the real Report7 DOCX path to enable the SRS integration test.

For per-sheet diagnostics without launching the UI:

```powershell
dart run tool/verify_excel_import.dart "C:\path\to\TestReport.xlsx"
```
