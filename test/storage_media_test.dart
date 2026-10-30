import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo/features/auth/device_auth_service.dart';
import 'package:flutter_demo/features/auth/lock_session.dart';
import 'package:flutter_demo/features/discover/discover_controller.dart';
import 'package:flutter_demo/features/home/home_screen.dart';
import 'package:flutter_demo/features/storage/vault_models.dart';
import 'package:flutter_demo/features/storage/vault_repository.dart';
import 'package:flutter_demo/main.dart';

class _Authenticated implements DeviceAuthenticator {
  @override
  Future<bool> authenticate() async => true;
}

void main() {
  late Directory directory;
  late VaultRepository repository;
  late VaultFolder folder;
  late DiscoverController discover;
  late LockSessionController session;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('trungtn-media-test-');
    repository = VaultRepository(directoryProvider: () async => directory);
    await repository.load();
    folder = await repository.createFolder('Ảnh & ghi chú');
    discover = DiscoverController();
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
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MyApp(
        authenticator: _Authenticated(),
        sessionController: session,
        homeBuilder: (onLock) => HomeScreen(
          onLock: onLock,
          repository: repository,
          discover: discover,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-storage')));
    await tester.pumpAndSettle();
    final tile = find.byKey(ValueKey('folder-${folder.id}'));
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<VaultItem> addImage(String name, {String? folderId}) =>
      repository.importFile(
        folderId: folderId ?? folder.id,
        source: File('assets/demo/owl.jpg'),
        name: name,
      );

  Future<void> cacheImages(WidgetTester tester) => tester.runAsync(() async {
    for (final item in repository.items.where(
      (i) => i.type == VaultItemType.image,
    )) {
      final file = repository.fileFor(item);
      if (!await file.exists()) continue;
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      PaintingBinding.instance.imageCache.putIfAbsent(
        FileImage(file),
        () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: frame.image)),
        ),
      );
      codec.dispose();
    }
  });

  Future<void> openImage(WidgetTester tester, VaultItem item) async {
    final card = find.byKey(ValueKey('content-card-${item.id}'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('folder-image-gallery')), findsOneWidget);
  }

  for (final richText in [false, true]) {
    testWidgets(
      'Copy card preserves full ${richText ? 'rich' : 'plain'} text without opening the editor',
      (tester) async {
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final fullText =
            '  Tiếng Việt 👋\n${List.filled(30, 'Nội dung đầy đủ không bị cắt.').join('\n')}\n  ';
        late VaultItem note;
        await tester.runAsync(() async {
          note = await repository.saveNote(
            folderId: folder.id,
            name: 'Văn bản dài',
            text: fullText,
            richText: richText,
            delta: richText
                ? [
                    {'insert': fullText},
                  ]
                : null,
          );
        });
        await mount(tester);
        expect(find.byKey(ValueKey('read-more-${note.id}')), findsOneWidget);
        final copy = find.byKey(ValueKey('copy-text-${note.id}'));
        await tester.ensureVisible(copy);
        await tester.tap(copy);
        await tester.pumpAndSettle();
        expect(copied, fullText);
        expect(find.text('Đã sao chép nội dung.'), findsOneWidget);
        expect(find.byKey(const Key('note-body')), findsNothing);
        expect(find.byKey(const Key('add-content')), findsOneWidget);
        expect(repository.items.single.text, fullText);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Image gallery starts on selected image, swipes within its folder and preserves edge Back',
    (tester) async {
      await tester.runAsync(() async {
        await addImage('Ảnh 1.jpg');
        await addImage('Ảnh 2.jpg');
        await addImage('Ảnh 3.jpg');
        final otherFolder = await repository.createFolder('Thư mục khác');
        await addImage('Không thuộc album.jpg', folderId: otherFolder.id);
        await repository.saveNote(
          folderId: folder.id,
          name: 'Bỏ qua text',
          text: 'Text',
          richText: false,
        );
        await repository.importFile(
          folderId: folder.id,
          source: File('assets/demo/welcome.pdf'),
          name: 'Bỏ qua file.pdf',
        );
      });
      final images = repository
          .itemsIn(folder.id)
          .where((i) => i.type == VaultItemType.image)
          .toList();
      await cacheImages(tester);
      await mount(tester);
      await openImage(tester, images[1]);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('gallery-image-name'))).data,
        images[1].name,
      );
      final gallery = find.byKey(const Key('folder-image-gallery'));
      await tester.fling(gallery, const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('gallery-image-name'))).data,
        images[2].name,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('gallery-next')))
            .onPressed,
        isNull,
      );
      await tester.fling(gallery, const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      await tester.fling(gallery, const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.fling(gallery, const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('gallery-previous')))
            .onPressed,
        isNull,
      );
      await tester.fling(gallery, const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('gallery-next')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      double imageScale() => tester
          .widgetList<Transform>(
            find.descendant(of: gallery, matching: find.byType(Transform)),
          )
          .map((w) => w.transform.getMaxScaleOnAxis())
          .fold(0.0, (a, b) => a > b ? a : b);
      final beforeZoom = imageScale();
      await tester.tap(gallery);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(gallery);
      await tester.pumpAndSettle();
      expect(imageScale(), greaterThan(beforeZoom));
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.dragFrom(const Offset(5, 300), const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(gallery, findsNothing);
      expect(find.byKey(const Key('folder-content-grid')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'A folder with one image stays on that image when swiping either way',
    (tester) async {
      late VaultItem image;
      await tester.runAsync(() async {
        image = await addImage('Ảnh duy nhất.jpg');
      });
      await cacheImages(tester);
      await mount(tester);
      await openImage(tester, image);
      final gallery = find.byKey(const Key('folder-image-gallery'));
      await tester.fling(gallery, const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(gallery, const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.byTooltip('Ảnh tiếp theo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('An unreadable image does not prevent swiping to another image', (
    tester,
  ) async {
    late VaultItem missing;
    await tester.runAsync(() async {
      await addImage('Ảnh còn lại.jpg');
      missing = await addImage('Ảnh bị thiếu.jpg');
      await repository.fileFor(missing).delete();
    });
    await cacheImages(tester);
    await mount(tester);
    await openImage(tester, missing);
    expect(find.text('Chưa xem được ảnh'), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('folder-image-gallery')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Chưa xem được ảnh'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
