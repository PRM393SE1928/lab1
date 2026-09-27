import 'dart:js_interop';

import 'package:sembast_web/sembast_web.dart';
import 'package:flutter_application_2/services/workspace_store.dart';

@JS('location.search')
external String get query;
@JS('document.body.textContent')
external set resultText(String value);

/// Run through browser_storage_probe.cjs. Uses a dedicated test database,
/// never the application's real workspace database.
Future<void> main() async {
  final args = Uri.splitQueryString(query.substring(1));
  final name = 'phase4_probe_${args['run']}';
  final store = DatabaseWorkspaceStore(
    () => databaseFactoryWeb.openDatabase(name),
  );
  try {
    final previous = await store.read();
    if (args['phase'] == 'write') {
      await store.write({
        'version': 1,
        'notes': 'Đăng nhập — persists after reload',
        'drafts': [
          {'id': 'TC-001', 'requirementId': 'srs_section_1'},
        ],
      });
    } else {
      if (previous?['notes'] != 'Đăng nhập — persists after reload' ||
          ((previous?['drafts'] as List?)?.single as Map?)?['requirementId'] !=
              'srs_section_1') {
        throw StateError('Workspace was not restored after navigation');
      }
    }
    await store.close();
    if (args['phase'] != 'write') await databaseFactoryWeb.deleteDatabase(name);
    resultText = 'PASS ${args['phase']}';
  } catch (error) {
    resultText = 'FAIL $error';
  }
}
