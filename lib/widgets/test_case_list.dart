import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../models/test_case.dart';
import '../providers/app_state.dart';
import 'status_badge.dart';

class TestCaseList extends StatelessWidget {
  const TestCaseList({
    super.key,
    required this.state,
    required this.cases,
    required this.onSelected,
    required this.onQuery,
    required this.module,
    required this.status,
    required this.onModule,
    required this.onStatus,
  });
  final AppState state;
  final List<TestCase> cases;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onQuery;
  final String? module;
  final ReviewStatus? status;
  final ValueChanged<String?> onModule;
  final ValueChanged<ReviewStatus?> onStatus;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(
        onChanged: onQuery,
        decoration: const InputDecoration(
          labelText: 'Search test cases',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: module,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Module'),
        items: [
          const DropdownMenuItem(value: null, child: Text('All modules')),
          for (final m in state.modules)
            DropdownMenuItem(value: m, child: Text(m)),
        ],
        onChanged: onModule,
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<ReviewStatus>(
        initialValue: status,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Evaluation Status'),
        items: [
          const DropdownMenuItem(value: null, child: Text('All statuses')),
          for (final s in ReviewStatus.values)
            DropdownMenuItem(
              value: s,
              child: Text(
                s == ReviewStatus.notEvaluated ? 'Not Reviewed' : s.label,
              ),
            ),
        ],
        onChanged: onStatus,
      ),
      const SizedBox(height: 8),
      Text('${cases.length} matching test cases'),
      const SizedBox(height: 8),
      Expanded(
        child: cases.isEmpty
            ? const Center(child: Text('No matching test cases.'))
            : ListView.builder(
                itemCount: cases.length,
                itemBuilder: (context, index) {
                  final t = cases[index];
                  return Card(
                    child: ListTile(
                      selected: state.selectedId == t.id,
                      title: Text(t.displayId),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (t.sourceId != null) Text(t.module),
                          Text(
                            t.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          StatusBadge(state.status(t.id)),
                        ],
                      ),
                      onTap: () => onSelected(t.id),
                    ),
                  );
                },
              ),
      ),
    ],
  );
}
