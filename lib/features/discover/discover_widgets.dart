import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/ui.dart';
import 'discover_controller.dart';
import 'discover_models.dart';

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
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(26),
      ),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    weather?.city.name ?? controller.city.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                PopupMenuButton<WeatherCity>(
                  tooltip: 'Đổi thành phố',
                  icon: const Icon(
                    Icons.expand_more_rounded,
                    color: Colors.white,
                  ),
                  onSelected: controller.changeCity,
                  itemBuilder: (_) => [
                    for (final city in WeatherCity.choices)
                      PopupMenuItem(value: city, child: Text(city.name)),
                  ],
                ),
              ],
            ),
            if (weather != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${weather.temperature.round()}°',
                          style: const TextStyle(
                            fontSize: 58,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          weather.description,
                          style: const TextStyle(fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    weather.code >= 95
                        ? Icons.thunderstorm_outlined
                        : weather.code >= 51
                        ? Icons.grain_rounded
                        : weather.code >= 1
                        ? Icons.cloud_outlined
                        : Icons.wb_sunny_outlined,
                    size: 68,
                    color: const Color(0xFFEEEEEE),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  Text('Cảm giác ${weather.feelsLike.round()}°'),
                  Text('Độ ẩm ${weather.humidity}%'),
                  Text('Gió ${weather.windSpeed.round()} km/h'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Dữ liệu thời tiết: ${formatDate(weather.observedAt)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFFBDBDBD)),
              ),
            ] else ...[
              const SizedBox(height: 16),
              if (resource.loading)
                const LinearProgressIndicator(
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                )
              else
                const Text('Chưa có dữ liệu thời tiết.'),
              const SizedBox(height: 12),
            ],
            if (resource.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  resource.error!,
                  style: const TextStyle(color: Color(0xFFEEEEEE)),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: colors.onPrimary),
                onPressed: () =>
                    openSource(context, Uri.parse('https://open-meteo.com/')),
                child: const Text(
                  'Open-Meteo ↗',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
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
    final colors = Theme.of(context).colorScheme;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Xem nguồn $title',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    openSource(context, board?.sourceUrl ?? sourceUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
              ),
            ],
          ),
          if (resource.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (board != null) ...[
            const SizedBox(height: 12),
            Text(
              '${board.source} · ${board.unit}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            for (final row in board.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _priceCell(
                            context,
                            board.firstLabel,
                            row.first,
                          ),
                        ),
                        const SizedBox(width: 10),
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
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            if (resource.fetchedAt != null)
              Text(
                'Lấy dữ liệu: ${formatDate(resource.fetchedAt!)}',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
          ] else if (!resource.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Chưa có bảng giá. Bạn có thể xem tại nguồn.'),
            ),
          if (resource.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                resource.error!,
                style: TextStyle(fontSize: 14, color: colors.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _priceCell(BuildContext context, String label, num value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(18),
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openSource(context, post.url),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.imageUrl != null)
                Image.network(
                  post.imageUrl.toString(),
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          height: 190,
                          child: Center(child: Icon(Icons.image_outlined)),
                        ),
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 100,
                    child: Center(
                      child: Icon(Icons.newspaper_rounded, size: 40),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            post.categoryName,
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'VnExpress',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        const Icon(Icons.north_east_rounded, size: 17),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post.title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700, height: 1.4),
                    ),
                    if (post.summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        post.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (post.publishedAt != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        formatDate(post.publishedAt!),
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
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
