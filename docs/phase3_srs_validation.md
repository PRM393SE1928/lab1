# Phase 3: SRS import, search and mapping

## Files

Created:
- `lib/models/srs_section.dart`: structured source sections and cached search index.
- `lib/services/srs_service.dart`: DOCX selection and import orchestration.
- `lib/services/srs_parser.dart`: platform-independent ZIP/XML extraction and section detection; verifies consumed XML parts without requesting verification of unrelated media.
- `tool/verify_srs_web.dart`: JavaScript-backend parser diagnostic (run under Node; not a browser picker test).
- `lib/widgets/srs_widgets.dart`: search dialog and lazy source-content view.
- `test/support/docx_fixture.dart`: small DOCX fixtures.
- `test/srs_service_test.dart`, `test/srs_state_test.dart`, `test/srs_widget_test.dart`: extraction, search, mapping, failure/replacement and UI coverage.
- `docs/phase3_srs_validation.md`: this record.

Modified:
- `lib/providers/app_state.dart`: SRS metadata, import progress, staged replacement and session mapping.
- `lib/models/evaluation.dart`: documents the existing `requirementId` as the primary section's internal key; no duplicate mapping field.
- `lib/screens/import_screen.dart`: enabled SRS selection/parsing and replacement confirmation.
- `lib/screens/review_screen.dart`: search/select/change/remove mappings and source content.
- `lib/screens/report_screen.dart`: source section paths instead of internal keys.
- `test/widget_test.dart`: scroll the save control completely into view after the expanded SRS panel.
- `README.md`: Phase 3 usage.

No packages added. Existing `archive`, `xml`, `file_selector`, and Flutter `compute` are reused.
Excel parser, column mapping, Dashboard and evaluation rules are preserved.

## Implementation

The picker accepts DOCX. The service reads bytes once and parses `word/document.xml`
and heading information from `word/styles.xml` in a background isolate on desktop.
Paragraph text retains Unicode, XML entity decoding, explicit line breaks and tabs.
Tables become ordered row blocks with cell separators. Images and unsupported formatting
are not rendered. Ordinary paragraphs are collected under a heading, not converted into
individual requirements. Table/figure captions remain content even when styled as headings.

Heading levels, explicit numbered headings, and known SRS headings establish parent paths.
Categories are inherited from functional/non-functional/use-case/rule/message headings.
Explicit source references are retained separately from `srs_section_*` application keys.
For combined reports, an explicit Software Requirement Specification chapter is bounded by
the next same-or-higher-level heading. This prevents later design/manual chapters entering
the requirement index. Standalone SRS documents use the full document heading structure.

The service builds one in-memory index after parsing. Search matches all normalized query
tokens across reference, title, parent path, content, category and keywords. Search does not
read or unzip files. Results and selected content use lazy lists, not a whole-document Text.

The existing Evaluation.requirementId holds zero or one primary section key. Mapping edits
update the session draft; Save Evaluation commits a copy for reports, retaining existing
validation. Criteria and status remain reviewer-controlled. Drafts survive screen/case changes.
Replacement is parsed first, then asks permission to clear affected mappings. Confirmed
replacement clears saved/draft mapping keys only; judgments, notes and test cases remain.
Failed/cancelled imports preserve the active document, cases, saved reviews, drafts and mappings.

## Validation

Final checks: `flutter pub get` succeeded, `flutter analyze` reported no issues,
and `flutter test` passed **all 36 tests** with the three real-file environment
variables set (no skipped real-file checks). The native OS picker and a packaged
Windows build were not manually exercised in this phase.

Real input read without modification:
`C:\Users\DELL\Downloads\9747_HCM_SU26SE017_GSU10_HCM_Report7.docx`.
Detected **151 SRS sections and 1,678 content blocks**. The `3.2.1 Login` section has
12 blocks and retains Authentication → Functional Requirements parent context.
Counts refer to this local document revision, not all possible Report7 versions.

Automated coverage includes DOCX selection controls, Unicode/entities/breaks/tabs/table order,
heading hierarchy, combined-report boundaries, search/category filters, invalid/empty/missing
document XML, mapping changes/removal, independent cases, replacement confirmation,
failed-import preservation, and the existing Excel and review-screen regressions.

## Limitations

- Session only; no persistence, export, automatic evaluation or local suggestions added.
- Automatic Word list numbering is not reconstructed; literal source numbers and IDs are
  preserved. When absent, the UI explicitly says no source reference is available.
- Heading detection is heuristic for unstyled text. Documents with no useful headings are
  rejected; custom style inheritance without an explicit heading name/outline may need support.
- Tables are text rows, not a visual reproduction of merged cells. Images, diagrams, headers,
  footers, comments, embedded objects and visual page layout are not included. No OCR or PDF.
- Native desktop parsing uses an isolate. Flutter web runs `compute` on its main event loop,
  so large DOCX parsing can briefly block browser interaction; desktop is the primary target.
- Native OS file-picker interaction needs the manual check below; widget tests inject a picker.

## Manual test steps

1. Start the updated app from the project directory: `flutter run -d windows`.
   If the Windows build toolchain is unavailable, use `flutter run -d chrome` or
   `flutter run -d web-server --web-port=8080` and open its printed address.
   Restart an older running app to load these changes; restarting clears session work.
2. Import your real Test Case Report with **Select Test Case File → Import / Parse**.
   Confirm Dashboard counts and original execution results still match the workbook.
3. In **Import Files**, click **Select SRS**, choose Report7.docx and verify filename/path
   and **Ready to parse**. Click **Parse SRS**, then check **Completed** and the counts.
4. Open **Test Case Review**, choose a login case, and scroll to **SRS Requirement**.
   Click **Find Requirement**, search `3.2.1`, then try ` LOGIN ` and an appropriate category.
5. Select **3.2.1 Login**. Confirm the reference, category, parent path and source text appear.
   Scroll the source panel to see further paragraphs/rows. Criteria must remain unchanged.
6. Map another case, return to the first, and navigate via Dashboard back to Review.
   Verify both mappings remain distinct. Change one mapping and then remove it.
7. Choose all seven criteria, supply issues when required, and **Save Evaluation**.
   In Reports verify that the saved mapping displays a section path, not `srs_section_*`.
8. Select another SRS and parse it. With mappings present, click **Cancel** at replacement
   confirmation and verify existing work remains. Repeat and confirm replacement; mappings
   clear but notes, criteria, test cases and original execution results remain.
9. Try an empty/corrupt DOCX. Verify a useful error and retention of the last successful SRS
   plus all saved/draft reviews. Cancel the file picker and verify it also preserves state.
10. Close and reopen only after finishing session checks; session data is intentionally lost.

To run real-file integration tests, set `SRS_DOCX`, `TEST_REPORT_XLSX` and `UNIT_TEST_XLSX`
to their local paths, then run `flutter pub get`, `flutter analyze` and `flutter test`.
