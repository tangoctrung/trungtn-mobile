import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo/features/auth/device_auth_service.dart';
import 'package:flutter_demo/features/discover/discover_controller.dart';
import 'package:flutter_demo/features/discover/discover_models.dart';
import 'package:flutter_demo/features/home/home_screen.dart';
import 'package:flutter_demo/features/storage/storage_screen.dart';
import 'package:flutter_demo/features/storage/vault_models.dart';
import 'package:flutter_demo/features/storage/vault_repository.dart';
import 'package:flutter_demo/main.dart';
import 'package:flutter_demo/features/auth/lock_session.dart';
import 'package:flutter_demo/shared/compact_bottom_bar.dart';
import 'package:flutter_demo/shared/app_theme.dart';
import 'package:flutter_demo/features/storage/vault_item_card.dart';

class _Authenticated implements DeviceAuthenticator {
  Future<bool> Function()? handler;
  @override
  Future<bool> authenticate() => handler?.call() ?? Future.value(true);
}

Future<void> waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Storage write did not finish');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory directory;
  late VaultRepository repository;
  late DiscoverController discover;
  late VaultFolder folder;
  late _Authenticated authenticator;
  late LockSessionController session;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('trungtn-ui-test-');
    repository = VaultRepository(directoryProvider: () async => directory);
    await repository.load();
    folder = await repository.createFolder('Cá nhân');
    discover = DiscoverController();
    authenticator = _Authenticated();
    session = LockSessionController(store: MemoryLockSessionStore());
  });
  tearDown(() async {
    await repository.close();
    repository.dispose();
    discover.dispose();
    session.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        authenticator: authenticator,
        sessionController: session,
        homeBuilder: (onLock) => HomeScreen(
          onLock: onLock,
          repository: repository,
          discover: discover,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openFolder(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('tab-storage')));
    await tester.pumpAndSettle();
    final tile = find.byKey(ValueKey('folder-${folder.id}'));
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-content')), findsOneWidget);
  }

  testWidgets(
    'Bottom navigation labels only the selected tab and retains storage state',
    (tester) async {
      await mount(tester);
      final navigation = tester.widget<CompactBottomBar>(
        find.byType(CompactBottomBar),
      );
      final bar = find.byType(CompactBottomBar);
      expect(
        find.descendant(of: bar, matching: find.text('Home')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('Lưu trữ')),
        findsNothing,
      );
      expect(
        find.descendant(of: bar, matching: find.text('Khám phá')),
        findsNothing,
      );
      expect(navigation.selectedIndex, 0);
      expect(
        tester.getSize(find.byKey(const Key('tab-focus-indicator'))).width,
        closeTo((340 - 12 - 112) * 2 / 3, .01),
      );
      expect(
        tester.getSize(find.byKey(const Key('tab-focus-indicator'))).height,
        52,
      );

      expect(
        tester.getSize(find.byKey(const Key('bottom-bar-surface'))).height,
        60,
      );
      expect(
        tester
            .widgetList<Icon>(
              find.descendant(of: bar, matching: find.byType(Icon)),
            )
            .every((icon) => icon.size == 30),
        isTrue,
      );
      await openFolder(tester);
      await tester.tap(find.byKey(const Key('tab-discover')));
      await tester.pumpAndSettle();
      expect(find.text('Nhịp sống hôm nay'), findsOneWidget);
      expect(
        tester
            .widget<CompactBottomBar>(find.byType(CompactBottomBar))
            .selectedIndex,
        2,
      );
      await tester.tap(find.byKey(const Key('tab-storage')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-content')), findsOneWidget);
    },
  );

  testWidgets(
    'Batch selection is an icon in the title row at root and inside a folder',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const Key('tab-storage')));
      await tester.pumpAndSettle();
      void checkHeader() {
        final select = find.byKey(const Key('start-selection'));
        expect(tester.widget<IconButton>(select).tooltip, 'Chọn nhiều');
        expect(find.text('Chọn'), findsNothing);
        expect(
          tester.getCenter(select).dy,
          closeTo(
            tester.getCenter(find.byKey(const Key('add-folder'))).dy,
            .01,
          ),
        );
      }

      checkHeader();
      await openFolder(tester);
      checkHeader();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A single folder tap selects; a double tap enters', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const Key('tab-storage')));
    await tester.pumpAndSettle();
    final tile = find.byKey(ValueKey('folder-${folder.id}'));
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('add-content')), findsNothing);
    expect(tester.widget<FolderTile>(find.byType(FolderTile)).selected, isTrue);
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-content')), findsOneWidget);
    await tester.tap(find.byTooltip('Thư mục cha'));
    await tester.pumpAndSettle();
    expect(find.text('Kho của bạn'), findsOneWidget);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('Left edge swipe navigates back safely on $platform', (
      tester,
    ) async {
      late VaultFolder child;
      await tester.runAsync(() async {
        child = await repository.createFolder(
          'Thư mục con',
          parentId: folder.id,
        );
      });
      await mount(tester);
      await openFolder(tester);
      final tile = find.byKey(ValueKey('folder-${child.id}'));
      await tester.tap(tile);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('Thư mục con'), findsOneWidget);

      // Content drags, short gestures, and vertical scrolling must not go back.
      await tester.dragFrom(const Offset(120, 320), const Offset(220, 0));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(5, 320), const Offset(12, 0));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(5, 320), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(find.text('Thư mục con'), findsOneWidget);

      await tester.dragFrom(const Offset(5, 320), const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('folder-${child.id}')), findsOneWidget);
      expect(find.byTooltip('Thư mục cha'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick-add-text')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('note-body')), 'Chưa lưu');
      await tester.pump();
      await tester.dragFrom(const Offset(5, 320), const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục viết'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('note-body')))
            .controller!
            .text,
        'Chưa lưu',
      );
      await tester.dragFrom(const Offset(5, 320), const Offset(240, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ thay đổi'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note-body')), findsNothing);
      expect(find.byKey(const Key('add-content')), findsOneWidget);

      // A clean editor can go back directly, including native iOS navigation.
      await tester.tap(find.byKey(const Key('quick-add-text')));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(5, 320), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note-body')), findsNothing);
      await tester.dragFrom(const Offset(5, 320), const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(find.text('Kho của bạn'), findsOneWidget);
      await tester.dragFrom(const Offset(5, 320), const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(find.text('Kho của bạn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('Create folder dialog writes it to persistent storage', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const Key('tab-storage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-folder')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('folder-name')), 'Công việc');
    await tester.runAsync(() async {
      await tester.tap(find.text('Tạo'));
      await waitUntil(() => repository.folders.length == 2);
    });
    await tester.pumpAndSettle();
    expect(find.text('Công việc'), findsOneWidget);
  });

  testWidgets(
    'Storage root hides recent content and shows actual local usage',
    (tester) async {
      await tester.runAsync(
        () => repository.saveNote(
          folderId: folder.id,
          name: 'Ghi chú riêng',
          text: 'Xin chào',
          richText: false,
        ),
      );
      await mount(tester);
      await tester.tap(find.byKey(const Key('tab-storage')));
      await tester.pumpAndSettle();
      expect(find.text('Gần đây'), findsNothing);
      expect(find.text('Ghi chú riêng'), findsNothing);
      final usage = tester.widget<Text>(
        find.byKey(const Key('storage-used-bytes')),
      );
      expect(usage.data, contains('Đã dùng'));
      expect(repository.totalBytes, greaterThan(0));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('storage-usage')));
        await repository.refreshStorageStats();
      });
      await tester.pumpAndSettle();
      expect(find.text('Dung lượng lưu trữ'), findsOneWidget);
      expect(find.text('Ghi chú & dữ liệu ứng dụng'), findsOneWidget);
      expect(find.text('1 văn bản'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Storage menus rename and delete persisted folders and content', (
    tester,
  ) async {
    late VaultItem note;
    await tester.runAsync(() async {
      note = await repository.saveNote(
        folderId: folder.id,
        name: 'Trước',
        text: 'Nội dung giữ nguyên',
        richText: false,
      );
    });
    await mount(tester);
    await tester.tap(find.byKey(const Key('tab-storage')));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(ValueKey('folder-${folder.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi tên thư mục'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('folder-name')), 'Đã đổi tên');
    await tester.runAsync(() async {
      await tester.tap(find.text('Lưu'));
      await repository.refreshStorageStats();
    });
    await tester.pumpAndSettle();
    expect(find.text('Đã đổi tên'), findsOneWidget);
    await openFolder(tester);
    await tester.tap(find.byKey(ValueKey('item-actions-${note.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi tên'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('item-name')), 'Sau');
    await tester.runAsync(() async {
      await tester.tap(find.text('Lưu'));
      await repository.refreshStorageStats();
    });
    await tester.pumpAndSettle();
    expect(find.text('Sau'), findsOneWidget);
    expect(repository.items.single.text, 'Nội dung giữ nguyên');
    await tester.tap(find.byKey(ValueKey('item-actions-${note.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa nội dung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(repository.items.single.id, note.id);
    await tester.tap(find.byKey(ValueKey('item-actions-${note.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa nội dung'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await repository.refreshStorageStats();
    });
    await tester.pumpAndSettle();
    expect(find.text('Thư mục đang trống'), findsOneWidget);
    await tester.tap(find.byTooltip('Thư mục cha'));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(ValueKey('folder-${folder.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa thư mục'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await repository.refreshStorageStats();
    });
    await tester.pumpAndSettle();
    expect(find.text('Bắt đầu với một thư mục'), findsOneWidget);
    await tester.runAsync(repository.load);
    await tester.pumpAndSettle();
    expect(repository.items, isEmpty);
    expect(repository.folders, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Batch folder selection supports cancel, select all and recursive deletion',
    (tester) async {
      late VaultFolder second;
      late VaultFolder keep;
      await tester.runAsync(() async {
        second = await repository.createFolder('Thư mục 2');
        keep = await repository.createFolder('Giữ lại');
        final child = await repository.createFolder('Con', parentId: folder.id);
        await repository.saveNote(
          folderId: child.id,
          name: 'Trong thư mục con',
          text: 'Text',
          richText: false,
        );
      });
      await mount(tester);
      await tester.tap(find.byKey(const Key('tab-storage')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-selection')));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 0'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('delete-selected')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(ValueKey('folder-${folder.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('folder-${second.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 2'), findsOneWidget);
      expect(repository.folders.length, 4);
      await tester.tap(find.byKey(const Key('delete-selected')));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 thư mục và 1 nội dung'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 2'), findsOneWidget);
      expect(repository.folders.length, 4);
      await tester.tap(find.byKey(const Key('select-all')));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('select-all')));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 0'), findsOneWidget);
      await tester.tap(find.byKey(const Key('select-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('folder-${keep.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-selected')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('confirm-delete')));
        await repository.refreshStorageStats();
      });
      await tester.pumpAndSettle();
      expect(repository.folders.single.id, keep.id);
      expect(repository.items, isEmpty);
      expect(find.byKey(const Key('start-selection')), findsOneWidget);
      expect(find.text('Đã chọn 2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Batch selection deletes mixed content and child folders while retaining unchecked items',
    (tester) async {
      late VaultFolder child;
      late VaultItem retained;
      await tester.runAsync(() async {
        child = await repository.createFolder('Con', parentId: folder.id);
        await repository.saveNote(
          folderId: child.id,
          name: 'Trong thư mục con',
          text: 'Text',
          richText: false,
        );
        await repository.saveNote(
          folderId: folder.id,
          name: 'Text',
          text: 'Text',
          richText: false,
        );
        await repository.saveNote(
          folderId: folder.id,
          name: 'Editor',
          text: 'Rich\n',
          richText: true,
          delta: [
            {'insert': 'Rich\n'},
          ],
        );
        await repository.importFile(
          folderId: folder.id,
          source: File('assets/demo/owl.jpg'),
          name: 'Photo.jpg',
        );
        await repository.importFile(
          folderId: folder.id,
          source: File('assets/demo/welcome.pdf'),
          name: 'File.pdf',
        );
        await repository.importFile(
          folderId: folder.id,
          source: File('assets/demo/butterfly.mp4'),
          name: 'Video.mp4',
        );
        retained = await repository.saveNote(
          folderId: folder.id,
          name: 'Giữ lại',
          text: 'Keep',
          richText: false,
        );
      });
      await mount(tester);
      await openFolder(tester);
      await tester.longPress(find.byKey(ValueKey('folder-${child.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn nhiều'));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('select-all')));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 7'), findsOneWidget);
      final card = find.byKey(ValueKey('content-card-${retained.id}'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(quill.QuillEditor), findsNothing);
      expect(find.byKey(const Key('note-body')), findsNothing);
      await tester.drag(
        find.byKey(const PageStorageKey('storage-list')),
        const Offset(0, 1500),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 6'), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete-selected')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('confirm-delete')));
        await repository.refreshStorageStats();
      });
      await tester.pumpAndSettle();
      expect(repository.folders.single.id, folder.id);
      expect(repository.items.single.id, retained.id);
      expect(repository.storageStats.fileBytes, 0);
      expect(find.byKey(const Key('start-selection')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Back exits batch selection first and the controls fit a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => repository.saveNote(
          folderId: folder.id,
          name: 'Note',
          text: 'Keep',
          richText: false,
        ),
      );
      await mount(tester);
      await tester.tap(find.byKey(const Key('tab-storage')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('select-all')));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 1'), findsOneWidget);
      await tester.dragFrom(const Offset(5, 300), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('start-selection')), findsOneWidget);
      expect(find.text('Kho của bạn'), findsOneWidget);
      await openFolder(tester);
      await tester.tap(find.byKey(const Key('start-selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('select-all')));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(5, 300), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-content')), findsOneWidget);
      expect(find.byKey(const Key('start-selection')), findsOneWidget);
      expect(repository.items.single.text, 'Keep');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Plain note can be saved, reopened and edited from its folder', (
    tester,
  ) async {
    await mount(tester);
    await openFolder(tester);
    await tester.tap(find.byKey(const Key('add-content')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Văn bản thường'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title')), 'Nhật ký');
    await tester.enterText(
      find.byKey(const Key('note-body')),
      'Nội dung đầu tiên',
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('save-note')));
      await waitUntil(() => repository.items.isNotEmpty);
    });
    await tester.pumpAndSettle();
    expect(find.text('Nhật ký'), findsOneWidget);
    await tester.tap(find.text('Nhật ký'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('note-body')))
          .controller!
          .text,
      'Nội dung đầu tiên',
    );
    await tester.enterText(find.byKey(const Key('note-body')), 'Đã sửa');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('save-note')));
      await waitUntil(() => repository.items.single.text == 'Đã sửa');
    });
    await tester.pumpAndSettle();
    expect(repository.items, hasLength(1));
    expect(repository.items.single.type, VaultItemType.text);
  });

  testWidgets('Rich editor saves formatting and restores the same document', (
    tester,
  ) async {
    await mount(tester);
    await openFolder(tester);
    await tester.tap(find.byKey(const Key('quick-add-richText')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title')), 'Kế hoạch');
    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    editor.controller.document.insert(0, 'Nội dung đậm');
    editor.controller.formatText(0, 12, quill.Attribute.bold);
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('save-note')));
      await waitUntil(() => repository.items.isNotEmpty);
    });
    await tester.pumpAndSettle();
    expect(repository.items.single.type, VaultItemType.richText);
    expect(repository.items.single.delta!.first['attributes'], {'bold': true});
    await tester.tap(find.text('Kế hoạch'));
    await tester.pumpAndSettle();
    final restored = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    expect(
      restored.controller.document.toDelta().toJson().first['attributes'],
      {'bold': true},
    );
  });

  testWidgets(
    'Selected formatting buttons keep contrasting icons and undo clears the dirty state',
    (tester) async {
      late VaultItem note;
      await tester.runAsync(() async {
        note = await repository.saveNote(
          folderId: folder.id,
          name: 'Định dạng',
          text: 'Văn bản\n',
          richText: true,
          delta: [
            {'insert': 'Văn bản\n'},
          ],
        );
      });
      await mount(tester);
      await openFolder(tester);
      await tester.tap(find.byKey(ValueKey('content-card-${note.id}')));
      await tester.pumpAndSettle();
      final editor = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );
      editor.controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 3),
        quill.ChangeSource.local,
      );
      await tester.pump();
      final bold = find.byIcon(Icons.format_bold);
      await tester.ensureVisible(bold);
      await tester.tap(bold);
      await tester.pumpAndSettle();
      expect(
        editor.controller.getSelectionStyle().attributes['bold']?.value,
        isTrue,
      );
      expect(IconTheme.of(tester.element(bold)).color, Colors.white);
      final boldButton = tester.widget<IconButton>(
        find.ancestor(of: bold, matching: find.byType(IconButton)).first,
      );
      expect(boldButton.style!.backgroundColor!.resolve({}), AppTheme.ink);
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.format_italic))).color,
        AppTheme.ink,
      );
      expect(
        TextSelectionTheme.of(tester.element(find.byType(quill.QuillEditor)))
            .selectionColor,
        const Color(0x330F0F0F),
      );
      editor.controller.undo();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi chưa lưu?'), findsNothing);
      expect(find.byType(quill.QuillEditor), findsNothing);
      expect(find.byKey(const Key('add-content')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Focus, selection and transient mobile lifecycle changes do not reauthenticate the rich editor',
    (tester) async {
      var authCalls = 0;
      authenticator.handler = () async {
        authCalls++;
        return true;
      };
      late VaultItem note;
      await tester.runAsync(() async {
        note = await repository.saveNote(
          folderId: folder.id,
          name: 'Chỉ xem',
          text: 'Giữ nội dung\n',
          richText: true,
          delta: [
            {'insert': 'Giữ nội dung\n'},
          ],
        );
      });
      await mount(tester);
      await openFolder(tester);
      await tester.tap(find.byKey(ValueKey('content-card-${note.id}')));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 3),
        quill.ChangeSource.local,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('note-title')));
      await tester.pump();
      final color = find.byIcon(Icons.color_lens);
      await tester.ensureVisible(color);
      await tester.tap(color);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(authCalls, 1);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(session.isUnlocked, isTrue);
      expect(find.text('Mở khóa'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(authCalls, 1);
      expect(find.byType(quill.QuillEditor), findsOneWidget);
      expect(controller.document.toPlainText(), 'Giữ nội dung\n');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(authCalls, 1);
      expect(find.text('Bỏ thay đổi chưa lưu?'), findsNothing);
      expect(find.byKey(const Key('add-content')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'Moving plain text and title selections does not mark a note as edited',
    (tester) async {
      late VaultItem note;
      await tester.runAsync(() async {
        note = await repository.saveNote(
          folderId: folder.id,
          name: 'Chỉ chọn chữ',
          text: 'Giữ nguyên',
          richText: false,
        );
      });
      await mount(tester);
      await openFolder(tester);
      await tester.tap(find.byKey(ValueKey('content-card-${note.id}')));
      await tester.pumpAndSettle();
      tester
          .widget<TextField>(find.byKey(const Key('note-title')))
          .controller!
          .selection = const TextSelection.collapsed(
        offset: 2,
      );
      tester
          .widget<TextField>(find.byKey(const Key('note-body')))
          .controller!
          .selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi chưa lưu?'), findsNothing);
      expect(find.byKey(const Key('add-content')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A real background transition still locks an unsaved rich editor and restores its document',
    (tester) async {
      await mount(tester);
      await openFolder(tester);
      await tester.tap(find.byKey(const Key('quick-add-richText')));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      controller.document.insert(0, 'Nội dung chưa lưu');
      controller.formatText(0, 8, quill.Attribute.bold);
      await tester.pump();
      final delta = controller.document.toDelta().toJson();
      final pending = Completer<bool>();
      authenticator.handler = () => pending.future;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(session.isUnlocked, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(quill.QuillEditor), findsNothing);
      expect(find.text('Đang xác thực…'), findsOneWidget);
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(quill.QuillEditor), findsOneWidget);
      expect(controller.document.toDelta().toJson(), delta);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục viết'));
      await tester.pumpAndSettle();
      expect(controller.document.toDelta().toJson(), delta);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Unsaved note stays behind the lock and is restored after authentication',
    (tester) async {
      await mount(tester);
      await openFolder(tester);
      await tester.tap(find.byKey(const Key('add-content')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Văn bản thường'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('note-body')),
        'Nội dung chưa lưu',
      );
      final pending = Completer<bool>();
      authenticator.handler = () => pending.future;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const Key('note-body')), findsNothing);
      expect(find.text('Đang xác thực…'), findsOneWidget);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note-body')), findsNothing);
      expect(find.text('Xác thực thất bại'), findsOneWidget);
      authenticator.handler = () async => true;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('note-body')))
            .controller!
            .text,
        'Nội dung chưa lưu',
      );
    },
  );
  testWidgets('All three tabs and add menu fit a small phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    discover.weather.data = WeatherInfo(
      city: WeatherCity.choices.first,
      temperature: 29,
      feelsLike: 32,
      humidity: 80,
      windSpeed: 10,
      code: 3,
      observedAt: DateTime(2026, 10, 28, 8),
    );
    discover.gold.data = PriceBoard(
      rows: const [
        PriceRow(
          name: 'Vàng miếng SJC',
          first: 10000000,
          second: 11000000,
          updatedAt: '28/10/2026 08:00',
        ),
      ],
      source: 'BTMC',
      sourceUrl: Uri.parse('https://btmc.vn/'),
      firstLabel: 'Mua vào',
      secondLabel: 'Bán ra',
      unit: 'đ / chỉ',
    );
    await mount(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('tab-discover')));
    await tester.pumpAndSettle();
    final list = find.byKey(const PageStorageKey('discover-list'));
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await openFolder(tester);
    await tester.tap(find.byKey(const Key('add-content')));
    await tester.pumpAndSettle();
    expect(find.text('Tệp khác'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Long press opens folder editing and cover choices from Home and Storage',
    (tester) async {
      await mount(tester);
      await tester.longPress(find.byKey(ValueKey('folder-${folder.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Đổi tên thư mục'), findsOneWidget);
      expect(find.text('Đổi ảnh đại diện'), findsOneWidget);
      expect(find.text('Xóa thư mục'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-storage')));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(ValueKey('folder-${folder.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đổi ảnh đại diện'));
      await tester.pumpAndSettle();
      expect(find.text('Ảnh đại diện thư mục'), findsOneWidget);
      expect(find.text('Chọn ảnh từ máy'), findsOneWidget);
      expect(find.byKey(const Key('add-content')), findsNothing);
    },
  );
  testWidgets(
    'Folder content uses two cards per row and long text opens in full',
    (tester) async {
      late VaultItem longNote;
      late VaultItem shortNote;
      final fullText = List.filled(
        30,
        'Đây là nội dung dài cần xem đầy đủ.',
      ).join(' ');
      await tester.runAsync(() async {
        longNote = await repository.saveNote(
          folderId: folder.id,
          name: 'Nội dung dài',
          text: fullText,
          richText: false,
        );
        shortNote = await repository.saveNote(
          folderId: folder.id,
          name: 'Ghi chú ngắn',
          text: 'Ngắn gọn.',
          richText: false,
        );
      });
      await mount(tester);
      await openFolder(tester);
      expect(find.byType(VaultItemCard), findsNWidgets(2));
      final first = tester.getRect(
        find.byKey(ValueKey('content-card-${longNote.id}')),
      );
      final second = tester.getRect(
        find.byKey(ValueKey('content-card-${shortNote.id}')),
      );
      expect(first.top, closeTo(second.top, .01));
      expect((first.left - second.left).abs(), greaterThan(first.width));
      expect(
        tester
            .widget<Text>(find.byKey(ValueKey('note-preview-${longNote.id}')))
            .maxLines,
        3,
      );
      expect(find.byKey(ValueKey('read-more-${shortNote.id}')), findsNothing);
      final more = find.byKey(ValueKey('read-more-${longNote.id}'));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('note-body')))
            .controller!
            .text,
        fullText,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
