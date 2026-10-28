import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'features/auth/auth_gate.dart';
import 'features/auth/device_auth_service.dart';
import 'features/auth/lock_session.dart';
import 'shared/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.authenticator,
    this.homeBuilder,
    this.sessionController,
  });

  final DeviceAuthenticator? authenticator;
  final Widget Function(VoidCallback onLock)? homeBuilder;
  final LockSessionController? sessionController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrungTN',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        FlutterQuillLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: AuthGate(
        authenticator: authenticator,
        homeBuilder: homeBuilder,
        sessionController: sessionController,
      ),
    );
  }
}
