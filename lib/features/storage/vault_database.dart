import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'vault_models.dart';

class VaultSnapshot {
  const VaultSnapshot(this.folders, this.items, this.demoVersion);
  final List<VaultFolder> folders;
  final List<VaultItem> items;
  final int demoVersion;
}

class VaultDatabase {
  VaultDatabase({this.factory});
  final DatabaseFactory? factory;
  Database? _db;

  Future<void> open(Directory directory) async {
    _db ??= await (factory ?? databaseFactory).openDatabase(
      p.join(directory.path, 'vault.db'),
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA auto_vacuum = FULL');
          await db.rawQuery('PRAGMA journal_mode = WAL');
        },
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute('''CREATE TABLE folders (
            id TEXT PRIMARY KEY, name TEXT NOT NULL,
            parentId TEXT REFERENCES folders(id) ON DELETE CASCADE,
            createdAt TEXT NOT NULL, coverRelativePath TEXT
          )''');
          await db.execute('''CREATE TABLE items (
            id TEXT PRIMARY KEY,
            folderId TEXT NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
            name TEXT NOT NULL, type TEXT NOT NULL, text TEXT NOT NULL,
            delta TEXT, relativePath TEXT, size INTEGER NOT NULL CHECK(size >= 0),
            createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
          )''');
          await db.execute('CREATE INDEX folders_parent ON folders(parentId)');
          await db.execute(
            'CREATE INDEX items_folder_updated ON items(folderId, updatedAt DESC)',
          );
        },
      ),
    );
  }

  /// Import the old JSON only once. The initialization marker and all rows
  /// commit together, so a failed migration can safely be retried.
  Future<VaultSnapshot> read(Directory directory) async {
    final db = _db!;
    final initialized = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['initialized'],
    );
    if (initialized.isEmpty) {
      final legacy = File(p.join(directory.path, 'index.json'));
      final folders = <VaultFolder>[];
      final items = <VaultItem>[];
      var demoVersion = 0;
      if (await legacy.exists()) {
        final json =
            jsonDecode(await legacy.readAsString()) as Map<String, dynamic>;
        if (json['version'] != 1) {
          throw const FormatException('Unknown vault version');
        }
        folders.addAll(
          (json['folders'] as List).map(
            (e) => VaultFolder.fromJson(e as Map<String, dynamic>),
          ),
        );
        items.addAll(
          (json['items'] as List).map(
            (e) => VaultItem.fromJson(e as Map<String, dynamic>),
          ),
        );
        demoVersion = json['demoVersion'] as int? ?? 0;
      }
      await writeChanges(const [], const [], folders, items, demoVersion);
      // Keep index.json untouched as a migration backup. SQLite is authoritative
      // once initialized, including when the last folder has been deleted.
    }
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['demoVersion'],
    );
    return VaultSnapshot(
      (await db.query(
        'folders',
        orderBy: 'rowid',
      )).map(VaultFolder.fromJson).toList(),
      (await db.query('items', orderBy: 'rowid'))
          .map(
            (row) => VaultItem.fromJson({
              ...row,
              'delta': row['delta'] == null
                  ? null
                  : jsonDecode(row['delta']! as String),
            }),
          )
          .toList(),
      rows.isEmpty ? 0 : int.parse(rows.single['value']! as String),
    );
  }

  Future<void> writeChanges(
    List<VaultFolder> oldFolders,
    List<VaultItem> oldItems,
    List<VaultFolder> folders,
    List<VaultItem> items,
    int demoVersion,
  ) async {
    final oldFolderMap = {for (final f in oldFolders) f.id: f};
    final oldItemMap = {for (final i in oldItems) i.id: i};
    final folderIds = folders.map((f) => f.id).toSet();
    final itemIds = items.map((i) => i.id).toSet();
    // Legacy JSON may list children before parents. Insert in tree order so
    // foreign keys fail inside the transaction body and roll back immediately.
    final orderedFolders = <VaultFolder>[];
    final remaining = {for (final folder in folders) folder.id: folder};
    final inserted = <String>{};
    while (remaining.isNotEmpty) {
      final ready = remaining.values
          .where((f) => f.parentId == null || inserted.contains(f.parentId))
          .toList();
      if (ready.isEmpty) throw const FormatException('Invalid folder tree');
      for (final folder in ready) {
        orderedFolders.add(folder);
        inserted.add(folder.id);
        remaining.remove(folder.id);
      }
    }
    await _db!.transaction((txn) async {
      final batch = txn.batch();
      for (final item in oldItems) {
        if (!itemIds.contains(item.id)) {
          batch.delete('items', where: 'id = ?', whereArgs: [item.id]);
        }
      }
      for (final folder in oldFolders.reversed) {
        if (!folderIds.contains(folder.id)) {
          batch.delete('folders', where: 'id = ?', whereArgs: [folder.id]);
        }
      }
      for (final folder in orderedFolders) {
        if (identical(folder, oldFolderMap[folder.id])) continue;
        if (oldFolderMap.containsKey(folder.id)) {
          batch.update(
            'folders',
            folder.toJson(),
            where: 'id = ?',
            whereArgs: [folder.id],
          );
        } else {
          batch.insert('folders', folder.toJson());
        }
      }
      for (final item in items) {
        if (identical(item, oldItemMap[item.id])) continue;
        final row = {
          ...item.toJson(),
          'delta': item.delta == null ? null : jsonEncode(item.delta),
        };
        if (oldItemMap.containsKey(item.id)) {
          batch.update('items', row, where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('items', row);
        }
      }
      batch.insert('settings', {
        'key': 'demoVersion',
        'value': '$demoVersion',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      batch.insert('settings', {
        'key': 'initialized',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    });
    try {
      await _db!.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } on DatabaseException {
      // Another reader may hold the WAL; the committed data is still durable.
    }
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }
}
