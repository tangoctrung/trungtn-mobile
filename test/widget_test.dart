import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo/features/auth/device_auth_service.dart';
import 'package:flutter_demo/features/home/home_screen.dart';
import 'package:flutter_demo/main.dart';
import 'package:flutter_demo/features/auth/lock_session.dart';
import 'package:flutter_demo/features/storage/vault_repository.dart';
import 'package:flutter_demo/features/discover/discover_controller.dart';

class FakeAuthenticator implements DeviceAuthenticator {
  FakeAuthenticator(this.handler);

  Future<bool> Function() handler;
  int calls = 0;

  @override
  Future<bool> authenticate() {
    calls++;
    return handler();
  }
}

void main() {
  late VaultRepository repository;
  late DiscoverController discover;
  late LockSessionController session;
  setUp(() {
    repository = VaultRepository()..loading = false;
    discover = DiscoverController();
    session = LockSessionController(store: MemoryLockSessionStore());
  });
  tearDown(() {
    repository.dispose();
    discover.dispose();
    session.dispose();
  });
  Widget testApp({required DeviceAuthenticator authenticator}) => MyApp(
    authenticator: authenticator,
    sessionController: session,
    homeBuilder: (onLock) =>
        HomeScreen(onLock: onLock, repository: repository, discover: discover),
  );
  testWidgets('Startup waits for authentication before showing home', (
    tester,
  ) async {
    final pending = Completer<bool>();
    final auth = FakeAuthenticator(() => pending.future);
    await tester.pumpWidget(testApp(authenticator: auth));
    await tester.pump();

    expect(auth.calls, 1);
    expect(find.byType(HomeScreen), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Không gian của bạn'), findsOneWidget);
  });

  testWidgets('Failure stays locked and retry can unlock', (tester) async {
    final auth = FakeAuthenticator(() async => false);
    await tester.pumpWidget(testApp(authenticator: auth));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Xác thực thất bại'), findsOneWidget);
    expect(find.text('Thoát ứng dụng'), findsOneWidget);

    auth.handler = () async => true;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(auth.calls, 2);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Cancellation or missing device credentials never opens home', (
    tester,
  ) async {
    final auth = FakeAuthenticator(() async {
      throw const DeviceAuthFailure('Thiết bị chưa có mã khóa màn hình.');
    });
    await tester.pumpWidget(testApp(authenticator: auth));
    await tester.pumpAndSettle();

    expect(find.text('Thiết bị chưa có mã khóa màn hình.'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Thoát ứng dụng'), findsOneWidget);
  });

  testWidgets('Unexpected plugin error stays locked', (tester) async {
    await tester.pumpWidget(
      testApp(
        authenticator: FakeAuthenticator(() async {
          throw MissingPluginException();
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android exit invokes the system navigator', (tester) async {
    final methods = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        methods.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      testApp(authenticator: FakeAuthenticator(() async => false)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thoát ứng dụng'));
    await tester.tap(find.text('Thoát ứng dụng'));
    await tester.pump();
    expect(methods, contains('SystemNavigator.pop'));
    expect(find.byType(HomeScreen), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS exit explains how to close and keeps home locked', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(authenticator: FakeAuthenticator(() async => false)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thoát ứng dụng'));
    await tester.tap(find.text('Thoát ứng dụng'));
    await tester.pumpAndSettle();
    expect(find.text('Ứng dụng vẫn đang khóa'), findsOneWidget);
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'Background locks home; prompt lifecycle does not start a duplicate',
    (tester) async {
      final auth = FakeAuthenticator(() async => true);
      await tester.pumpWidget(testApp(authenticator: auth));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      final pending = Completer<bool>();
      auth.handler = () => pending.future;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(HomeScreen), findsNothing);
      expect(auth.calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(auth.calls, 2);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsNothing);
    },
  );

  testWidgets('Manual lock removes home and requires another authentication', (
    tester,
  ) async {
    final auth = FakeAuthenticator(() async => true);
    await tester.pumpWidget(testApp(authenticator: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Khóa ứng dụng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khóa luôn'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(auth.calls, 1);
    await tester.tap(find.text('Mở khóa'));
    await tester.pumpAndSettle();
    expect(auth.calls, 2);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Late authentication after disposal is ignored', (tester) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      testApp(authenticator: FakeAuthenticator(() => pending.future)),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('A root dialog cannot remain above the lock screen', (
    tester,
  ) async {
    final auth = FakeAuthenticator(() async => true);
    await tester.pumpWidget(
      MyApp(
        authenticator: auth,
        sessionController: session,
        homeBuilder: (_) => Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    const AlertDialog(content: Text('Nội dung riêng tư')),
              ),
              child: const Text('Mở hộp thoại'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở hộp thoại'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung riêng tư'), findsOneWidget);
    final pending = Completer<bool>();
    auth.handler = () => pending.future;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Nội dung riêng tư'), findsNothing);
    expect(find.text('Mở hộp thoại'), findsNothing);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Xác thực thất bại'), findsOneWidget);
  });
}
