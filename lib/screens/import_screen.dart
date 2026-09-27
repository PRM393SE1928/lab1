import 'package:flutter/material.dart';

import '../providers/app_state.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({
    super.key,
    required this.state,
    required this.onOpenReview,
  });
  final AppState state;
  final VoidCallback onOpenReview;

  @override
  Widget build(BuildContext context) {
    final file = state.selectedExcelFile;
    final result = state.importResult;
    final busy = state.importing || state.selectingFile;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Select a Test Case Excel workbook, then import it. '
          'All worksheets with recognized test-case headers will be read.',
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SRS document (.docx)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'File name: ${state.selectedSrsFile?.name ?? state.importedSrsFileName ?? 'No file selected'}',
                ),
                SelectableText(
                  'File path: ${state.selectedSrsFile?.path ?? state.importedSrsPath ?? 'Not selected'}',
                ),
                Text('Status: ${state.srsStatus}'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: state.srsBusy ? null : state.selectSrsFile,
                      child: const Text('Select SRS'),
                    ),
                    FilledButton(
                      onPressed: state.srsBusy || state.selectedSrsFile == null
                          ? null
                          : () async {
                              await state.importSelectedSrs(
                                confirmReplacement: (count) async {
                                  if (!context.mounted) return false;
                                  return await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Replace SRS?'),
                                          content: Text(
                                            'Replacing the SRS will clear $count existing requirement mappings. Evaluations and notes will be kept; review their traceability against the new SRS. Continue?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Replace SRS'),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;
                                },
                              );
                            },
                      child: const Text('Parse SRS'),
                    ),
                  ],
                ),
                if (state.srsBusy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (state.srsError != null)
                  SelectableText(
                    state.srsError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (state.importedSrsFileName != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    'Active SRS: ${state.importedSrsFileName}\n${state.importedSrsPath}',
                  ),
                  Text('Sections detected: ${state.srsSections.length}'),
                  Text(
                    'Searchable blocks: ${state.srsSections.fold<int>(0, (n, s) => n + s.blocks.length)}',
                  ),
                ],
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test Case report (.xlsx)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'File name: ${file?.name ?? state.importedFileName ?? 'No file selected'}',
                ),
                SelectableText(
                  'File path: ${file?.path ?? state.importedFilePath ?? 'Not selected'}',
                ),
                const SizedBox(height: 12),
                Text(
                  state.importing
                      ? state.importStatus
                      : state.selectingFile
                      ? 'Import status: Selecting file...'
                      : state.importError != null
                      ? 'Import status: Failed'
                      : file == null
                      ? state.importResult == null
                            ? 'Import status: No file selected'
                            : 'Import status: Restored from local storage'
                      : state.selectedFileImported
                      ? 'Import status: Completed'
                      : 'Import status: Ready to import',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy ? null : state.selectExcelFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select Test Case File'),
                    ),
                    FilledButton.icon(
                      onPressed: busy || file == null
                          ? null
                          : () async {
                              await state.importSelectedExcel();
                            },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import / Parse'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Import replaces the current test cases and clears their saved evaluations and drafts. '
                  'A failed import keeps the current workspace intact. Check the save status before closing the app.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose the project Test Case Report, not the Unit Test/function workbook. '
                  'Title rows, section headings, and alternate column names are detected automatically. '
                  'Only the Test Case ID column is required; missing review fields stay empty.',
                ),
                if (state.importing)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (state.importError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SelectableText(
                      state.importError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (result != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last successful import',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    '${state.importedFileName}\n${state.importedFilePath}',
                  ),
                  Text(
                    'Imported ${result.testCases.length} test cases. All start as Not Reviewed.',
                  ),
                  Text(
                    '${result.sheetsScanned} worksheets scanned · '
                    '${result.sheetCounts.length} Test Case sheets · '
                    '${result.ignoredSheets.length} ignored · ${result.failedSheets.length} failed',
                  ),
                  Text(
                    'Parsing time: ${(result.elapsedMilliseconds / 1000).toStringAsFixed(2)} seconds',
                  ),
                  if (result.ignoredSheets.isNotEmpty)
                    Text(
                      'Ignored: ${result.ignoredSheets.map((s) => s.name).join(', ')}',
                    ),
                  if (result.failedSheets.isNotEmpty)
                    Text(
                      'Some sheets could not be imported: ${result.failedSheets.map((s) => s.name).join(', ')}. See diagnostics below.',
                    ),
                  if (result.warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ExpansionTile(
                      title: Text('Import notes (${result.warnings.length})'),
                      children: [
                        for (final warning in result.warnings)
                          ListTile(title: SelectableText(warning)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: busy ? null : onOpenReview,
                    child: const Text('Open Test Case Review'),
                  ),
                ],
              ),
            ),
          ),
        if (state.importDiagnostics.isNotEmpty)
          Card(
            child: ExpansionTile(
              title: const Text('Worksheet diagnostics (last attempt)'),
              children: [
                for (final diagnostic in state.importDiagnostics)
                  ListTile(
                    title: Text(
                      '${diagnostic.name} · ${diagnostic.disposition.name}',
                    ),
                    subtitle: SelectableText(diagnostic.debugSummary),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
