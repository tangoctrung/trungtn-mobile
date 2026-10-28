import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'vault_models.dart';
import 'vault_demo_data.dart';

class VaultRepository extends ChangeNotifier {
  VaultRepository({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;
  Directory? _directory;
  List<VaultFolder> _folders = [];
  List<VaultItem> _items = [];
  Future<void> _pending = Future.value();
  bool _disposed = false;
  int _demoVersion = 0;
  bool loading = true;
  String? error;

  List<VaultFolder> get folders => List.unmodifiable(_folders);
  List<VaultItem> get items => List.unmodifiable(_items);
  int get totalBytes => _items.fold(0, (sum, item) => sum + item.size);
  List<VaultItem> get recentItems =>
      [..._items]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool seedDemo = false}) async {
    loading = true;
    error = null;
    _changed();
    try {
      final base = await _directoryProvider();
      final directory = Directory(p.join(base.path, 'vault'));
      await directory.create(recursive: true);
      final index = File(p.join(directory.path, 'index.json'));
      final isNew = !await index.exists();
      if (!isNew) {
        final json =
            jsonDecode(await index.readAsString()) as Map<String, dynamic>;
        if (json['version'] != 1) {
          throw const FormatException('Unknown vault version');
        }
        _demoVersion = json['demoVersion'] as int? ?? 0;
        _folders = (json['folders'] as List)
            .map((e) => VaultFolder.fromJson(e as Map<String, dynamic>))
            .toList();
        _items = (json['items'] as List)
            .map((e) => VaultItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      _directory = directory;
      if (seedDemo && _demoVersion < 2) {
        final demo = await installVaultDemo(directory, _folders, _items);
        _demoVersion = 2;
        await _commit(demo.folders, demo.items);
      }
    } catch (_) {
      // Never replace an unreadable index with an empty library.
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
      if (loading || error != null || _directory == null) {
        throw StateError('Kho lưu trữ chưa sẵn sàng.');
      }
      return operation();
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _commit(List<VaultFolder> folders, List<VaultItem> items) async {
    final temporary = File(p.join(_directory!.path, 'index.json.tmp'));
    await temporary.writeAsString(
      jsonEncode({
        'version': 1,
        'demoVersion': _demoVersion,
        'folders': folders.map((folder) => folder.toJson()).toList(),
        'items': items.map((item) => item.toJson()).toList(),
      }),
      flush: true,
    );
    await temporary.rename(p.join(_directory!.path, 'index.json'));
    _folders = folders;
    _items = items;
    _changed();
  }

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
    final entry = VaultItem(
      id: id ?? _id(),
      folderId: folderId,
      name: name.trim().isEmpty ? 'Ghi chú không tiêu đề' : name.trim(),
      type: richText ? VaultItemType.richText : VaultItemType.text,
      text: text,
      delta: delta,
      size: utf8.encode(text).length,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _commit(_folders, [
      ..._items.where((item) => item.id != entry.id),
      entry,
    ]);
    return entry;
  });

  Future<VaultItem> importFile({
    required String folderId,
    required File source,
    required String name,
  }) => _serialize(() async {
    folder(folderId);
    final id = _id();
    final extension = p
        .extension(name)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9.]'), '');
    final relativePath = p.join('files', '$id$extension');
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
        createdAt: now,
        updatedAt: now,
      );
      await _commit(_folders, [..._items, entry]);
      return entry;
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  });

  File fileFor(VaultItem item) {
    final relative = item.relativePath;
    if (_directory == null || relative == null || p.isAbsolute(relative)) {
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
    super.dispose();
  }
}
