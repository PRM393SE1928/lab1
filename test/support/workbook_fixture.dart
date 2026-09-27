import 'dart:typed_data';

import 'package:excel/excel.dart';

Uint8List workbookBytes(Map<String, List<List<Object?>>> sheets) {
  final book = Excel.createExcel();
  for (final entry in sheets.entries) {
    for (final row in entry.value.indexed) {
      book[entry.key].insertRowIterables(
        row.$2
            .map<CellValue?>(
              (value) => switch (value) {
                null => null,
                CellValue() => value,
                int() => IntCellValue(value),
                double() => DoubleCellValue(value),
                bool() => BoolCellValue(value),
                _ => TextCellValue(value.toString()),
              },
            )
            .toList(),
        row.$1,
      );
    }
  }
  if (!sheets.containsKey('Sheet1')) book.delete('Sheet1');
  return Uint8List.fromList(book.encode()!);
}

Uint8List basicWorkbook({String id = 'REAL-001'}) => workbookBytes({
  'Authentication': [
    [
      'Test Case ID',
      'Description',
      'Procedure / Steps',
      'Expected Result',
      'Execution Status',
      'Actual Result',
    ],
    [
      id,
      'Verify real login',
      'Open login\nEnter credentials',
      'Dashboard opens',
      'Passed',
      'Dashboard opened',
    ],
  ],
});
