import 'package:flutter/material.dart';

const pageLabels = [
  'Dashboard',
  'Import Files',
  'Test Case Review',
  'Issues',
  'Reports',
];
const pageIcons = [
  Icons.dashboard_outlined,
  Icons.upload_file_outlined,
  Icons.fact_check_outlined,
  Icons.warning_amber_outlined,
  Icons.assessment_outlined,
];

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.compact,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final bool compact;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: compact ? 72 : 210,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            child: compact
                ? const Icon(Icons.fact_check, size: 28)
                : const Text(
                    'TEST CASE\nAnalysis & Evaluation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                for (var i = 0; i < pageLabels.length; i++)
                  compact
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: IconButton(
                            tooltip: pageLabels[i],
                            isSelected: selected == i,
                            onPressed: () => onSelected(i),
                            icon: Icon(pageIcons[i]),
                          ),
                        )
                      : ListTile(
                          selected: selected == i,
                          leading: Icon(pageIcons[i]),
                          title: Text(pageLabels[i]),
                          onTap: () => onSelected(i),
                        ),
              ],
            ),
          ),
          if (!compact)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Test Case workspace',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    ),
  );
}
