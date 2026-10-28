import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo/features/auth/device_auth_service.dart';
import 'package:flutter_demo/features/auth/lock_session.dart';
import 'package:flutter_demo/features/discover/discover_controller.dart';
import 'package:flutter_demo/features/home/home_screen.dart';
import 'package:flutter_demo/features/storage/vault_repository.dart';
import 'package:flutter_demo/main.dart';

class _Authenticator implements DeviceAuthenticator {
  int calls = 0;
  Future<bool> Function() handler = () async => true;
  @override
  Future<bool> authenticate() {
    calls++;
    return handler();
  }
}

class _Harness {
  DateTime now = DateTime.utc(2026, 10, 28, 8);
  final store = MemoryLockSessionStore();
  final auth = _Authenticator();
  final repository = VaultRepository()..loading = false;
  final discover = DiscoverController();
  late LockSessionController session = LockSessionController(
    store: store,
    now: () => now,
  );
  bool disposed = false;

  Widget app() => MyApp(
    authenticator: auth,
    sessionController: session,
    homeBuilder: (onLock) =>
        HomeScreen(onLock: onLock, repository: repository, discover: discover),
  );
  void dispose() {
    if (disposed) return;
    disposed = true;
    session.dispose();
    repository.dispose();
    discover.dispose();
  }
}

Future<void> select(WidgetTester tester, LockTimeout option) async {
  await tester.tap(find.byTooltip('Khóa ứng dụng'));
  await tester.pumpAndSettle();
  final target = find.byKey(ValueKey('lock-timeout-${option.name}'));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void background(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void resume(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  testWidgets('Lock menu presents exactly the requested options', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Khóa ứng dụng'));
    await tester.pumpAndSettle();
    for (final label in [
      'Khóa luôn',
      '3 phút',
      '15 phút',
      '30 phút',
      '1 giờ',
      '3 giờ',
      '1 ngày',
      '7 ngày',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      find.text('Tính từ lần mở khóa thành công gần nhất.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    h.dispose();
  });

  testWidgets(
    'Returning within the window skips authentication; a foreground expiry prompts again',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await select(tester, LockTimeout.minutes3);
      h.now = h.now.add(const Duration(minutes: 2));
      background(tester);
      resume(tester);
      await tester.pumpAndSettle();
      expect(h.auth.calls, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
      final pending = Completer<bool>();
      h.auth.handler = () => pending.future;
      h.now = h.now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 3));
      await tester.pump();
      expect(h.auth.calls, 2);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Đang xác thực…'), findsOneWidget);
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(h.session.authenticatedAt, h.now);
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    },
  );

  testWidgets(
    'Resume checks the deadline even if the background timer never ran',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await select(tester, LockTimeout.minutes3);
      background(tester);
      h.now = h.now.add(const Duration(minutes: 4));
      final pending = Completer<bool>();
      h.auth.handler = () => pending.future;
      resume(tester);
      await tester.pump();
      expect(h.auth.calls, 2);
      expect(find.byType(HomeScreen), findsNothing);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Xác thực thất bại'), findsOneWidget);
      expect(h.store.value!['authenticatedAt'], isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    },
  );

  testWidgets(
    'Cold launch restores a valid timed grant and skips the native prompt',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await select(tester, LockTimeout.days7);
      await tester.pumpWidget(const SizedBox.shrink());
      h.session.dispose();
      h.now = h.now.add(const Duration(days: 1));
      h.session = LockSessionController(store: h.store, now: () => h.now);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      expect(h.auth.calls, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
      await select(tester, LockTimeout.immediately);
      expect(find.byType(HomeScreen), findsNothing);
      expect(h.store.value!['authenticatedAt'], isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    },
  );
}
