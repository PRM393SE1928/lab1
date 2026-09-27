import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../models/srs_section.dart';
import 'srs_parser.dart';
export 'srs_parser.dart' show SrsImportException, parseSrsBytes;

class SrsService {
  Future<XFile?> selectFile() => openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'SRS document (.docx)', extensions: ['docx']),
    ],
  );
  Future<SrsIndex> importFile(
    XFile file, {
    void Function(String)? onProgress,
  }) async {
    if (!file.name.toLowerCase().endsWith('.docx')) {
      throw const SrsImportException('Select a .docx SRS document.');
    }
    onProgress?.call('Reading SRS...');
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const SrsImportException('Could not read the selected SRS file.');
    }
    onProgress?.call('Parsing document...');
    await Future<void>.delayed(Duration.zero);
    final sections = await compute(parseSrsBytes, bytes);
    onProgress?.call('Building section index...');
    await Future<void>.delayed(Duration.zero);
    return SrsIndex(sections);
  }
}
