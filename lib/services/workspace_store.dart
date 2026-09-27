import 'package:sembast/sembast.dart';

abstract class WorkspaceStore {
  Future<Map<String, Object?>?> read();
  Future<void> write(Map<String, Object?> value);
  Future<void> close();
}

/// One transactional workspace record: imports and their reviews cannot be
/// partially replaced. Revision checks prevent an older tab overwriting work.
class DatabaseWorkspaceStore implements WorkspaceStore {
  DatabaseWorkspaceStore(this.open);
  final Future<Database> Function() open;
  Future<Database>? _database;
  final _record = stringMapStoreFactory.store('workspace').record('current');
  int _revision = 0;
  Future<Database> get database => _database ??= _open();
  Future<Database> _open() async {
    try {
      return await open();
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  @override
  Future<Map<String, Object?>?> read() async {
    final record = await _record.get(await database);
    _revision = record?['revision'] as int? ?? 0;
    return record == null
        ? null
        : Map<String, Object?>.from(record['data'] as Map);
  }

  @override
  Future<void> write(Map<String, Object?> value) async {
    final db = await database;
    final next = await db.transaction((txn) async {
      final current = await _record.get(txn);
      if ((current?['revision'] as int? ?? 0) != _revision) {
        throw StateError(
          'Another tab has saved this workspace. Keep this tab open and use the tab with the latest saved work.',
        );
      }
      final revision = _revision + 1;
      await _record.put(txn, {'revision': revision, 'data': value});
      return revision;
    });
    _revision = next;
  }

  @override
  Future<void> close() async {
    final pending = _database;
    _database = null;
    if (pending != null) await (await pending).close();
  }
}
