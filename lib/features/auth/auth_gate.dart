import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/edge_back_gesture.dart';
import '../home/home_screen.dart';
import 'device_auth_service.dart';
import 'lock_session.dart';
import 'lock_session_scope.dart';

enum _AuthStatus { loading, locked, authenticating, authenticated, failed }

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authenticator,
    this.homeBuilder,
    this.sessionController,
  });

  final DeviceAuthenticator? authenticator;
  final Widget Function(VoidCallback onLock)? homeBuilder;
  final LockSessionController? sessionController;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  late final DeviceAuthenticator _authenticator;
  late final LockSessionController _session;
  _AuthStatus _status = _AuthStatus.loading;
  String? _error;
  bool _hasSession = false;
  bool _obscured = false;
  bool _foreground = true;
  final _sessionNavigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _authenticator = widget.authenticator ?? DeviceAuthService();
    _session = widget.sessionController ?? LockSessionController();
    _session.addListener(_onSessionChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initialize());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_onSessionChanged);
    if (widget.sessionController == null) _session.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _session.initialize();
    if (!mounted) return;
    if (_session.isUnlocked) {
      setState(() {
        _hasSession = true;
        _status = _AuthStatus.authenticated;
      });
    } else {
      setState(() => _status = _AuthStatus.locked);
      await _authenticate();
    }
  }

  void _onSessionChanged() {
    if (!mounted ||
        _status != _AuthStatus.authenticated ||
        _session.isUnlocked) {
      return;
    }
    _lockVisuals();
    if (_session.lockReason == SessionLockReason.expired && _foreground) {
      unawaited(_authenticate());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _obscured = true);
      _dismissRootOverlays();
      final mobile =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      // Mobile `hidden` is a transitional state. Revoke the session when
      // actually paused, rather than for temporary view/focus transitions.
      if (state == AppLifecycleState.paused || !mobile) {
        // Native authentication dialogs can also background the app.
        if (_status == _AuthStatus.authenticated) _session.onBackground();
      }
    } else if (state == AppLifecycleState.resumed) {
      _session.validate();
      setState(() => _obscured = false);
      if (_status == _AuthStatus.locked) unawaited(_authenticate());
    }
  }

  Future<void> _authenticate() async {
    if (_status == _AuthStatus.authenticating) return;
    setState(() {
      _status = _AuthStatus.authenticating;
      _error = null;
    });

    bool authenticated = false;
    String? errorMessage;
    try {
      authenticated = await _authenticator.authenticate();
      if (!authenticated) {
        errorMessage =
            'Xác thực không thành công. Ứng dụng vẫn đang được khóa.';
      }
    } on DeviceAuthFailure catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Không thể xác thực trên thiết bị này. Vui lòng thử lại.';
    }

    if (!mounted) return;
    if (authenticated) {
      await _session.authenticated();
      if (!mounted) return;
      authenticated = _session.isUnlocked;
    }
    setState(() {
      _status = authenticated ? _AuthStatus.authenticated : _AuthStatus.failed;
      if (authenticated) _hasSession = true;
      _error = errorMessage;
    });
  }

  Future<void> _exitApp() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await SystemNavigator.pop();
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ứng dụng vẫn đang khóa'),
        content: const Text(
          'Để thoát, hãy về màn hình chính hoặc đóng ứng dụng '
          'trong trình chuyển đổi ứng dụng của thiết bị.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _status == _AuthStatus.authenticated && !_obscured;
    return Stack(
      children: [
        if (_hasSession)
          Positioned.fill(
            child: NavigatorPopHandler<void>(
              enabled: unlocked,
              onPopWithResult: (_) =>
                  _sessionNavigator.currentState?.maybePop(),
              child: Offstage(
                offstage: !unlocked,
                child: TickerMode(
                  enabled: unlocked,
                  child: LockSessionScope(
                    controller: _session,
                    child: EdgeBackGesture(
                      onBack: () async {
                        // Respect folder navigation and unsaved editor guards.
                        await _sessionNavigator.currentState?.maybePop();
                      },
                      child: Navigator(
                        key: _sessionNavigator,
                        onGenerateRoute: (_) => MaterialPageRoute<void>(
                          builder: (_) =>
                              widget.homeBuilder?.call(_lock) ??
                              HomeScreen(onLock: _lock),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_status != _AuthStatus.authenticated)
          Positioned.fill(child: _buildLockScreen(context))
        else if (_obscured)
          const Positioned.fill(child: ColoredBox(color: Colors.white)),
      ],
    );
  }

  void _lock() {
    _session.lock();
  }

  void _lockVisuals() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _status = _AuthStatus.locked);
    _dismissRootOverlays();
  }

  void _dismissRootOverlays() {
    // Third-party editors can put dialogs on the app's root navigator.
    // Dismiss those overlays so they cannot sit above the authentication gate.
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
  }

  Widget _buildLockScreen(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isBusy =
        _status == _AuthStatus.authenticating || _status == _AuthStatus.loading;
    final failed = _status == _AuthStatus.failed;
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: colors.primary, size: 28),
                  const SizedBox(height: 12),
                  Text('TrungTN', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: failed
                              ? colors.errorContainer
                              : colors.primaryContainer,
                          child: Icon(
                            failed
                                ? Icons.lock_outline_rounded
                                : isIOS
                                ? Icons.face_retouching_natural
                                : Icons.fingerprint_rounded,
                            size: 40,
                            color: failed ? colors.error : colors.primary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          failed ? 'Xác thực thất bại' : 'Chào mừng trở lại',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isIOS
                              ? 'Dùng Face ID, Touch ID hoặc mật mã thiết bị '
                                    'để mở khóa ứng dụng.'
                              : 'Dùng vân tay hoặc mã khóa thiết bị '
                                    'để mở khóa ứng dụng.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 20),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: isBusy ? null : _authenticate,
                          icon: isBusy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.lock_open_rounded),
                          label: Text(
                            isBusy
                                ? 'Đang xác thực…'
                                : failed
                                ? 'Thử lại'
                                : 'Mở khóa',
                          ),
                        ),
                        if (failed) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              foregroundColor: colors.error,
                            ),
                            onPressed: _exitApp,
                            icon: const Icon(Icons.exit_to_app_rounded),
                            label: const Text('Thoát ứng dụng'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Mật mã và sinh trắc học được xác minh bởi thiết bị.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
