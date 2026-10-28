import 'package:flutter/widgets.dart';

import 'lock_session.dart';

class LockSessionScope extends InheritedNotifier<LockSessionController> {
  const LockSessionScope({
    super.key,
    required LockSessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static LockSessionController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LockSessionScope>()?.notifier;
}
