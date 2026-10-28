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
      final theme = Theme.of(context);
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          key: const PageStorageKey('discover-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (index, name) in [
                    'Tất cả',
                    'Trong nước',
                    'Thế giới',
                  ].indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(name),
                        showCheckmark: false,
                        selected: _newsFilter == index,
                        labelStyle: TextStyle(
                          color: _newsFilter == index
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                        onSelected: (_) => setState(() => _newsFilter = index),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Nhịp sống hôm nay', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            WeatherCard(controller: controller),
            const SizedBox(height: 10),
            MarketOverview(controller: controller),
            const SectionTitle('Tin mới'),
            if (resources.any((resource) => resource.loading))
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            for (final resource in resources.where(
              (resource) => resource.error != null,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(resource.error!, style: theme.textTheme.bodySmall),
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
