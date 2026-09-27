import 'package:flutter/material.dart';

import '../models/srs_section.dart';

class SrsContent extends StatefulWidget {
  const SrsContent({super.key, required this.section});
  final SrsSection section;
  @override
  State<SrsContent> createState() => _SrsContentState();
}

class _SrsContentState extends State<SrsContent> {
  final controller = ScrollController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 240,
    child: Scrollbar(
      controller: controller,
      child: ListView.builder(
        controller: controller,
        primary: false,
        itemCount: widget.section.blocks.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SelectableText(widget.section.blocks[i]),
        ),
      ),
    ),
  );
}

class SrsSearchDialog extends StatefulWidget {
  const SrsSearchDialog({super.key, required this.index});
  final SrsIndex index;
  @override
  State<SrsSearchDialog> createState() => _SrsSearchDialogState();
}

class _SrsSearchDialogState extends State<SrsSearchDialog> {
  String query = '';
  String? category;
  @override
  Widget build(BuildContext context) {
    final results = widget.index.search(query, category: category);
    final categories =
        widget.index.sections.map((s) => s.category).toSet().toList()..sort();
    return AlertDialog(
      title: const Text('Find Requirement'),
      content: SizedBox(
        width: 800,
        height: 540,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search section, title or content',
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                for (final c in categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (value) => setState(() => category = value),
            ),
            const SizedBox(height: 8),
            Text('${results.length} sections'),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('No matching requirements.'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final s = results[i];
                        final preview = s.blocks.isEmpty
                            ? 'Heading with subsections'
                            : s.blocks.first;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.path,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${s.sectionNumber ?? 'No explicit source reference'} · ${s.category}',
                                ),
                                Text(
                                  preview.length > 350
                                      ? '${preview.substring(0, 350)}…'
                                      : preview,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, s.id),
                                  child: const Text('Select'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
