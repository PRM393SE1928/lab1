# Phase 4: persistent local workspace

## Scope

Persist imported Test Cases (including source IDs, additional columns and original execution
results), parsed SRS sections, file metadata, Excel diagnostics, primary mappings, saved
evaluations, separate draft evaluations, all seven criteria, overrides, issues, fixes, notes,
review timestamps and the selected Test Case. Search indexes are rebuilt on restore.
No changes to evaluation rules, Excel/DOCX parsing or Phase 5 export are part of this phase.

The original brief allowed a simple local store, preferring SQLite when practical.
Sembast was chosen to keep Chrome and Windows on the same transaction API without SQLite
WASM assets or new native plugins. Chrome uses IndexedDB and desktop uses a Sembast file.
Dependencies added: `sembast`, `sembast_web`; `path` changed from transitive to direct.

## Files

Created:
- `lib/models/workspace_snapshot.dart`: version 1 serialization and validated restoration.
- `lib/services/workspace_store.dart`: storage contract, atomic record and revision protection.
- `lib/services/local_workspace.dart`, `local_workspace_io.dart`, `local_workspace_web.dart`: platform selection.
- `test/workspace_persistence_test.dart`: persistence, separate drafts, failures, replacement, concurrency and disk reopen tests.
- `test/workspace_widget_test.dart`: startup failure/retry and draft restoration through UI recreation.
- `tool/verify_workspace_web.dart`, `tool/browser_storage_probe.cjs`: actual Chrome IndexedDB verification using an isolated test database/profile.
- `tool/serve_web.cjs`: serves the built web app locally at a stable `127.0.0.1:8081` address.
- `docs/phase4_persistence.md`: this document.

Modified: `main.dart`, `providers/app_state.dart`, the shell/import/review/report screens,
`widgets/app_sidebar.dart`, `pubspec.yaml`, `pubspec.lock`, and README. Formatting also
normalized `models/srs_section.dart`; its behavior is unchanged.

## Behavior and integrity

Startup loads and validates the complete workspace before rendering the review screens.
Missing storage starts with samples; malformed/unsupported data shows a retry screen and
blocks automatic overwrite. The original database is not silently reset.

Every draft edit queues an immediate local write. Pending writes are serialized, coalescing
later edits so an earlier snapshot cannot become the final record. One transaction stores
the whole workspace, keeping imports, evaluations and mappings consistent. Status indicates
Saving locally, Saved locally, or Not saved locally. Save Evaluation waits for local writing
before reporting success. Failed writes retain in-memory changes and offer Retry saving.

Draft persistence does not mark a case reviewed. Dashboard/Reports still use saved evaluations.
Re-import behavior is preserved: successful Excel replacement clears its reviews/drafts;
confirmed SRS replacement clears mappings while retaining judgments and notes. Cancelled or
failed imports do not replace the stored workspace. New parsed data persists without storing
the original file bytes or reopening file-picker handles after restart.

Revision checks reject an older tab's write after another tab commits a newer workspace.
There is no automatic cross-tab merge; use one reviewer tab at a time.

Windows location: `%APPDATA%\TestCaseReview\review_workspace.db`.
Chrome database: `test_case_review_workspace`, local to the origin and browser profile.
Keep a fixed host/port; browser storage is not shared with the desktop application.
Wait for Saved locally before closing. Browser storage can be removed through site-data
clearing, private-session termination or browser eviction; it is not a cloud backup.

## Validation status

Completed:
- Full regression suite: **43/43 tests passed** on 2026-09-26 with all three real-file
  environment variables set. Includes disk close/reopen, failed-write retry, serial writes,
  separate drafts, failed-import preservation, stale-writer rejection, UI recreation/restore,
  startup error/retry, and the Phase 1–3 real Excel/SRS regression checks.
- Actual headless Chrome passed IndexedDB write and read after page navigation/recreation.
  The probe uses a dedicated test database; it never opens the application's real workspace.
- Final `flutter analyze`: **No issues found**.

- `flutter build web --no-pub`: **passed**, including the Wasm dry run. A pre-existing
  CupertinoIcons font warning is non-fatal; the web output was generated successfully.
- Built app served at `http://127.0.0.1:8081` using `node tool/serve_web.cjs`.

Dependency resolution/download completed. Flutter's post-resolution Windows plugin-link
step reported that Developer Mode/symlink support is unavailable. No system settings were
changed. The native tests and the Chrome IndexedDB probe still executed successfully.

## Manual acceptance after starting the updated build

1. Run the updated app on the same browser profile/address (`127.0.0.1:8081`).
2. Import an Excel workbook and SRS, then wait for Saved locally.
3. Map a case, edit criteria and notes, and save its evaluation. Wait for Saved locally.
4. Make an additional draft-only note on that case without Save Evaluation. Wait for Saved locally.
5. Reload the page or close/reopen at the same address. Imported files, counts, mapping,
   saved judgment and the separate draft note should return without selecting source files.
6. Verify Reports still shows the saved evaluation, not the unsaved draft changes.
7. Import a corrupt file and reload: the previous workspace must remain.
8. Cancel SRS replacement and reload: old mappings must remain. Confirm replacement and reload:
   mappings must be cleared, while notes/judgments remain.
9. For Windows, repeat by closing/reopening the application; check its separate local workspace.

The Phase 4 built app is available on port 8081. If an older Phase 3 tab is still open,
load the new build only after finishing that session; the older version did not persist
its in-memory data, so its files must be imported once in Phase 4. To start the built app
again after stopping the local server, run `node tool/serve_web.cjs` from this project.
Do not run a Flutter development server on the same port at the same time.
