import 'package:flutter/material.dart';

import '../models/evaluation.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final ReviewStatus status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ReviewStatus.pass => Colors.green.shade800,
      ReviewStatus.warning => Colors.orange.shade900,
      ReviewStatus.fail => Colors.red.shade800,
      ReviewStatus.notEvaluated => Colors.blueGrey.shade700,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        switch (status) {
          ReviewStatus.pass => Icons.check_circle_outline,
          ReviewStatus.warning => Icons.warning_amber,
          ReviewStatus.fail => Icons.cancel_outlined,
          ReviewStatus.notEvaluated => Icons.pending_outlined,
        },
        size: 16,
        color: color,
      ),
      label: Text(
        status == ReviewStatus.notEvaluated ? 'Not Reviewed' : status.label,
        style: TextStyle(color: color, fontSize: 12),
      ),
      backgroundColor: color.withValues(alpha: 0.07),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
    );
  }
}
