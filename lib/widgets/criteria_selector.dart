import 'package:flutter/material.dart';

import '../models/evaluation.dart';

class CriteriaSelector extends StatelessWidget {
  const CriteriaSelector({
    super.key,
    required this.criterion,
    required this.value,
    required this.onChanged,
  });
  final Criterion criterion;
  final ReviewStatus value;
  final ValueChanged<ReviewStatus> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: DropdownButtonFormField<ReviewStatus>(
      key: ValueKey('${criterion.name}-${value.name}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: criterion.label,
        helperText: criterion.critical
            ? 'FAIL indicates a critical problem'
            : 'Quality issue: suggested WARNING',
      ),
      items: [
        for (final status in ReviewStatus.values)
          DropdownMenuItem(value: status, child: Text(status.label)),
      ],
      onChanged: (status) {
        if (status != null) onChanged(status);
      },
    ),
  );
}
