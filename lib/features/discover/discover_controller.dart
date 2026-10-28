import 'package:flutter/foundation.dart';

import 'discover_models.dart';
import 'discover_service.dart';

class DiscoverController extends ChangeNotifier {
  DiscoverController({DiscoverService? service})
    : _service = service ?? DiscoverService();
  final DiscoverService _service;
  final weather = FeedResource<WeatherInfo>();
  final gold = FeedResource<PriceBoard>();
  final fuel = FeedResource<PriceBoard>();
  final domestic = FeedResource<List<NewsPost>>();
  final world = FeedResource<List<NewsPost>>();
  WeatherCity city = WeatherCity.choices.first;
  bool _disposed = false;
  bool _refreshing = false;

  List<NewsPost> get latestNews => [...?domestic.data, ...?world.data]
    ..sort(
      (a, b) => (b.publishedAt ?? DateTime(1970)).compareTo(
        a.publishedAt ?? DateTime(1970),
      ),
    );

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _load<T>(
    FeedResource<T> resource,
    Future<T> Function() fetch,
  ) async {
    final request = ++resource.request;
    resource.loading = true;
    resource.error = null;
    _changed();
    try {
      final data = await fetch();
      if (resource.request != request || _disposed) return;
      resource.data = data;
      resource.fetchedAt = DateTime.now();
    } catch (_) {
      if (resource.request == request && !_disposed) {
        resource.error = resource.data == null
            ? 'Chưa tải được dữ liệu. Kéo xuống để thử lại.'
            : 'Chưa cập nhật được. Đang hiển thị dữ liệu đã tải trước đó.';
      }
    } finally {
      if (resource.request == request && !_disposed) {
        resource.loading = false;
        _changed();
      }
    }
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await Future.wait([
        _load(weather, () => _service.weather(city)),
        _load(gold, _service.gold),
        _load(fuel, _service.fuel),
        _load(domestic, () => _service.news(NewsCategory.domestic)),
        _load(world, () => _service.news(NewsCategory.world)),
      ]);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> changeCity(WeatherCity selected) async {
    city = selected;
    // Do not show the previous city's values under the new city's label.
    weather.data = null;
    await _load(weather, () => _service.weather(selected));
  }

  @override
  void dispose() {
    _disposed = true;
    _service.close();
    super.dispose();
  }
}
