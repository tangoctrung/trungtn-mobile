import 'package:flutter/material.dart';

import '../../shared/ui.dart';
import 'discover_controller.dart';
import 'discover_widgets.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.controller});
  final DiscoverController controller;
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  int _newsFilter = 0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final posts = _newsFilter == 1
          ? controller.domestic.data ?? []
          : _newsFilter == 2
          ? controller.world.data ?? []
          : controller.latestNews;
      final resources = _newsFilter == 1
          ? [controller.domestic]
          : _newsFilter == 2
          ? [controller.world]
          : [controller.domestic, controller.world];
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          key: const PageStorageKey('discover-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Nhịp sống hôm nay',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Thời tiết, thị trường và những câu chuyện mới.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            WeatherCard(controller: controller),
            const SectionTitle('Thị trường'),
            PriceBoardCard(
              title: 'Giá vàng',
              icon: Icons.diamond_outlined,
              resource: controller.gold,
              sourceUrl: Uri.parse('https://btmc.vn/'),
            ),
            const SizedBox(height: 14),
            PriceBoardCard(
              title: 'Giá xăng dầu',
              icon: Icons.local_gas_station_outlined,
              resource: controller.fuel,
              sourceUrl: Uri.parse('https://www.petrolimex.com.vn/'),
            ),
            const SectionTitle('Dòng tin'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (index, name) in [
                  'Tất cả',
                  'Trong nước',
                  'Thế giới',
                ].indexed)
                  ChoiceChip(
                    label: Text(name),
                    selected: _newsFilter == index,
                    labelStyle: TextStyle(
                      color: _newsFilter == index
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    onSelected: (_) => setState(() => _newsFilter = index),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (resources.any((resource) => resource.loading))
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
            for (final resource in resources.where(
              (resource) => resource.error != null,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  resource.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (posts.isEmpty &&
                resources.every((resource) => !resource.loading))
              const EmptyState(
                icon: Icons.newspaper_outlined,
                title: 'Chưa có bài viết',
                message: 'Kéo xuống để tải lại tin tức.',
              ),
            for (final post in posts) NewsPostCard(post: post),
          ],
        ),
      );
    },
  );
}
