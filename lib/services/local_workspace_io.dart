import 'package:path/path.dart' as path;

import 'dart:io';

import 'package:sembast/sembast_io.dart';

import 'workspace_store.dart';

WorkspaceStore createWorkspaceStore() => DatabaseWorkspaceStore(() async {
  final base = Platform.isWindows
      ? Platform.environment['APPDATA']
      : Platform.environment['XDG_DATA_HOME'] ??
            (Platform.environment['HOME'] == null
                ? null
                : path.join(Platform.environment['HOME']!, '.local', 'share'));
  if (base == null || base.isEmpty) {
    throw StateError('The local application-data folder is unavailable.');
  }
  final directory = Directory(path.join(base, 'TestCaseReview'));
  await directory.create(recursive: true);
  return databaseFactoryIo.openDatabase(
    path.join(directory.path, 'review_workspace.db'),
  );
});
