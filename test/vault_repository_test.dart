import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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
    repository.dispose();
    await directory.delete(recursive: true);
  });

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
      addTearDown(fresh.dispose);
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
      final index = File(p.join(directory.path, 'vault', 'index.json'));
      await index.writeAsString('{broken');
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
    final json = jsonDecode(
      await File(p.join(directory.path, 'vault', 'index.json')).readAsString(),
    );
    expect(json['items'], isEmpty);
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
      expect(repository.items.map((item) => item.id).toList(), ids);
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
}
