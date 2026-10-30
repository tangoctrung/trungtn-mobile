import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/ui.dart';
import '../discover/discover_controller.dart';
import '../discover/discover_widgets.dart';
import '../storage/item_viewer_screen.dart';
import '../storage/vault_actions.dart';
import '../storage/storage_screen.dart';
import '../storage/vault_models.dart';
import '../storage/vault_repository.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    required this.repository,
    required this.discover,
    required this.onStorage,
    required this.onDiscover,
    required this.onFolder,
  });
  final VaultRepository repository;
  final DiscoverController discover;
  final VoidCallback onStorage;
  final VoidCallback onDiscover;
  final ValueChanged<VaultFolder> onFolder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([repository, discover]),
    builder: (context, _) {
      final theme = Theme.of(context);
      final folders = repository.foldersIn(null).take(6).toList();
      final recent = repository.recentItems.take(2).toList();
      return RefreshIndicator(
        onRefresh: discover.refresh,
        child: ListView(
          key: const PageStorageKey('home-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('Không gian của bạn', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, dd/MM/yyyy', 'vi').format(DateTime.now()),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            WeatherCard(controller: discover),
            const SizedBox(height: 10),
            MarketOverview(controller: discover),
            SectionTitle(
              'Thư viện của bạn',
              action: 'Xem tất cả',
              onAction: onStorage,
            ),
            Text(
              repository.loading
                  ? 'Đang tải thư viện…'
                  : repository.error ??
                        '${repository.folders.length} thư mục · ${repository.items.length} nội dung · ${formatBytes(repository.totalBytes)}',
              style: theme.textTheme.bodySmall,
            ),
            if (folders.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(146),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: folders.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, index) => SizedBox(
                    width: 156,
                    child: FolderTile(
                      folder: folders[index],
                      repository: repository,
                      onMore: () => showFolderActions(
                        context,
                        repository,
                        folders[index],
                      ),
                      count:
                          repository.itemsIn(folders[index].id).length +
                          repository.foldersIn(folders[index].id).length,
                      onSelect: () {},
                      onOpen: () => onFolder(folders[index]),
                    ),
                  ),
                ),
              ),
            ] else if (!repository.loading && repository.error == null)
              EmptyState(
                icon: Icons.create_new_folder_outlined,
                title: 'Bắt đầu với một thư mục',
                message: 'Ghi chú, ảnh và tài liệu sẽ xuất hiện ở đây.',
                action: TextButton(
                  onPressed: onStorage,
                  child: const Text('Đến Lưu trữ'),
                ),
              ),
            if (recent.isNotEmpty) ...[
              const SectionTitle('Gần đây'),
              for (final item in recent)
                VaultItemTile(
                  item: item,
                  repository: repository,
                  folderName: repository.folder(item.folderId).name,
                  onTap: () => openVaultItem(context, repository, item),
                ),
            ],
            SectionTitle(
              'Dành cho bạn',
              action: 'Khám phá',
              onAction: onDiscover,
            ),
            if (discover.latestNews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  discover.domestic.loading || discover.world.loading
                      ? 'Đang tải dòng tin…'
                      : 'Chưa tải được tin tức. Kéo xuống để thử lại.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (final post in discover.latestNews.take(3))
              NewsPostCard(post: post),
          ],
        ),
      );
    },
  );
}
