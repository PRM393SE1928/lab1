import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../providers/app_state.dart';
import '../widgets/test_case_list.dart';
import '../widgets/criteria_selector.dart';
import '../widgets/status_badge.dart';
import '../widgets/srs_widgets.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.state});
  final AppState state;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String query = '';
  String? module;
  ReviewStatus? status;
  @override
  Widget build(BuildContext context) {
    final cases = widget.state.testCases
        .where(
          (t) =>
              (module == null || t.module == module) &&
              (status == null || widget.state.status(t.id) == status) &&
              '${t.displayId} ${t.description} ${t.module}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    final index = cases.indexWhere((t) => t.id == widget.state.selectedId);
    void select(String id) => setState(() => widget.state.selectTestCase(id));
    final list = TestCaseList(
      state: widget.state,
      cases: cases,
      onSelected: select,
      onQuery: (value) => setState(() => query = value),
      module: module,
      status: status,
      onModule: (value) => setState(() => module = value),
      onStatus: (value) => setState(() => status = value),
    );
    final form = ReviewForm(
      key: ValueKey(widget.state.selectedId),
      state: widget.state,
      previous: index > 0 ? () => select(cases[index - 1].id) : null,
      next: index >= 0 && index < cases.length - 1
          ? () => select(cases[index + 1].id)
          : null,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: LayoutBuilder(
        builder: (context, size) {
          if (size.maxWidth < 680) {
            return Column(
              children: [
                SizedBox(height: size.maxHeight * 0.45, child: list),
                const Divider(),
                Expanded(child: form),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 280, child: list),
              const SizedBox(width: 16),
              Expanded(child: form),
            ],
          );
        },
      ),
    );
  }
}

class ReviewForm extends StatefulWidget {
  const ReviewForm({super.key, required this.state, this.previous, this.next});
  final AppState state;
  final VoidCallback? previous;
  final VoidCallback? next;
  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  late final Evaluation evaluation;
  late final TextEditingController issues;
  late final TextEditingController fix;
  late final TextEditingController notes;
  @override
  void initState() {
    super.initState();
    evaluation = widget.state.draft(widget.state.selectedId);
    issues = TextEditingController(text: evaluation.issues);
    fix = TextEditingController(text: evaluation.suggestedFix);
    notes = TextEditingController(text: evaluation.reviewerNotes);
  }

