import 'package:flutter/material.dart';

import '../../shared/app_theme.dart';
import '../../shared/ui.dart';
import 'vault_models.dart';
import 'vault_repository.dart';

class StorageUsageCard extends StatelessWidget {
  const StorageUsageCard({super.key, required this.repository});
  final VaultRepository repository;

  Future<void> _showDetails(BuildContext context) async {
    await repository.refreshStorageStats();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          final stats = repository.storageStats;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dung lượng lưu trữ',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    formatBytes(stats.totalBytes),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 16),
                  for (final row in [
                    (
                      'Ảnh, video và tệp',
                      stats.fileBytes,
                      Icons.perm_media_outlined,
                    ),
                    (
                      'Ảnh đại diện thư mục',
                      stats.coverBytes,
                      Icons.folder_outlined,
                    ),
                    (
                      'Ghi chú & dữ liệu ứng dụng',
                      stats.databaseBytes,
                      Icons.notes_rounded,
                    ),
                    ('Dữ liệu khác', stats.otherBytes, Icons.more_horiz),
                  ])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(row.$3),
                      title: Text(row.$1),
                      trailing: Text(formatBytes(row.$2)),
                    ),
                  const Divider(),
                  Text(
                    'Nội dung đã lưu',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in VaultItemType.values)
                        Chip(
                          label: Text(
                            '${repository.items.where((i) => i.type == type).length} ${itemTypeLabel(type).toLowerCase()}',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tổng dung lượng gồm tệp, ảnh đại diện và dữ liệu ứng dụng. Tệp dùng chung được tính một lần.',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.soft,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      key: const Key('storage-usage'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showDetails(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.storage_rounded, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đã dùng ${formatBytes(repository.totalBytes)}',
                    key: const Key('storage-used-bytes'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${repository.folders.length} thư mục · ${repository.items.length} nội dung',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
