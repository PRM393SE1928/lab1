import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../models/excel_import_result.dart';
import 'excel_parser.dart';
export 'excel_parser.dart' show parseExcelBytes, parseExcelBytesResponsive;

class ExcelService {
  Future<XFile?> selectFile() => openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Test Case Report (.xlsx)', extensions: ['xlsx']),
    ],
  );

  Future<ExcelImportResult> importFile(
    XFile file, {
    void Function(String)? onProgress,
  }) async {
    if (!file.name.toLowerCase().endsWith('.xlsx')) {
      throw const ExcelImportException(
        'Select an .xlsx Test Case Report. Legacy .xls and CSV files are not supported.',
      );
    }
    onProgress?.call('Reading workbook...');
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const ExcelImportException(
        'Could not read the selected file. Check that it exists and that you have permission to open it.',
      );
    }
    try {
      final result = await parseExcelBytesResponsive(
        bytes,
        onProgress: onProgress,
      );
      if (kDebugMode) {
        for (final diagnostic in result.diagnostics) {
          debugPrint(diagnostic.debugSummary);
        }
        debugPrint(
          '[Excel Import] ${result.testCases.length} cases in ${result.elapsedMilliseconds} ms',
        );
      }
      return result;
    } on ExcelImportException catch (error) {
      if (kDebugMode) {
        for (final diagnostic in error.diagnostics) {
          debugPrint(diagnostic.debugSummary);
        }
      }
      rethrow;
    }
  }
}
