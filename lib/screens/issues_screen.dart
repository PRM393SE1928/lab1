import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../providers/app_state.dart';
import '../widgets/status_badge.dart';

class IssuesScreen extends StatefulWidget {
  const IssuesScreen({super.key, required this.state, required this.onOpen});
  final AppState state;
  final ValueChanged<String> onOpen;
  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  String query = '';
  ReviewStatus? filter;
  @override
  Widget build(BuildContext context) {
    final cases = widget.state.testCases.where((t) {
      final e = widget.state.saved(t.id);
      return e != null &&
          e.issues.trim().isNotEmpty &&
          (filter == null || e.overallStatus == filter) &&
          '${t.displayId} ${e.issues}'.toLowerCase().contains(
            query.toLowerCase(),
          );
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search test case ID or issue',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final s in [null, ReviewStatus.warning, ReviewStatus.fail])
              ChoiceChip(
                label: Text(s?.label ?? 'All'),
                selected: filter == s,
                onSelected: (_) => setState(() => filter = s),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (cases.isEmpty)
          const Text('No saved issues match these filters.')
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: [
                for (final label in [
                  'Test Case ID',
                  'Module',
                  'Status',
                  'Issue',
                  'Suggested Fix',
                ])
                  DataColumn(label: Text(label)),
              ],
              rows: cases.map((t) {
                final e = widget.state.saved(t.id)!;
                return DataRow(
                  onSelectChanged: (_) => widget.onOpen(t.id),
                  cells: [
                    DataCell(Text(t.displayId)),
                    DataCell(Text(t.module)),
                    DataCell(StatusBadge(e.overallStatus)),
                    DataCell(
                      SizedBox(
                        width: 280,
                        child: Text(
                          e.issues,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 280,
                        child: Text(
                          e.suggestedFix,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Select a row to open its full evaluation. Only saved evaluations are shown.',
        ),
      ],
    );
  }
}
