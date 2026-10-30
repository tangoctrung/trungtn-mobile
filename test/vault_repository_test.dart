import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:flutter_demo/features/storage/vault_models.dart';
import 'package:flutter_demo/features/storage/vault_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late VaultRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('trungtn-vault-test-');
    repository = VaultRepository(directoryProvider: () async => directory);
    await repository.load();
  });
  tearDown(() async {
    await repository.close();
    repository.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> legacyIndex(Object json) async {
    await repository.close();
    await File(p.join(directory.path, 'vault', 'vault.db')).delete();
    await File(p.join(directory.path, 'vault', 'index.json'))
        .writeAsString(json is String ? json : jsonEncode(json));
  }

  test(
    'Folders, nested folders and plain/rich notes survive a fresh repository',
    () async {
      final parent = await repository.createFolder('Cá nhân');
      final child = await repository.createFolder(
        'Ghi chú',
        parentId: parent.id,
      );
      await repository.saveNote(
        folderId: child.id,
        name: 'Văn bản',
        text: 'Xin chào 👋',
        richText: false,
      );
      final rich = await repository.saveNote(
        folderId: child.id,
        name: 'Có định dạng',
        text: 'Đậm\n',
        richText: true,
        delta: [
          {
            'insert': 'Đậm',
            'attributes': {'bold': true},
          },
          {'insert': '\n'},
        ],
      );
      final fresh = VaultRepository(directoryProvider: () async => directory);
      addTearDown(() async {
        await fresh.close();
        fresh.dispose();
      });
      await fresh.load();
      expect(fresh.error, isNull);
      expect(fresh.foldersIn(null).single.name, 'Cá nhân');
      expect(fresh.foldersIn(parent.id).single.id, child.id);
      expect(fresh.itemsIn(child.id), hasLength(2));
      final restored = fresh.items.firstWhere((item) => item.id == rich.id);
      expect(restored.type, VaultItemType.richText);
      expect(restored.delta!.first['attributes'], {'bold': true});
    },
  );

  test(
    'Editing replaces a note and preserves its identity and creation time',
    () async {
      final folder = await repository.createFolder('Notes');
      final note = await repository.saveNote(
        folderId: folder.id,
        name: 'A',
        text: 'Old',
        richText: false,
      );
      final updated = await repository.saveNote(
        folderId: folder.id,
        id: note.id,
        name: 'B',
        text: 'New',
        richText: false,
      );
      expect(repository.items.single.name, 'B');
      expect(updated.id, note.id);
      expect(updated.createdAt, note.createdAt);
      expect(updated.text, 'New');
    },
  );

  test(
    'Imported files use a durable independent copy and preserve bytes',
    () async {
      final folder = await repository.createFolder('Files');
      final source = File(p.join(directory.path, 'source.mp4'));
      await source.writeAsBytes([0, 1, 2, 128, 255]);
      final item = await repository.importFile(
        folderId: folder.id,
        source: source,
        name: 'Kỷ niệm.mp4',
      );
      await source.delete();
      expect(item.type, VaultItemType.video);
      expect(item.name, 'Kỷ niệm.mp4');
      expect(item.size, 5);
      expect(await repository.fileFor(item).readAsBytes(), [0, 1, 2, 128, 255]);
      expect(
        p.isWithin(
          p.join(directory.path, 'vault'),
          repository.fileFor(item).path,
        ),
        isTrue,
      );
    },
  );

  test('Concurrent writes retain both folders; duplicates and empty names are rejected', () async {
    await Future.wait([
      repository.createFolder('A'),
      repository.createFolder('B'),
    ]);
    expect(repository.folders, hasLength(2));
    await expectLater(repository.createFolder(' a '), throwsArgumentError);
    await expectLater(repository.createFolder('  '), throwsArgumentError);
    await repository.createFolder('C');
    expect(repository.folders, hasLength(3));
  });

  test(
    'Unreadable index is kept intact and cannot be silently overwritten',
    () async {
      await legacyIndex('{broken');
      final index = File(p.join(directory.path, 'vault', 'index.json'));
      await repository.load();
      expect(repository.error, isNotNull);
      await expectLater(repository.createFolder('New'), throwsStateError);
      expect(await index.readAsString(), '{broken');
    },
  );

  test('Failed file copy does not create a broken entry', () async {
    final folder = await repository.createFolder('Files');
    await expectLater(
      repository.importFile(
        folderId: folder.id,
        source: File(p.join(directory.path, 'missing')),
        name: 'Missing.pdf',
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(repository.items, isEmpty);
    await repository.load();
    expect(repository.items, isEmpty);
  });

  test('Metadata cannot resolve a file outside the vault', () async {
    final now = DateTime.now();
    final item = VaultItem(
      id: 'x',
      folderId: 'y',
      name: 'bad',
      type: VaultItemType.file,
      createdAt: now,
      updatedAt: now,
      relativePath: '../../outside.txt',
    );
    expect(() => repository.fileFor(item), throwsStateError);
  });
  test(
    'Demo folders contain all five content types and preserve later edits',
    () async {
      await repository.load(seedDemo: true);
      expect(repository.folders, hasLength(6));
      for (final folder in repository.folders) {
        expect(
          repository.itemsIn(folder.id).map((item) => item.type).toSet(),
          VaultItemType.values.toSet(),
        );
      }
      final note = repository.items.firstWhere((item) => item.isNote);
      await repository.saveNote(
        folderId: note.folderId,
        id: note.id,
        name: 'Ghi chú của tôi',
        text: 'Đã sửa',
        richText: false,
      );
      final ids = repository.items.map((item) => item.id).toList();
      final sampleFile = repository.items.firstWhere(
        (item) => item.type == VaultItemType.file,
      );
      expect(await repository.fileFor(sampleFile).exists(), isTrue);
      await repository.load(seedDemo: true);
      expect(repository.items.map((item) => item.id), unorderedEquals(ids));
      expect(
        repository.items.firstWhere((item) => item.id == note.id).text,
        'Đã sửa',
      );
    },
  );
  test(
    'Old sample folders receive media while real folders and notes stay intact',
    () async {
      final legacy = await repository.createFolder('Cá nhân');
      final original = await repository.saveNote(
        folderId: legacy.id,
        name: 'Ghi chú cũ',
        text: 'Đây là nội dung mẫu, bạn có thể chỉnh sửa.',
        richText: false,
      );
      final real = await repository.createFolder('Công việc');
      final personal = await repository.saveNote(
        folderId: real.id,
        name: 'Tài liệu của tôi',
        text: 'Nội dung đã lưu',
        richText: false,
      );
      await repository.load(seedDemo: true);
      expect(
        repository.itemsIn(legacy.id).map((item) => item.type).toSet(),
        VaultItemType.values.toSet(),
      );
      expect(
        repository.items.firstWhere((item) => item.id == original.id).text,
        original.text,
      );
      expect(repository.itemsIn(real.id).single.id, personal.id);
      expect(repository.itemsIn(real.id).single.text, 'Nội dung đã lưu');
      for (final item in repository.items.where((item) => !item.isNote)) {
        expect(await repository.fileFor(item).exists(), isTrue);
      }
    },
  );
  test(
    'Folder covers survive restart and are independent of the selected source',
    () async {
      final folder = await repository.createFolder('Ảnh bìa');
      final source = File(p.join(directory.path, 'chosen.jpg'));
      await File('assets/demo/owl.jpg').copy(source.path);
      final bytes = await source.readAsBytes();
      final updated = await repository.setFolderCover(
        folderId: folder.id,
        source: source,
        name: 'chosen.jpg',
      );
      final storedFile = repository.folderCoverFile(updated)!;
      await source.delete();
      expect(await storedFile.readAsBytes(), bytes);
      final fresh = VaultRepository(directoryProvider: () async => directory);
      addTearDown(() async {
        await fresh.close();
        fresh.dispose();
      });
      await fresh.load();
      expect(
        fresh.folder(folder.id).coverRelativePath,
        updated.coverRelativePath,
      );
      expect(
        await fresh.folderCoverFile(fresh.folder(folder.id))!.readAsBytes(),
        bytes,
      );
      expect(fresh.items, isEmpty);
    },
  );

  test('Replacing and resetting a cover preserves folder content', () async {
    final folder = await repository.createFolder('Cá nhân');
    final note = await repository.saveNote(
      folderId: folder.id,
      name: 'Ghi chú',
      text: 'Giữ lại',
      richText: false,
    );
    final source = File('assets/demo/owl.jpg');
    final first = await repository.setFolderCover(
      folderId: folder.id,
      source: source,
      name: 'first.jpg',
    );
    final firstFile = repository.folderCoverFile(first)!;
    final second = await repository.setFolderCover(
      folderId: folder.id,
      source: source,
      name: 'second.jpg',
    );
    expect(await firstFile.exists(), isFalse);
    final secondFile = repository.folderCoverFile(second)!;
    await repository.resetFolderCover(folder.id);
    expect(repository.folder(folder.id).coverRelativePath, isNull);
    expect(await secondFile.exists(), isFalse);
    expect(repository.itemsIn(folder.id).single.id, note.id);
    expect(repository.itemsIn(folder.id).single.text, 'Giữ lại');
  });

  test('Default folder cover stays a folder after adding images and resetting a chosen cover', () async {
    final folder = await repository.createFolder('Ảnh');
    final image = await repository.importFile(
      folderId: folder.id,
      source: File('assets/demo/owl.jpg'),
      name: 'Nội dung.jpg',
    );
    expect(repository.folderCoverFile(repository.folder(folder.id)), isNull);
    final custom = await repository.setFolderCover(
      folderId: folder.id,
      source: File('assets/demo/owl.jpg'),
      name: 'Ảnh đại diện.jpg',
    );
    final customFile = repository.folderCoverFile(custom)!;
    expect(await customFile.exists(), isTrue);
    await repository.resetFolderCover(folder.id);
    expect(repository.folderCoverFile(repository.folder(folder.id)), isNull);
    expect(await customFile.exists(), isFalse);
    expect(await repository.fileFor(image).exists(), isTrue);
    await repository.load();
    expect(repository.folderCoverFile(repository.folder(folder.id)), isNull);
    expect(repository.items.single.id, image.id);
  });

  test(
    'A failed cover import leaves the previous cover and metadata intact',
    () async {
      final folder = await repository.createFolder('Cá nhân');
      final updated = await repository.setFolderCover(
        folderId: folder.id,
        source: File('assets/demo/owl.jpg'),
        name: 'original.jpg',
      );
      final empty = File(p.join(directory.path, 'empty.jpg'));
      await empty.writeAsBytes([]);
      await expectLater(
        repository.setFolderCover(
          folderId: folder.id,
          source: empty,
          name: 'empty.jpg',
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        repository.folder(folder.id).coverRelativePath,
        updated.coverRelativePath,
      );
      expect(
        await repository
            .folderCoverFile(repository.folder(folder.id))!
            .exists(),
        isTrue,
      );
      await expectLater(
        repository.setFolderCover(
          folderId: folder.id,
          source: empty,
          name: 'text.txt',
        ),
        throwsArgumentError,
      );
    },
  );

  test('Folders in an older index without cover metadata still load', () async {
    final folder = await repository.createFolder('Cũ');
    final json = {
      'version': 1,
      'folders': [folder.toJson()],
      'items': [],
    };
    (json['folders'] as List).first.remove('coverRelativePath');
    await legacyIndex(json);
    await repository.load();
    expect(repository.error, isNull);
    expect(repository.folder(folder.id).coverRelativePath, isNull);
  });

  test('SQLite migration preserves notes, covers and files and never imports twice', () async {
    final parent = await repository.createFolder('Cũ');
    final child = await repository.createFolder('Con', parentId: parent.id);
    final note = await repository.saveNote(
      folderId: child.id,
      name: 'Tiếng Việt',
      text: 'Chào 👋',
      richText: true,
      delta: [
        {'insert': 'Chào 👋\n'},
      ],
    );
    final file = await repository.importFile(
      folderId: child.id,
      source: File('assets/demo/welcome.pdf'),
      name: 'Tài liệu.pdf',
    );
    await repository.setFolderCover(
      folderId: parent.id,
      source: File('assets/demo/owl.jpg'),
      name: 'cover.jpg',
    );
    final original = {
      'version': 1,
      'demoVersion': 2,
      'folders': repository.folders.map((f) => f.toJson()).toList(),
      'items': repository.items.map((i) => i.toJson()).toList(),
    };
    await legacyIndex(original);
    await repository.load();
    expect(repository.error, isNull);
    expect(
      repository.items.firstWhere((i) => i.id == note.id).delta,
      note.delta,
    );
    expect(await repository.fileFor(file).exists(), isTrue);
    expect(
      await repository.folderCoverFile(repository.folder(parent.id))!.exists(),
      isTrue,
    );
    final header = await File(p.join(directory.path, 'vault', 'vault.db'))
        .openRead(0, 16)
        .expand((bytes) => bytes)
        .toList();
    expect(utf8.decode(header), 'SQLite format 3\u0000');
    // Even an empty library is authoritative after migration, rather than
    // resurrecting deleted content from the untouched JSON backup.
    await repository.deleteFolder(parent.id);
    await repository.load();
    expect(repository.folders, isEmpty);
    expect(repository.items, isEmpty);
    expect(
      jsonDecode(
        await File(p.join(directory.path, 'vault', 'index.json'))
            .readAsString(),
      ),
      original,
    );
  });

  test(
    'A failed migration rolls back all rows and can be retried safely',
    () async {
      final parent = await repository.createFolder('Parent');
      final note = await repository.saveNote(
        folderId: parent.id,
        name: 'Note',
        text: 'Keep me',
        richText: false,
      );
      final valid = {
        'version': 1,
        'folders': [parent.toJson()],
        'items': [note.toJson()],
      };
      await legacyIndex({
        ...valid,
        'items': [
          {...note.toJson(), 'folderId': 'missing'},
        ],
      });
      await repository.load();
      expect(repository.error, isNotNull);
      await expectLater(
        repository.createFolder('Must not write'),
        throwsStateError,
      );
      await File(p.join(directory.path, 'vault', 'index.json'))
          .writeAsString(jsonEncode(valid));
      await repository.load();
      expect(repository.error, isNull);
      expect(repository.folders.single.id, parent.id);
      expect(repository.items.single.text, 'Keep me');
    },
  );

  test('Rename is persistent, preserves contents and rejects duplicate sibling names', () async {
    final first = await repository.createFolder('One');
    await repository.createFolder('Two');
    final nested = await repository.createFolder('Nested', parentId: first.id);
    final note = await repository.saveNote(
      folderId: nested.id,
      name: 'Before',
      text: 'Keep',
      richText: false,
    );
    await expectLater(
      repository.renameFolder(first.id, ' two '),
      throwsArgumentError,
    );
    await expectLater(
      repository.renameFolder(first.id, ' '),
      throwsArgumentError,
    );
    await repository.renameFolder(first.id, "Công việc '2026'");
    await repository.renameItem(note.id, 'After');
    await repository.load();
    expect(repository.folder(first.id).name, "Công việc '2026'");
    expect(repository.folder(nested.id).parentId, first.id);
    expect(repository.items.single.name, 'After');
    expect(repository.items.single.text, 'Keep');
    expect(repository.items.single.createdAt, note.createdAt);
  });

  test('Deleting a folder removes every descendant and owned file but preserves siblings', () async {
    final root = await repository.createFolder('Remove');
    final child = await repository.createFolder('Child', parentId: root.id);
    final grandchild = await repository.createFolder(
      'Grandchild',
      parentId: child.id,
    );
    final sibling = await repository.createFolder('Keep');
    final retained = await repository.saveNote(
      folderId: sibling.id,
      name: 'Keep',
      text: 'Keep',
      richText: false,
    );
    await repository.saveNote(
      folderId: child.id,
      name: 'Remove',
      text: 'Remove',
      richText: false,
    );
    final image = await repository.importFile(
      folderId: grandchild.id,
      source: File('assets/demo/owl.jpg'),
      name: 'Photo.jpg',
    );
    final cover = await repository.setFolderCover(
      folderId: root.id,
      source: File('assets/demo/owl.jpg'),
      name: 'Cover.jpg',
    );
    final coverFile = repository.folderCoverFile(cover)!;
    await repository.deleteFolder(root.id);
    expect(await repository.fileFor(image).exists(), isFalse);
    expect(await coverFile.exists(), isFalse);
    expect(repository.storageStats.fileBytes, 0);
    expect(repository.storageStats.coverBytes, 0);
    await repository.load();
    expect(repository.folders.single.id, sibling.id);
    expect(repository.items.single.id, retained.id);
  });

  test('Replacing an attachment preserves identity, cleans the old copy, and keeps data on failure', () async {
    final folder = await repository.createFolder('Files');
    final original = await repository.importFile(
      folderId: folder.id,
      source: File('assets/demo/owl.jpg'),
      name: 'Old.jpg',
    );
    final oldFile = repository.fileFor(original);
    await expectLater(
      repository.importFile(
        folderId: folder.id,
        source: File(p.join(directory.path, 'missing')),
        name: 'Missing.jpg',
        replaceItemId: original.id,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(repository.items.single.relativePath, original.relativePath);
    expect(await oldFile.exists(), isTrue);
    final updated = await repository.importFile(
      folderId: folder.id,
      source: File('assets/demo/welcome.pdf'),
      name: 'New.pdf',
      replaceItemId: original.id,
    );
    expect(updated.id, original.id);
    expect(updated.createdAt, original.createdAt);
    expect(updated.type, VaultItemType.file);
    expect(await oldFile.exists(), isFalse);
    await repository.load();
    expect(repository.items.single.name, 'New.pdf');
    expect(
      await repository.fileFor(repository.items.single).readAsBytes(),
      await File('assets/demo/welcome.pdf').readAsBytes(),
    );
  });

  test('Batch deletion expands descendants, deduplicates selection, and preserves unselected data', () async {
    final parent = await repository.createFolder('Parent');
    final child = await repository.createFolder('Child', parentId: parent.id);
    final another = await repository.createFolder('Another');
    final keep = await repository.createFolder('Keep');
    final childNote = await repository.saveNote(
      folderId: child.id,
      name: 'Inside',
      text: 'Inside',
      richText: false,
    );
    await repository.saveNote(
      folderId: another.id,
      name: 'Other',
      text: 'Other',
      richText: false,
    );
    final retained = await repository.saveNote(
      folderId: keep.id,
      name: 'Keep',
      text: 'Keep',
      richText: false,
    );
    final image = await repository.importFile(
      folderId: keep.id,
      source: File('assets/demo/owl.jpg'),
      name: 'Image.jpg',
    );
    final file = await repository.importFile(
      folderId: keep.id,
      source: File('assets/demo/welcome.pdf'),
      name: 'File.pdf',
    );
    final cover = await repository.setFolderCover(
      folderId: child.id,
      source: File('assets/demo/owl.jpg'),
      name: 'Cover.jpg',
    );
    final coverFile = repository.folderCoverFile(cover)!;
    final plan = repository.planDeletion(
      folderIds: [parent.id, child.id, another.id],
      itemIds: [childNote.id, image.id, file.id],
    );
    expect(plan.folderIds.length, 3);
    expect(plan.itemIds.length, 4);
    await repository.deleteMany(
      folderIds: [parent.id, child.id, another.id, parent.id],
      itemIds: [childNote.id, image.id, file.id],
    );
    expect(repository.folders.single.id, keep.id);
    expect(repository.items.single.id, retained.id);
    expect(await repository.fileFor(image).exists(), isFalse);
    expect(await repository.fileFor(file).exists(), isFalse);
    expect(await coverFile.exists(), isFalse);
    expect(repository.storageStats.fileBytes, 0);
    expect(repository.storageStats.coverBytes, 0);
    await repository.load();
    expect(repository.folders.single.id, keep.id);
    expect(repository.items.single.id, retained.id);
  });

  test('A rejected batch rolls back all SQLite rows and retains files for retry', () async {
    final folder = await repository.createFolder('Files');
    final first = await repository.importFile(
      folderId: folder.id,
      source: File('assets/demo/owl.jpg'),
      name: 'First.jpg',
    );
    final second = await repository.importFile(
      folderId: folder.id,
      source: File('assets/demo/welcome.pdf'),
      name: 'Second.pdf',
    );
    await expectLater(
      repository.deleteMany(itemIds: [first.id, 'stale-id']),
      throwsStateError,
    );
    expect(repository.items.length, 2);
    final db = await databaseFactory.openDatabase(
      p.join(directory.path, 'vault', 'vault.db'),
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      await db.execute(
        "CREATE TRIGGER reject_batch BEFORE DELETE ON items WHEN OLD.id = '${second.id}' BEGIN SELECT RAISE(ABORT, 'test rejection'); END",
      );
      await expectLater(
        repository.deleteMany(itemIds: [first.id, second.id]),
        throwsA(isA<DatabaseException>()),
      );
      expect((await db.query('items')).length, 2);
      expect(repository.items.length, 2);
      expect(await repository.fileFor(first).exists(), isTrue);
      expect(await repository.fileFor(second).exists(), isTrue);
      await db.execute('DROP TRIGGER reject_batch');
      await repository.deleteMany(itemIds: [first.id, second.id]);
      expect(repository.items, isEmpty);
      expect(await repository.fileFor(first).exists(), isFalse);
      expect(await repository.fileFor(second).exists(), isFalse);
    } finally {
      await db.close();
    }
  });

  test(
    'Batch deletion keeps shared media until the last reference is removed',
    () async {
      await repository.load(seedDemo: true);
      final images = repository.items
          .where((i) => i.type == VaultItemType.image)
          .toList();
      final shared = repository.fileFor(images.first);
      final originalBytes = repository.storageStats.fileBytes;
      await repository.deleteMany(itemIds: images.take(2).map((i) => i.id));
      expect(await shared.exists(), isTrue);
      expect(repository.storageStats.fileBytes, originalBytes);
      await repository.deleteMany(itemIds: images.skip(2).map((i) => i.id));
      expect(await shared.exists(), isFalse);
      expect(
        repository.storageStats.fileBytes,
        originalBytes - await File('assets/demo/owl.jpg').length(),
      );
      await repository.load();
      expect(
        repository.items.where((i) => i.type == VaultItemType.image),
        isEmpty,
      );
    },
  );

  test(
    'Storage usage matches real disk bytes and counts shared media only once',
    () async {
      await repository.load(seedDemo: true);
      final uniquePaths = repository.items
          .where((i) => !i.isNote)
          .map((i) => i.relativePath)
          .toSet();
      var mediaBytes = 0;
      for (final relative in uniquePaths) {
        mediaBytes += await File(p.join(directory.path, 'vault', relative!))
            .length();
      }
      expect(repository.storageStats.fileBytes, mediaBytes);
      expect(repository.storageStats.databaseBytes, greaterThan(0));
      var diskBytes = 0;
      await for (final entry in Directory(
        p.join(directory.path, 'vault'),
      ).list(recursive: true, followLinks: false)) {
        if (entry is File) diskBytes += await entry.length();
      }
      expect(repository.totalBytes, diskBytes);
      final images = repository.items
          .where((i) => i.type == VaultItemType.image)
          .toList();
      final sharedFile = repository.fileFor(images.first);
      await repository.deleteItem(images.first.id);
      expect(await sharedFile.exists(), isTrue);
      for (final image in images.skip(1)) {
        await repository.deleteItem(image.id);
      }
      expect(await sharedFile.exists(), isFalse);
      expect(
        repository.storageStats.fileBytes,
        mediaBytes - await File('assets/demo/owl.jpg').length(),
      );
    },
  );
}
