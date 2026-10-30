import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'vault_models.dart';
import 'vault_demo_data.dart';
import 'vault_database.dart';
import 'vault_storage_stats.dart';

class VaultRepository extends ChangeNotifier {
  VaultRepository({
    Future<Directory> Function()? directoryProvider,
    DatabaseFactory? databaseFactory,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory,
       _database = VaultDatabase(factory: databaseFactory);

  final Future<Directory> Function() _directoryProvider;
  final VaultDatabase _database;
  Directory? _directory;
  List<VaultFolder> _folders = [];
  List<VaultItem> _items = [];
  Future<void> _pending = Future.value();
  Future<void>? _loadingTask;
  bool _disposed = false;
  int _demoVersion = 0;
  bool loading = true;
  String? error;
  VaultStorageStats storageStats = const VaultStorageStats();

  List<VaultFolder> get folders => List.unmodifiable(_folders);
  List<VaultItem> get items => List.unmodifiable(_items);
  int get totalBytes => storageStats.totalBytes;
  int get contentBytes => _items.fold(0, (sum, item) => sum + item.size);
  List<VaultItem> get recentItems =>
      [..._items]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool seedDemo = false}) {
    if (_disposed) return Future.value();
    return _loadingTask ??= _load(seedDemo: seedDemo)
        .whenComplete(() => _loadingTask = null);
  }

  Future<void> _load({required bool seedDemo}) async {
    await _pending;
    loading = true;
    error = null;
    _changed();
    try {
      final base = await _directoryProvider();
      final directory = Directory(p.join(base.path, 'vault'));
      await directory.create(recursive: true);
      _directory = directory;
      await _database.open(directory);
      final snapshot = await _database.read(directory);
      _folders = snapshot.folders;
      _items = snapshot.items;
      _demoVersion = snapshot.demoVersion;
      if (seedDemo && _demoVersion < 2) {
        final demo = await installVaultDemo(directory, _folders, _items);
        _demoVersion = 2;
        await _commit(demo.folders, demo.items);
      }
      await _removeUnreferencedFiles();
      await _refreshStorageStats();
    } catch (_) {
      // Never replace unreadable data with an empty library.
      await _database.close();
      error = 'Không đọc được dữ liệu lưu trữ. Hãy thử tải lại.';
    } finally {
      loading = false;
      _changed();
    }
  }

  List<VaultFolder> foldersIn(String? parentId) =>
      _folders.where((folder) => folder.parentId == parentId).toList();
  List<VaultItem> itemsIn(String folderId) =>
      _items.where((item) => item.folderId == folderId).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  VaultFolder folder(String id) =>
      _folders.firstWhere((folder) => folder.id == id);