  @override
  void dispose() {
    issues.dispose();
    fix.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> chooseRequirement() async {
    final index = widget.state.requirementIndex;
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SrsSearchDialog(index: index),
    );
    if (mounted && id != null) {
      if (!identical(index, widget.state.requirementIndex)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The SRS changed while searching. Find the requirement in the current SRS.',
            ),
          ),
        );
        return;
      }
      widget.state.mapRequirement(evaluation.testCaseId, id);
      setState(() {});
    }
  }

  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
  Widget detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        SelectableText(value.isEmpty ? 'Not provided' : value),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final t = widget.state.testCases.firstWhere(
      (t) => t.id == evaluation.testCaseId,
    );
    final mapped = widget.state.sectionFor(evaluation.requirementId);
    return Card(
      margin: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(t.displayId, style: Theme.of(context).textTheme.titleLarge),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(widget.state.status(t.id)),
          ),
          const Text(
            'Status above reflects the last save. Draft edits are kept separately from saved evaluations.',
            style: TextStyle(fontSize: 12),
          ),
          heading('A · Test Case Information'),
          detail('Module', t.module),
          detail('Description', t.description),
          detail('Preconditions', t.preconditions),
          detail(
            'Steps',
            t.steps.indexed
                .map((step) => '${step.$1 + 1}. ${step.$2}')
                .join('\n'),
          ),
          detail('Test Data', t.testData),
          detail('Expected Result', t.expectedResult),
          detail(
            'Original execution result (separate from design evaluation)',
            t.executionResult,
          ),
          if (t.additionalFields.isNotEmpty)
            ExpansionTile(
              title: const Text('Original Excel fields and source'),
              children: [
                for (final field in t.additionalFields.entries)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: detail(field.key, field.value),
                  ),
              ],
            ),
          heading('B · SRS Requirement'),
          if (mapped == null)
            const Text('No SRS requirement mapped.')
          else ...[
            detail('Section', mapped.path),
            detail(
              'Reference',
              mapped.sectionNumber ?? 'No explicit source reference',
            ),
            detail('Category', mapped.category),
            if (mapped.blocks.isEmpty)
              const Text(
                'This heading contains subsections. Search for a more specific section to see its content.',
              )
            else
              SrsContent(key: ValueKey(mapped.id), section: mapped),
          ],
          if (widget.state.requirementIndex.sections.isEmpty)
            const Text(
              'Import an SRS document from Import Files to find requirements.',
            ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: widget.state.requirementIndex.sections.isEmpty
                    ? null
                    : chooseRequirement,
                icon: const Icon(Icons.search),
                label: Text(
                  mapped == null ? 'Find Requirement' : 'Change Requirement',
                ),
              ),
              TextButton(
                onPressed: mapped == null
                    ? null
                    : () => setState(
                        () => widget.state.mapRequirement(
                          evaluation.testCaseId,
                          null,
                        ),
                      ),
                child: const Text('Remove Mapping'),
              ),
            ],
          ),
          heading('C · Evaluation'),
          const Text(
            'Judge test-case design against the requirement. Use WARNING for minor omissions; '
            'FAIL on completeness means major steps are missing.',
          ),
          const SizedBox(height: 12),
          for (final c in Criterion.values)
            CriteriaSelector(
              criterion: c,
              value: evaluation.criteria[c]!,
              onChanged: (value) => setState(() {
                evaluation.criteria[c] = value;
                widget.state.draftChanged();
              }),
            ),
          heading('D · Result'),
          Text('Suggested Overall Status: ${evaluation.suggestedStatus.label}'),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReviewStatus>(
            initialValue: evaluation.overrideStatus,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Manual overall override',
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Use suggested status'),
              ),
              for (final s in [
                ReviewStatus.pass,
                ReviewStatus.warning,
                ReviewStatus.fail,
              ])
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (value) => setState(() {
              evaluation.overrideStatus = value;
              widget.state.draftChanged();
            }),
          ),
          const SizedBox(height: 8),
          Text('Overall Evaluation: ${evaluation.overallStatus.label}'),
          heading('E · Issues'),
          TextField(
            controller: issues,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Issues'),
            onChanged: (value) {
              evaluation.issues = value;
              widget.state.draftChanged();
            },
          ),
          heading('F · Suggested Fix'),
          TextField(
            controller: fix,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Suggested Fix'),
            onChanged: (value) {
              evaluation.suggestedFix = value;
              widget.state.draftChanged();
            },
          ),
          heading('G · Reviewer Notes'),
          TextField(
            controller: notes,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Reviewer Notes (optional)',
            ),
            onChanged: (value) {
              evaluation.reviewerNotes = value;
              widget.state.draftChanged();
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: widget.previous,
                child: const Text('Previous'),
              ),
              FilledButton(
                onPressed: () async {
                  final error = widget.state.save(t.id);
                  if (error == null) await widget.state.flushWorkspace();
                  if (!context.mounted) return;
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error ??
                            (widget.state.storageError != null
                                ? 'Evaluation updated but not saved locally. See the storage warning.'
                                : widget.state.persistenceEnabled
                                ? 'Evaluation saved locally.'
                                : 'Evaluation saved for this session.'),
                      ),
                    ),
                  );
                },
                child: const Text('Save Evaluation'),
              ),
              OutlinedButton(onPressed: widget.next, child: const Text('Next')),
            ],
          ),
          if (evaluation.reviewedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Last saved: ${evaluation.reviewedAt!.toLocal()}'),
            ),
        ],
      ),
    );
  }
}
