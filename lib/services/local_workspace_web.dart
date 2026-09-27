import 'package:sembast_web/sembast_web.dart';

import 'workspace_store.dart';

WorkspaceStore createWorkspaceStore() => DatabaseWorkspaceStore(
  () => databaseFactoryWeb.openDatabase('test_case_review_workspace'),
);
