import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LockTimeout {
  immediately('Khóa luôn', Duration.zero),
  minutes3('3 phút', Duration(minutes: 3)),
  minutes15('15 phút', Duration(minutes: 15)),
  minutes30('30 phút', Duration(minutes: 30)),
  hour1('1 giờ', Duration(hours: 1)),
  hours3('3 giờ', Duration(hours: 3)),
  day1('1 ngày', Duration(days: 1)),
  days7('7 ngày', Duration(days: 7));

  const LockTimeout(this.label, this.duration);
  final String label;
  final Duration duration;
}

enum SessionLockReason { manual, background, expired }

abstract interface class LockSessionStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> value);
}

class FileLockSessionStore implements LockSessionStore {
  FileLockSessionStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;
  Future<void> _pending = Future.value();

  Future<File> _file() async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File(p.join(directory.path, 'lock_session.json'));
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> value) {
    final encoded = jsonEncode(value);
    final result = _pending.then((_) async {
      final file = await _file();
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(encoded, flush: true);
      await temporary.rename(file.path);
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

class MemoryLockSessionStore implements LockSessionStore {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async =>
      value == null ? null : Map.of(value!);
  @override
  Future<void> write(Map<String, dynamic> value) async =>
      this.value = Map.of(value);
}

class LockSessionController extends ChangeNotifier {
  LockSessionController({LockSessionStore? store, DateTime Function()? now})
    : _store = store ?? FileLockSessionStore(),
      _now = now ?? DateTime.now;

  final LockSessionStore _store;
  final DateTime Function() _now;
  Future<void>? _initialization;
  Timer? _expiryTimer;
  LockTimeout _timeout = LockTimeout.immediately;
  DateTime? _authenticatedAt;
  bool _unlocked = false;
  bool _disposed = false;
  SessionLockReason? lockReason;

  LockTimeout get timeout => _timeout;
  DateTime? get authenticatedAt => _authenticatedAt;
  DateTime? get expiresAt =>
      _authenticatedAt == null || _timeout == LockTimeout.immediately
      ? null
      : _authenticatedAt!.add(_timeout.duration);
  DateTime get currentTime => _now().toUtc();
  bool get isUnlocked =>
      _unlocked && (_timeout == LockTimeout.immediately || _withinDeadline);
  bool get _withinDeadline {
    final start = _authenticatedAt;
    final end = expiresAt;
    final now = currentTime;
    return start != null &&
        end != null &&
        !now.isBefore(start) &&
        now.isBefore(end);
  }

  Future<void> initialize() => _initialization ??= _load();

  Future<void> _load() async {
    try {
      final value = await _store.read();
      if (_disposed || value == null) return;
      if (value['version'] != 1) throw const FormatException('Unknown session');
      _timeout = LockTimeout.values.byName(value['timeout'] as String);
      final stamp = value['authenticatedAt'] as String?;
      _authenticatedAt = stamp == null ? null : DateTime.parse(stamp).toUtc();
      _unlocked = _timeout != LockTimeout.immediately && _withinDeadline;
      if (!_unlocked) _authenticatedAt = null;
      _scheduleExpiry();
    } catch (_) {
      // Invalid or unreadable persisted state always requires device authentication.
      _timeout = LockTimeout.immediately;
      _authenticatedAt = null;
      _unlocked = false;
    }
  }

  Future<bool> authenticated() async {
    _authenticatedAt = currentTime;
    _unlocked = true;
    lockReason = null;
    _scheduleExpiry();
    _changed();
    return _persist();
  }

  Future<bool> selectTimeout(LockTimeout timeout) async {
    _timeout = timeout;
    if (timeout == LockTimeout.immediately) {
      _revoke(SessionLockReason.manual);
    } else if (!_unlocked || !_withinDeadline) {
      _revoke(SessionLockReason.expired);
    } else {
      _scheduleExpiry();
      _changed();
    }
    return _persist();
  }

  void validate() {
    if (_unlocked && _timeout != LockTimeout.immediately && !_withinDeadline) {
      _revoke(SessionLockReason.expired);
      unawaited(_persist());
    }
  }

  void onBackground() {
    if (_timeout == LockTimeout.immediately && _unlocked) {
      lock(reason: SessionLockReason.background);
    } else {
      validate();
    }
  }

  void lock({SessionLockReason reason = SessionLockReason.manual}) {
    _revoke(reason);
    unawaited(_persist());
  }

  void _revoke(SessionLockReason reason) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _unlocked = false;
    _authenticatedAt = null;
    lockReason = reason;
    _changed();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (!_unlocked || expiresAt == null || _disposed) return;
    final remaining = expiresAt!.difference(currentTime);
    if (remaining <= Duration.zero) {
      _revoke(SessionLockReason.expired);
    } else {
      _expiryTimer = Timer(remaining, () {
        _revoke(SessionLockReason.expired);
        unawaited(_persist());
      });
    }
  }

  Future<bool> _persist() async {
    final snapshot = <String, dynamic>{
      'version': 1,
      'timeout': _timeout.name,
      'authenticatedAt': _unlocked && _timeout != LockTimeout.immediately
          ? _authenticatedAt?.toIso8601String()
          : null,
    };
    try {
      await _store.write(snapshot);
      return true;
    } catch (_) {
      // An in-memory grant may still be used; a cold launch will authenticate again.
      return false;
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiryTimer?.cancel();
    super.dispose();
  }
}
