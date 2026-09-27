import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../models/evaluation.dart';
import '../providers/app_state.dart';
import '../widgets/status_badge.dart';
import '../services/export_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.state, this.exportService});
  final AppState state;
  final ExportService? exportService;
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  AppState get state => widget.state;
  late final service = widget.exportService ?? ExportService();
  bool exporting = false;
  String? exportStatus;
  bool exportFailed = false;

  Future<void> export() async {
    if (exporting) return;
    final report = state.captureReport();
    final originalPath = state.importedFilePath;
    setState(() {
      exporting = true;
      exportFailed = false;
      exportStatus = 'Preparing export...';
    });
    try {
      final stamp = report.createdAt.toUtc().toIso8601String().replaceAll(
        RegExp(r'[:.\-]'),
        '',
      );
      final destination = await service.chooseDestination(
        '${report.sampleData ? 'SAMPLE_' : ''}Evaluation_Report_$stamp.xlsx',
      );
      if (destination == null) {
        if (mounted) setState(() => exportStatus = 'Export cancelled.');
        return;
      }
      if (originalPath != null &&
          path.normalize(destination).toLowerCase() ==
              path.normalize(originalPath).toLowerCase()) {
        throw const ReportExportException(
          'Choose a different file. The imported source workbook must not be overwritten.',
        );
      }
      if (mounted) setState(() => exportStatus = 'Generating Excel report...');
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final bytes = await service.generate(report);
      await service.save(bytes, destination);
      if (mounted) setState(() => exportStatus = service.successMessage);
    } catch (error) {
      if (mounted) {
        setState(() {
          exportFailed = true;
          exportStatus = error is ReportExportException ? error.message : 'Could not export the report. Close the destination file if it is open, check write permissions or browser downloads, and try again. Your workspace was not changed.';
        });
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Evaluation summary', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Text(
        'Total: ${state.testCases.length} · Reviewed: ${state.reviewed} · '
        'Not Reviewed: ${state.count(ReviewStatus.notEvaluated)}',
      ),
      const SizedBox(height: 12),
      for (final s in [
        ReviewStatus.pass,
        ReviewStatus.warning,
        ReviewStatus.fail,
      ])
        Text(
          '${s.label}: ${state.count(s)} '
          '(${(state.testCases.isEmpty ? 0 : 100 * state.count(s) / state.testCases.length).toStringAsFixed(1)}% of all test cases)',
        ),
      const SizedBox(height: 20),
      const Text(
        'Exports saved evaluations only. Draft changes are excluded until you click Save Evaluation.',
      ),
      if (state.unsavedDraftCount > 0)
        Text(
          '${state.unsavedDraftCount} test cases have draft changes that will not be exported.',
        ),
      if (!state.hasImportedCases)
        const Text(
          'Sample data: the workbook will be marked as a demonstration report.',
        ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: exporting || state.testCases.isEmpty ? null : export,
          icon: const Icon(Icons.download),
          label: const Text('Export Excel'),
        ),
      ),
      if (exporting)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(),
        ),
      if (exportStatus != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SelectableText(
            exportStatus!,
            style: TextStyle(
              color: exportFailed ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ),
      const SizedBox(height: 20),
      const Text('Preview of saved results'),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            for (final label in [
              'Test Case ID',
              'Module',
              'SRS requirement',
              'Evaluation',
              'Original execution',
            ])
              DataColumn(label: Text(label)),
          ],
          rows: state.testCases
              .map(
                (t) => DataRow(
                  cells: [
                    DataCell(Text(t.displayId)),
                    DataCell(Text(t.module)),
                    DataCell(
                      Text(
                        state.mappingLabel(state.saved(t.id)?.requirementId),
                      ),
                    ),
                    DataCell(StatusBadge(state.status(t.id))),
                    DataCell(
                      Text(
                        t.executionResult.isEmpty
                            ? 'Not provided'
                            : t.executionResult,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}
