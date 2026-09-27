// Compile with dart compile js, then run with Node after setting
// globalThis.srsBase64 to the base64-encoded DOCX. This exercises Dart's JS
// backend without depending on Flutter's Chrome test-server CanvasKit setup.
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_application_2/services/srs_parser.dart';

@JS('srsBase64')
external String get srsBase64;

void main() {
  final timer = Stopwatch()..start();
  final sections = parseSrsBytes(base64Decode(srsBase64));
  // CLI diagnostic output.
  // ignore: avoid_print
  print(
    'SRS JavaScript: ${sections.length} sections in ${timer.elapsedMilliseconds} ms',
  );
}
