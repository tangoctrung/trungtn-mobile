import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo/features/auth/lock_session.dart';

class _UnavailableStore implements LockSessionStore {
  @override
  Future<Map<String, dynamic>?> read() async =>
      throw const FileSystemException('Unavailable');
  @override
  Future<void> write(Map<String, dynamic> value) async =>
      throw const FileSystemException('Unavailable');
}

void main() {
  late DateTime now;
  late MemoryLockSessionStore store;
  late LockSessionController session;

  setUp(() async {
    now = DateTime.utc(2026, 10, 28, 8);
    store = MemoryLockSessionStore();
    session = LockSessionController(store: store, now: () => now);
    await session.initialize();
  });
  tearDown(() => session.dispose());

  test(
    'Default policy locks on background and never restores an immediate grant',
    () async {
      await session.authenticated();
      expect(session.isUnlocked, isTrue);
      expect(store.value!['authenticatedAt'], isNull);
      session.onBackground();
      expect(session.isUnlocked, isFalse);
      expect(session.lockReason, SessionLockReason.background);
    },
  );

  test(
    'Duration is counted from device authentication, not option selection',
    () async {
      final unlockedAt = now;
      await session.authenticated();
      now = now.add(const Duration(minutes: 1));
      await session.selectTimeout(LockTimeout.minutes3);
      expect(session.expiresAt, unlockedAt.add(const Duration(minutes: 3)));
      now = unlockedAt.add(const Duration(minutes: 2, seconds: 59));
      session.onBackground();
      expect(session.isUnlocked, isTrue);
      now = unlockedAt.add(const Duration(minutes: 3));
      session.validate();
      expect(session.isUnlocked, isFalse);
      expect(session.lockReason, SessionLockReason.expired);
    },
  );

  test(
    'A shortened duration can expire immediately without resetting the clock',
    () async {
      await session.authenticated();
      await session.selectTimeout(LockTimeout.hour1);
      now = now.add(const Duration(minutes: 10));
      await session.selectTimeout(LockTimeout.minutes3);
      expect(session.isUnlocked, isFalse);
      expect(store.value!['authenticatedAt'], isNull);
    },
  );

  test(
    'A valid seven-day grant and its chosen option survive a cold launch',
    () async {
      await session.authenticated();
      await session.selectTimeout(LockTimeout.days7);
      now = now.add(const Duration(days: 6, hours: 23));
      final restored = LockSessionController(store: store, now: () => now);
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.timeout, LockTimeout.days7);
      expect(restored.isUnlocked, isTrue);
      now = now.add(const Duration(hours: 1));
      restored.validate();
      expect(restored.isUnlocked, isFalse);
    },
  );

  test(
    'Manual lock clears the persisted grant but keeps the timeout policy',
    () async {
      await session.authenticated();
      await session.selectTimeout(LockTimeout.minutes15);
      session.lock();
      final restored = LockSessionController(store: store, now: () => now);
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.timeout, LockTimeout.minutes15);
      expect(restored.isUnlocked, isFalse);
    },
  );

  test('Selecting lock now revokes authorization immediately', () async {
    await session.authenticated();
    await session.selectTimeout(LockTimeout.day1);
    await session.selectTimeout(LockTimeout.immediately);
    expect(session.isUnlocked, isFalse);
    expect(session.timeout, LockTimeout.immediately);
    expect(store.value!['authenticatedAt'], isNull);
  });

  test(
    'A backward clock invalidates the session instead of extending access',
    () async {
      await session.authenticated();
      await session.selectTimeout(LockTimeout.day1);
      now = now.subtract(const Duration(minutes: 1));
      session.validate();
      expect(session.isUnlocked, isFalse);
    },
  );

  test('Unknown options, invalid timestamps and expired grants cannot restore access', () async {
    for (final value in [
      {
        'version': 1,
        'timeout': 'forever',
        'authenticatedAt': now.toIso8601String(),
      },
      {'version': 1, 'timeout': 'minutes3', 'authenticatedAt': 'invalid'},
      {
        'version': 1,
        'timeout': 'minutes3',
        'authenticatedAt': now
            .subtract(const Duration(minutes: 3))
            .toIso8601String(),
      },
      {
        'version': 1,
        'timeout': 'minutes3',
        'authenticatedAt': now.add(const Duration(days: 1)).toIso8601String(),
      },
    ]) {
      final storage = MemoryLockSessionStore()..value = value;
      final restored = LockSessionController(store: storage, now: () => now);
      await restored.initialize();
      expect(restored.isUnlocked, isFalse);
      restored.dispose();
    }
  });

  test('Storage errors require authentication on restart; current timed grant still works', () async {
    final unavailable = LockSessionController(
      store: _UnavailableStore(),
      now: () => now,
    );
    addTearDown(unavailable.dispose);
    await unavailable.initialize();
    expect(unavailable.isUnlocked, isFalse);
    await unavailable.authenticated();
    expect(await unavailable.selectTimeout(LockTimeout.minutes3), isFalse);
    expect(unavailable.isUnlocked, isTrue);
  });

  test('File store serializes writes so a lock cannot be overwritten by an older grant', () async {
    final directory = await Directory.systemTemp.createTemp('trungtn-session-');
    addTearDown(() => directory.delete(recursive: true));
    final disk = FileLockSessionStore(directoryProvider: () async => directory);
    await Future.wait([
      disk.write({
        'version': 1,
        'timeout': 'minutes3',
        'authenticatedAt': now.toIso8601String(),
      }),
      disk.write({
        'version': 1,
        'timeout': 'minutes3',
        'authenticatedAt': null,
      }),
    ]);
    final restored = LockSessionController(store: disk, now: () => now);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.isUnlocked, isFalse);
    expect(restored.timeout, LockTimeout.minutes3);
  });
}
