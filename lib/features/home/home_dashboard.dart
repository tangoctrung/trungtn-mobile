import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/ui.dart';
import '../discover/discover_controller.dart';
import '../discover/discover_widgets.dart';
import '../storage/item_viewer_screen.dart';
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
      final folders = repository.foldersIn(null).take(4).toList();
      final recent = repository.recentItems.take(4).toList();
      return RefreshIndicator(
        onRefresh: discover.refresh,
        child: ListView(
          key: const PageStorageKey('home-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              DateFormat('EEEE, dd/MM/yyyy', 'vi').format(DateTime.now()),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Không gian của bạn',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lưu điều quan trọng. Khám phá điều mới.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            WeatherCard(controller: discover),
            SectionTitle(
              'Lưu trữ cá nhân',
              action: 'Xem tất cả',
              onAction: onStorage,
            ),
            SurfaceCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 38,
                    color: Color(0xFF171717),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${repository.folders.length} thư mục · ${repository.items.length} nội dung',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          repository.loading
                              ? 'Đang tải thư viện…'
                              : repository.error ??
                                    '${formatBytes(repository.totalBytes)} đã lưu trên thiết bị',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (folders.isNotEmpty) ...[
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: MediaQuery.textScalerOf(context).scale(180),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: folders.length,
                itemBuilder: (_, index) => FolderTile(
                  folder: folders[index],
                  count:
                      repository.itemsIn(folders[index].id).length +
                      repository.foldersIn(folders[index].id).length,
                  onSelect: () {},
                  onOpen: () => onFolder(folders[index]),
                ),
              ),
            ] else if (!repository.loading && repository.error == null)
              EmptyState(
                icon: Icons.create_new_folder_outlined,
                title: 'Mọi thứ bắt đầu từ một thư mục',
                message: 'Ghi chú, ảnh và tài liệu của bạn sẽ xuất hiện ở đây.',
                action: TextButton(
                  onPressed: onStorage,
                  child: const Text('Đến Lưu trữ'),
                ),
              ),
            if (recent.isNotEmpty) ...[
              const SectionTitle('Gần đây'),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final item in recent)
                      VaultItemTile(
                        item: item,
                        folderName: repository.folder(item.folderId).name,
                        onTap: () => openVaultItem(context, repository, item),
                      ),
                  ],
                ),
              ),
            ],
            SectionTitle(
              'Thị trường hôm nay',
              action: 'Khám phá',
              onAction: onDiscover,
            ),
            PriceBoardCard(
              title: 'Giá vàng',
              icon: Icons.diamond_outlined,
              resource: discover.gold,
              sourceUrl: Uri.parse('https://btmc.vn/'),
            ),
            const SizedBox(height: 14),
            PriceBoardCard(
              title: 'Giá xăng dầu',
              icon: Icons.local_gas_station_outlined,
              resource: discover.fuel,
              sourceUrl: Uri.parse('https://www.petrolimex.com.vn/'),
            ),
            SectionTitle(
              'Có gì mới?',
              action: 'Xem tất cả',
              onAction: onDiscover,
            ),
            if (discover.latestNews.isEmpty)
              SurfaceCard(
                child: Text(
                  discover.domestic.loading || discover.world.loading
                      ? 'Đang tải dòng tin…'
                      : 'Chưa tải được tin tức. Kéo xuống để thử lại.',
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
