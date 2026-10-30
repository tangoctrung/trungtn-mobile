import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/app_theme.dart';
import '../../shared/ui.dart';
import 'discover_controller.dart';
import 'discover_models.dart';
import 'news_article_screen.dart';
import 'weather_location.dart';

Future<void> openSource(BuildContext context, Uri uri) async {
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      showMessage(context, 'Không mở được liên kết. Hãy thử lại.');
    }
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Không mở được liên kết trên thiết bị này.');
    }
  }
}

class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key, required this.controller});
  final DiscoverController controller;

  @override
  Widget build(BuildContext context) {
    final resource = controller.weather;
    final weather = resource.data;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            weather?.city.name ??
                                controller.city?.name ??
                                'Vị trí hiện tại',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: PopupMenuButton<String>(
                            key: const Key('weather-location-menu'),
                            tooltip: 'Chọn vị trí thời tiết',
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.expand_more, size: 20),
                            onSelected: (value) {
                              if (value == 'current') {
                                controller.useCurrentLocation();
                              } else {
                                controller.changeCity(
                                  WeatherCity.choices[int.parse(value)],
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                key: Key('weather-current-location'),
                                value: 'current',
                                child: Row(
                                  children: [
                                    Icon(Icons.my_location_rounded, size: 20),
                                    SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        'Vị trí hiện tại',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              for (
                                var i = 0;
                                i < WeatherCity.choices.length;
                                i++
                              )
                                PopupMenuItem(
                                  value: '$i',
                                  child: Text(WeatherCity.choices[i].name),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      weather?.description ??
                          (resource.loading
                              ? controller.locating
                                    ? 'Đang xác định vị trí…'
                                    : 'Đang tải thời tiết…'
                              : 'Chưa có dữ liệu thời tiết'),
                    ),
                    if (weather != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Độ ẩm ${weather.humidity}% · Gió ${weather.windSpeed.round()} km/h',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (weather != null) ...[
                const SizedBox(width: 12),
                Icon(
                  weather.code >= 95
                      ? Icons.thunderstorm_outlined
                      : weather.code >= 51
                      ? Icons.grain
                      : weather.code >= 1
                      ? Icons.cloud_outlined
                      : Icons.wb_sunny_outlined,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  '${weather.temperature.round()}°',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w400,
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
          if (resource.loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  weather == null
                      ? 'Thời tiết hôm nay'
                      : 'Cảm giác ${weather.feelsLike.round()}° · ${formatDate(weather.observedAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () =>
                    openSource(context, Uri.parse('https://open-meteo.com/')),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Open-Meteo', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.open_in_new,
                        size: 12,
                        color: AppTheme.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (resource.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(resource.error!, style: theme.textTheme.bodySmall),
            ),
          if (resource.error != null && !resource.loading)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  key: const Key('weather-retry'),
                  onPressed: () => controller.usingDeviceLocation
                      ? controller.useCurrentLocation()
                      : controller.refreshWeather(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    controller.locationIssue == WeatherLocationIssue.denied
                        ? 'Cho phép vị trí'
                        : 'Thử lại',
                  ),
                ),
                if (controller.locationIssue ==
                        WeatherLocationIssue.deniedForever ||
                    controller.locationIssue ==
                        WeatherLocationIssue.serviceDisabled)
                  TextButton.icon(
                    key: const Key('weather-location-settings'),
                    onPressed: () async {
                      final opened = await controller
                          .openWeatherLocationSettings();
                      if (!opened && context.mounted) {
                        showMessage(
                          context,
                          'Chưa mở được cài đặt. Hãy mở phần Vị trí trong cài đặt thiết bị.',
                        );
                      }
                    },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Mở cài đặt'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class MarketOverview extends StatelessWidget {
  const MarketOverview({super.key, required this.controller});
  final DiscoverController controller;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _tile(
          context,
          'Giá vàng',
          Icons.diamond_outlined,
          controller.gold,
          Uri.parse('https://btmc.vn/'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _tile(
          context,
          'Giá xăng dầu',
          Icons.local_gas_station_outlined,
          controller.fuel,
          Uri.parse('https://www.petrolimex.com.vn/'),
        ),
      ),
    ],
  );

  Widget _tile(
    BuildContext context,
    String title,
    IconData icon,
    FeedResource<PriceBoard> resource,
    Uri source,
  ) {
    final theme = Theme.of(context);
    final board = resource.data;
    final row = board?.rows.first;
    return Material(
      color: AppTheme.soft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          useRootNavigator: false,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) => ListenableBuilder(
            listenable: controller,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: PriceBoardCard(
                title: title,
                icon: icon,
                resource: resource,
                sourceUrl: source,
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                row == null
                    ? (resource.loading ? 'Đang tải…' : 'Chưa có dữ liệu')
                    : '${formatMoney(row.second)} ${board!.unit}',
                maxLines: 2,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 3),
              Text(
                row?.name ?? 'Xem bảng giá',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PriceBoardCard extends StatelessWidget {
  const PriceBoardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.resource,
    required this.sourceUrl,
  });
  final String title;
  final IconData icon;
  final FeedResource<PriceBoard> resource;
  final Uri sourceUrl;

  @override
  Widget build(BuildContext context) {
    final board = resource.data;
    final theme = Theme.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              IconButton(
                tooltip: 'Xem nguồn $title',
                onPressed: () =>
                    openSource(context, board?.sourceUrl ?? sourceUrl),
                icon: const Icon(Icons.open_in_new, size: 20),
              ),
            ],
          ),
          if (resource.loading) const LinearProgressIndicator(minHeight: 2),
          if (board != null) ...[
            Text(
              '${board.source} · ${board.unit}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (final row in board.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _priceCell(
                            context,
                            board.firstLabel,
                            row.first,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _priceCell(
                            context,
                            board.secondLabel,
                            row.second,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Text(
              'Nguồn cập nhật: ${board.rows.first.updatedAt}',
              style: theme.textTheme.bodySmall,
            ),
            if (resource.fetchedAt != null)
              Text(
                'Lấy dữ liệu: ${formatDate(resource.fetchedAt!)}',
                style: theme.textTheme.bodySmall,
              ),
          ] else if (!resource.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Chưa có bảng giá. Bạn có thể xem tại nguồn.'),
            ),
          if (resource.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(resource.error!, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _priceCell(BuildContext context, String label, num value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.soft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoney(value),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    ),
  );
}

class NewsPostCard extends StatelessWidget {
  const NewsPostCard({super.key, required this.post});
  final NewsPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => openNewsArticle(context, post),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: post.imageUrl == null
                      ? const ColoredBox(
                          color: AppTheme.soft,
                          child: Center(
                            child: Icon(Icons.newspaper_outlined, size: 32),
                          ),
                        )
                      : Image.network(
                          post.imageUrl.toString(),
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                              ? child
                              : const ColoredBox(color: AppTheme.soft),
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: AppTheme.soft,
                            child: Center(
                              child: Icon(Icons.newspaper_outlined, size: 32),
                            ),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: AppTheme.soft,
                      child: Text(
                        'V',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'VnExpress · ${post.categoryName}',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (post.publishedAt != null)
                            Text(
                              formatDate(post.publishedAt!),
                              style: theme.textTheme.bodySmall,
                            ),
                          if (post.summary.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                post.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 2),
                      child: Icon(Icons.chevron_right_rounded, size: 22),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
