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
      final indicator = find.byKey(const Key('tab-focus-indicator'));
      final initialPosition = tester.getTopLeft(indicator);
      final initialSize = tester.getSize(indicator);
      expect(initialSize.height, 52);
      expect(initialSize.width, closeTo((340 - 12 - 112) * 2 / 3, .01));
      await tester.tap(find.byKey(const Key('tab-storage')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final intermediate = tester.getTopLeft(indicator);
      await tester.pumpAndSettle();
      final destination = tester.getTopLeft(indicator);
      expect(intermediate.dx, greaterThan(initialPosition.dx));
      expect(intermediate.dx, lessThan(destination.dx));
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
}
