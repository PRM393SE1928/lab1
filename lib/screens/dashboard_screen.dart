import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../providers/app_state.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final total = state.testCases.length;
    final progress = total == 0 ? 0.0 : state.reviewed / total;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SummaryCard(label: 'Total Test Cases', value: '$total'),
            SummaryCard(label: 'Reviewed', value: '${state.reviewed}'),
            SummaryCard(
              label: 'Not Reviewed',
              value: '${total - state.reviewed}',
            ),
            for (final s in [
              ReviewStatus.pass,
              ReviewStatus.warning,
              ReviewStatus.fail,
            ])
              SummaryCard(label: s.label, value: '${state.count(s)}'),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Review progress · ${state.reviewed} / $total · ${(progress * 100).toStringAsFixed(1)}%',
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: progress, minHeight: 8),
        const SizedBox(height: 28),
        Text('By module', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Module')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Reviewed')),
              DataColumn(label: Text('PASS')),
              DataColumn(label: Text('WARNING')),
              DataColumn(label: Text('FAIL')),
            ],
            rows: state.modules.map((module) {
              final cases = state.testCases
                  .where((t) => t.module == module)
                  .toList();
              return DataRow(
                cells: [
                  DataCell(Text(module)),
                  DataCell(Text('${cases.length}')),
                  DataCell(
                    Text(
                      '${cases.where((t) => state.status(t.id) != ReviewStatus.notEvaluated).length}',
                    ),
                  ),
                  for (final s in [
                    ReviewStatus.pass,
                    ReviewStatus.warning,
                    ReviewStatus.fail,
                  ])
                    DataCell(
                      Text(
                        '${cases.where((t) => state.status(t.id) == s).length}',
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
