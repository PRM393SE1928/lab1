import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

String cleanCell(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\u00a0', ' ')
    .trim();

int columnIndex(String reference) {
  var result = 0;
  for (final code in reference.toUpperCase().codeUnits) {
    if (code < 65 || code > 90) break;
    result = result * 26 + code - 64;
  }
  return result - 1;
}

String columnName(int index) {
  var name = '';
  for (var n = index + 1; n > 0; n = (n - 1) ~/ 26) {
    name = String.fromCharCode(65 + (n - 1) % 26) + name;
  }
  return name;
}

class CellRange {
  CellRange(String reference) {
    final ends = reference.replaceAll(r'$', '').split(':');
    firstColumn = columnIndex(ends.first);
    lastColumn = columnIndex(ends.last);
    firstRow = int.parse(ends.first.replaceAll(RegExp('[A-Za-z]'), ''));
    lastRow = int.parse(ends.last.replaceAll(RegExp('[A-Za-z]'), ''));
  }
  late final int firstColumn, lastColumn, firstRow, lastRow;
}

class SparseRow {
  SparseRow(this.number, this.cells);
  final int number;
  final Map<int, String> cells;
  String at(int? column) => cells[column] ?? '';
}

class SparseSheet {
  SparseSheet(this.name);
  final String name;
  final rows = <SparseRow>[];
  final merges = <CellRange>[];
  String declaredRange = '';
  int storedRows = 0;
  int formulaCells = 0;
  String get usedRange {
    if (rows.isEmpty) return '';
    final columns = rows.expand((r) => r.cells.keys);
    final low = columns.reduce((a, b) => a < b ? a : b);
    final high = columns.reduce((a, b) => a > b ? a : b);
    return '${columnName(low)}${rows.first.number}:${columnName(high)}${rows.last.number}';
  }
}

/// Read-only XLSX: decompress each requested XML part once; never construct the
/// rectangular styled-cell grid or expand the workbook's declared dimensions.
class XlsxReader {
  XlsxReader(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    _files = {for (final file in archive.files) file.name: file};
    final workbook = XmlDocument.parse(_read('xl/workbook.xml'));
    final relations = XmlDocument.parse(_read('xl/_rels/workbook.xml.rels'));
    final targets = <String, String>{
      for (final r in relations.descendants.whereType<XmlElement>().where(
        (e) =>
            e.name.local == 'Relationship' &&
            e.getAttribute('TargetMode') != 'External',
      ))
        r.getAttribute('Id')!: Uri.parse('xl/workbook.xml')
            .resolve(r.getAttribute('Target')!)
            .path
            .replaceFirst(RegExp(r'^/'), ''),
    };
    for (final sheet in workbook.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'sheet',
    )) {
      final id = sheet.attributes.firstWhere((a) => a.name.local == 'id').value;
      final path = targets[id];
      if (path != null) sheets[sheet.getAttribute('name')!] = path;
    }
    date1904 = workbook.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'workbookPr')
        .any((e) => ['1', 'true'].contains(e.getAttribute('date1904')));
    final stringsPath = targets.values
        .where((p) => p.endsWith('sharedStrings.xml'))
        .firstOrNull;
    final strings = _optional(stringsPath ?? 'xl/sharedStrings.xml');
    if (strings != null) {
      final xml = XmlDocument.parse(strings);
      _strings = [
        for (final item in xml.rootElement.childElements)
          item.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 't')
              .map((e) => e.innerText)
              .join(),
      ];
    }
    final stylesPath = targets.values
        .where((p) => p.endsWith('styles.xml'))
        .firstOrNull;
    final styles = _optional(stylesPath ?? 'xl/styles.xml');
    if (styles != null) {
      final xml = XmlDocument.parse(styles);
      final formats = <int, String>{
        for (final e in xml.descendants.whereType<XmlElement>().where(
          (e) => e.name.local == 'numFmt',
        ))
          int.parse(e.getAttribute('numFmtId')!): e.getAttribute('formatCode')!,
      };
      final xfs = xml.rootElement.childElements
          .where((e) => e.name.local == 'cellXfs')
          .firstOrNull;
      if (xfs != null) {
        for (final xf in xfs.childElements) {
          final id = int.tryParse(xf.getAttribute('numFmtId') ?? '') ?? 0;
          var format = formats[id] ?? '';
          format = format
              .replaceAll(RegExp(r'"[^"]*"|\\.|\[[^\]]*\]'), '')
              .toLowerCase();
          _dateStyles.add(
            (id >= 14 && id <= 22) ||
                [45, 46, 47].contains(id) ||
                RegExp('[ydhs]').hasMatch(format),
          );
        }
      }
    }
  }
  late final Map<String, ArchiveFile> _files;
  final sheets = <String, String>{};
  List<String> _strings = [];
  final _dateStyles = <bool>[];
  bool date1904 = false;
  String _read(String path) => utf8.decode(_files[path]!.content as List<int>);
  String? _optional(String path) =>
      _files.containsKey(path) ? _read(path) : null;

  /// Yields after each 250 stored rows, including styled but empty rows. The
  /// async import driver uses these boundaries to service browser UI events.
  Iterable<void> readSheet(String path, SparseSheet sheet) sync* {
    var rowNumber = 0, column = -1, style = 0;
    var type = '', capture = '';
    var inCell = false;
    var cells = <int, String>{};
    var value = StringBuffer(),
        inline = StringBuffer(),
        formula = StringBuffer();
    void finishCell() {
      if (!inCell) return;
      var text = value.toString();
      if (type == 's') {
        final index = int.tryParse(text);
        text = index != null && index >= 0 && index < _strings.length
            ? _strings[index]
            : '';
      } else if (type == 'inlineStr') {
        text = inline.toString();
      } else if (type == 'b') {
        text = text == '1' ? 'true' : 'false';
      } else if (type.isEmpty || type == 'n') {
        final number = double.tryParse(text);
        if (number != null && number.isFinite) {
          if (style < _dateStyles.length && _dateStyles[style]) {
            final epoch = date1904
                ? DateTime.utc(1904, 1, 1)
                : DateTime.utc(1899, 12, number < 60 ? 31 : 30);
            final date = epoch.add(
              Duration(milliseconds: (number * 86400000).round()),
            );
            text = date.toIso8601String().replaceFirst(RegExp(r'Z$'), '');
            if (number == number.truncateToDouble()) {
              text = text.split('T').first;
            }
          } else {
            text = number == number.truncateToDouble()
                ? number.toInt().toString()
                : number.toString();
          }
        }
      }
      if (text.isEmpty && formula.isNotEmpty) {
        text = '=$formula';
        sheet.formulaCells++;
      }
      text = cleanCell(text);
      if (text.isNotEmpty && column >= 0) cells[column] = text;
      inCell = false;
      capture = '';
    }

    for (final event in parseEvents(
      _read(path),
      validateNesting: true,
      validateDocument: true,
    )) {
      if (event is XmlStartElementEvent) {
        String? attr(String name) =>
            event.attributes.where((a) => a.name == name).firstOrNull?.value;
        final tag = event.name.split(':').last;
        if (tag == 'dimension') sheet.declaredRange = attr('ref') ?? '';
        if (tag == 'mergeCell') sheet.merges.add(CellRange(attr('ref')!));
        if (tag == 'row') {
          rowNumber = int.tryParse(attr('r') ?? '') ?? rowNumber + 1;
          cells = {};
          column = -1;
          sheet.storedRows++;
        } else if (tag == 'c') {
          inCell = true;
          column = attr('r') == null ? column + 1 : columnIndex(attr('r')!);
          type = attr('t') ?? '';
          style = int.tryParse(attr('s') ?? '') ?? 0;
          value = StringBuffer();
          inline = StringBuffer();
          formula = StringBuffer();
          if (event.isSelfClosing) finishCell();
        } else if (inCell &&
            ['v', 't', 'f'].contains(tag) &&
            !event.isSelfClosing) {
          capture = tag;
        }
      } else if (event is XmlTextEvent && inCell) {
        if (capture == 'v') value.write(event.value);
        if (capture == 't') inline.write(event.value);
        if (capture == 'f') formula.write(event.value);
      } else if (event is XmlEndElementEvent) {
        final tag = event.name.split(':').last;
        if (tag == 'c') finishCell();
        if (['v', 't', 'f'].contains(tag)) capture = '';
        if (tag == 'row') {
          if (cells.isNotEmpty) sheet.rows.add(SparseRow(rowNumber, cells));
          if (sheet.storedRows % 250 == 0) yield null;
        }
      }
    }
  }
}
