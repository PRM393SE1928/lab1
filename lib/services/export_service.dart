import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../models/evaluation_report.dart';
import 'report_builder.dart';
export 'report_builder.dart' show ReportExportException;

class ExportService {
  String get successMessage => kIsWeb
      ? 'Excel download requested. Check your browser downloads.'
      : 'Excel report saved.';
  Future<String?> chooseDestination(String suggestedName) async {
    if (kIsWeb) return suggestedName;
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel report', extensions: ['xlsx']),
      ],
    );
    final path = location?.path;
    return path == null || path.toLowerCase().endsWith('.xlsx')
        ? path
        : '$path.xlsx';
  }

  Future<Uint8List> generate(EvaluationReport report) =>
      compute(buildEvaluationReport, report);
  Future<void> save(Uint8List bytes, String destination) => XFile.fromData(
    bytes,
    name: destination.split(RegExp(r'[/\\]')).last,
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ).saveTo(destination);
}