  String _id() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pending.then((_) async {
      if (_disposed || loading || error != null || _directory == null) {
        throw StateError('Kho lưu trữ chưa sẵn sàng.');
      }
      return operation();
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _commit(List<VaultFolder> folders, List<VaultItem> items) async {
    await _database.writeChanges(
      _folders,
      _items,
      folders,
      items,
      _demoVersion,
    );
    _folders = folders;
    _items = items;
    await _refreshStorageStats();
    _changed();
  }

  Future<void> _refreshStorageStats() async {
    try {
      storageStats = await VaultStorageStats.measure(_directory!);
    } on FileSystemException {
      // A filesystem scan must not undo a successful database commit.
    }
  }

  Future<void> refreshStorageStats() => _serialize(() async {
    await _refreshStorageStats();
    _changed();
  });

  /// Only delete owned copies that are no longer referenced in SQLite.
  /// Demo files can be shared by multiple items, so references are deduplicated.
  Future<void> _removeUnreferencedFiles() async {
    final referenced = {
      for (final item in _items)
        if (item.relativePath != null) p.normalize(item.relativePath!),
      for (final folder in _folders)
        if (folder.coverRelativePath != null)
          p.normalize(folder.coverRelativePath!),
    };
    for (final name in ['files', 'covers', 'demo']) {
      final directory = Directory(p.join(_directory!.path, name));
      if (!await directory.exists()) continue;
      await for (final file in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (file is! File) continue;
        final relative = p.relative(file.path, from: _directory!.path);
        if (referenced.contains(relative)) continue;
        try {
          await file.delete();
        } on FileSystemException {
          /* Retry on next load. */
        }
      }
    }
  }

  Future<void> _cleanup() async {
    try {
      await _removeUnreferencedFiles();
    } on FileSystemException {
      /* Retry on next load. */
    }
    await _refreshStorageStats();
    _changed();
  }

  Future<VaultFolder> renameFolder(String id, String name) =>
      _serialize(() async {
        final original = folder(id);
        final clean = name.trim();
        if (clean.isEmpty) {
          throw ArgumentError('Tên thư mục không được để trống.');
        }
        if (foldersIn(original.parentId).any(
          (f) => f.id != id && f.name.toLowerCase() == clean.toLowerCase(),
        )) {
          throw ArgumentError('Thư mục này đã tồn tại.');
        }
        final updated = original.withName(clean);
        await _commit(
          _folders.map((f) => f.id == id ? updated : f).toList(),
          _items,
        );
        return updated;
      });

  Future<VaultItem> renameItem(String id, String name) => _serialize(() async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Tên không được để trống.');
    final updated = _items.firstWhere((i) => i.id == id).withName(clean);
    await _commit(
      _folders,
      _items.map((i) => i.id == id ? updated : i).toList(),
    );
    return updated;
  });

  VaultDeletionPlan planDeletion({
    Iterable<String> folderIds = const [],
    Iterable<String> itemIds = const [],
  }) {
    final removed = folderIds.toSet();
    final removedItems = itemIds.toSet();
    // Validate the entire request before any mutation, including stale IDs.
    for (final id in removed) {
      folder(id);
    }
    final existingItems = _items.map((i) => i.id).toSet();
    if (!existingItems.containsAll(removedItems)) {
      throw StateError('Nội dung đã thay đổi. Hãy chọn lại.');
    }
    var previousCount = 0;
    while (previousCount != removed.length) {
      previousCount = removed.length;
      removed.addAll(
        _folders.where((f) => removed.contains(f.parentId)).map((f) => f.id),
      );
    }
    removedItems.addAll(
      _items.where((i) => removed.contains(i.folderId)).map((i) => i.id),
    );
    return VaultDeletionPlan(folderIds: removed, itemIds: removedItems);
  }

  Future<void> deleteMany({
    Iterable<String> folderIds = const [],
    Iterable<String> itemIds = const [],
  }) {
    final selectedFolders = folderIds.toSet();
    final selectedItems = itemIds.toSet();
    return _serialize(() async {
      final plan = planDeletion(
        folderIds: selectedFolders,
        itemIds: selectedItems,
      );
      if (plan.isEmpty) return;
      // One SQLite transaction for the whole selection; clean private files
      // only after it commits, retaining files still referenced elsewhere.
      await _commit(
        _folders.where((f) => !plan.folderIds.contains(f.id)).toList(),
        _items.where((i) => !plan.itemIds.contains(i.id)).toList(),
      );
      await _cleanup();
    });
  }

  Future<void> deleteItem(String id) => deleteMany(itemIds: [id]);
  Future<void> deleteFolder(String id) => deleteMany(folderIds: [id]);

  Future<VaultFolder> createFolder(String name, {String? parentId}) =>
      _serialize(() async {
        final clean = name.trim();
        if (clean.isEmpty) {
          throw ArgumentError('Tên thư mục không được để trống.');
        }
        if (parentId != null) folder(parentId);
        if (foldersIn(parentId)
            .any((f) => f.name.toLowerCase() == clean.toLowerCase())) {
          throw ArgumentError('Thư mục này đã tồn tại.');
        }
        final entry = VaultFolder(
          id: _id(),
          name: clean,
          parentId: parentId,
          createdAt: DateTime.now(),
        );
        await _commit([..._folders, entry], _items);
        return entry;
      });

  Future<VaultItem> saveNote({
    required String folderId,
    required String name,
    required String text,
    required bool richText,
    List<dynamic>? delta,
    String? id,
  }) => _serialize(() async {
    folder(folderId);
    final now = DateTime.now();
    final existing = id == null
        ? null
        : _items.firstWhere((item) => item.id == id);
    if (existing != null &&
        (!existing.isNote || existing.folderId != folderId)) {
      throw ArgumentError('Ghi chú không hợp lệ.');
    }
    final entry = VaultItem(
      id: id ?? _id(),
      folderId: folderId,
      name: name.trim().isEmpty ? 'Ghi chú không tiêu đề' : name.trim(),
      type: richText ? VaultItemType.richText : VaultItemType.text,
      text: text,
      delta: delta,
      size:
          utf8.encode(text).length +
          (delta == null ? 0 : utf8.encode(jsonEncode(delta)).length),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _commit(_folders, [
      ..._items.where((item) => item.id != entry.id),
      entry,
    ]);
    return entry;
  });

  Future<VaultFolder> setFolderCover({
    required String folderId,
    required File source,
    required String name,
  }) => _serialize(() async {
    final original = folder(folderId);
    final extension = p.extension(name).toLowerCase();
    if (![
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.heic',
      '.heif',
      '.bmp',
      '.avif',
    ].contains(extension)) {
      throw ArgumentError('Hãy chọn một hình ảnh.');
    }
    final relative = p.join('covers', '${_id()}$extension');
    final target = _resolveFile(relative);
    await target.parent.create(recursive: true);
    try {
      await source.copy(target.path);
      if (await target.length() == 0) {
        throw const FileSystemException('Empty image');
      }
      final updated = original.withCover(relative);
      await _commit(
        _folders
            .map((entry) => entry.id == folderId ? updated : entry)
            .toList(),
        _items,
      );
      await _removeOwnedCover(original.coverRelativePath);
      await _refreshStorageStats();
      _changed();
      return updated;
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  });

  Future<void> resetFolderCover(String folderId) => _serialize(() async {
    final original = folder(folderId);
    await _commit(
      _folders
          .map((entry) => entry.id == folderId ? entry.withCover(null) : entry)
          .toList(),
      _items,
    );
    await _removeOwnedCover(original.coverRelativePath);
    await _refreshStorageStats();
    _changed();
  });

  Future<void> _removeOwnedCover(String? relative) async {
    if (relative == null || !relative.startsWith('covers${p.separator}')) {
      return;
    }
    try {
      final old = _resolveFile(relative);
      if (await old.exists()) await old.delete();
    } catch (_) {
      // Cover cleanup must not turn a successful metadata update into a failure.
    }
  }

  File? folderCoverFile(VaultFolder folder) {
    if (folder.coverRelativePath != null) {
      return _resolveFile(folder.coverRelativePath!);
    }
    return null;
  }

  Future<VaultItem> importFile({
    required String folderId,
    required File source,
    required String name,
    String? replaceItemId,
  }) => _serialize(() async {
    folder(folderId);
    final original = replaceItemId == null
        ? null
        : _items.firstWhere((i) => i.id == replaceItemId);
    if (original != null &&
        (original.isNote || original.folderId != folderId)) {
      throw ArgumentError('Tệp không hợp lệ.');
    }
    final id = original?.id ?? _id();
    final extension = p
        .extension(name)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9.]'), '');
    final relativePath = p.join('files', '${_id()}$extension');
    final target = File(p.join(_directory!.path, relativePath));
    await target.parent.create(recursive: true);
    try {
      await source.copy(target.path);
      final type = switch (extension) {
        '.jpg' ||
        '.jpeg' ||
        '.png' ||
        '.gif' ||
        '.webp' ||
        '.heic' ||
        '.heif' ||
        '.avif' ||
        '.bmp' => VaultItemType.image,
        '.mp4' ||
        '.mov' ||
        '.m4v' ||
        '.mkv' ||
        '.webm' ||
        '.avi' => VaultItemType.video,
        _ => VaultItemType.file,
      };
      final now = DateTime.now();
      final entry = VaultItem(
        id: id,
        folderId: folderId,
        name: p.basename(name),
        type: type,
        relativePath: relativePath,
        size: await target.length(),
        createdAt: original?.createdAt ?? now,
        updatedAt: now,
      );
      await _commit(_folders, [..._items.where((i) => i.id != id), entry]);
      if (original != null) await _cleanup();
      return entry;
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  });

  File fileFor(VaultItem item) {
    final relative = item.relativePath;
    if (relative == null) throw StateError('Không tìm thấy tệp.');
    return _resolveFile(relative);
  }

  File _resolveFile(String relative) {
    if (_directory == null || p.isAbsolute(relative)) {
      throw StateError('Không tìm thấy tệp.');
    }
    final target = p.normalize(p.join(_directory!.path, relative));
    if (!p.isWithin(_directory!.path, target)) {
      throw StateError('Đường dẫn tệp không hợp lệ.');
    }
    return File(target);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close());
    super.dispose();
  }

  Future<void> close() async {
    await _loadingTask;
    await _pending;
    await _database.close();
  }
}
