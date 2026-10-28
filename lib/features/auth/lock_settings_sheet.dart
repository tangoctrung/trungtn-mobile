import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/ui.dart';
import 'lock_session.dart';

Future<void> showLockSettings(
  BuildContext context,
  LockSessionController session,
) async {
  final selection = await showModalBottomSheet<LockTimeout>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _LockSettingsSheet(session: session),
  );
  if (selection == null) return;
  final saved = await session.selectTimeout(selection);
  if (context.mounted && !saved) {
    showMessage(
      context,
      'Đã áp dụng trong phiên này. Chưa lưu được lựa chọn để dùng khi mở lại app.',
    );
  }
}

class _LockSettingsSheet extends StatelessWidget {
  const _LockSettingsSheet({required this.session});
  final LockSessionController session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expiresAt = session.expiresAt;
    final openedAt = session.authenticatedAt;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Thời gian khóa', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Tính từ lần mở khóa thành công gần nhất.',
              style: theme.textTheme.bodyMedium,
            ),
            if (openedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Đã mở khóa: ${DateFormat('HH:mm · dd/MM').format(openedAt.toLocal())}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (expiresAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Cần xác thực lại lúc ${DateFormat('HH:mm · dd/MM').format(expiresAt.toLocal())}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in LockTimeout.values)
                    ListTile(
                      key: ValueKey('lock-timeout-${option.name}'),
                      leading: Icon(
                        option == LockTimeout.immediately
                            ? Icons.lock_outline_rounded
                            : Icons.timer_outlined,
                      ),
                      title: Text(option.label),
                      trailing: session.timeout == option
                          ? const Icon(Icons.check_circle_rounded)
                          : const Icon(Icons.circle_outlined, size: 22),
                      onTap: () => Navigator.of(context).pop(option),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
