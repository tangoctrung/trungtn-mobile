import 'package:flutter/foundation.dart';

import 'discover_models.dart';
import 'discover_service.dart';
import 'weather_location.dart';

class DiscoverController extends ChangeNotifier {
  DiscoverController({
    DiscoverService? service,
    WeatherLocationProvider? locationProvider,
  }) : _service = service ?? DiscoverService(),
       _location = locationProvider ?? DeviceWeatherLocation();
  final DiscoverService _service;
  final WeatherLocationProvider _location;
  final weather = FeedResource<WeatherInfo>();
  final gold = FeedResource<PriceBoard>();
  final fuel = FeedResource<PriceBoard>();
  final domestic = FeedResource<List<NewsPost>>();
  final world = FeedResource<List<NewsPost>>();
  WeatherCity? city;
  bool usingDeviceLocation = true;
  bool locating = false;
  WeatherLocationIssue? locationIssue;
  bool _requestedLocationPermission = false;
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
        refreshWeather(),
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
    usingDeviceLocation = false;
    city = selected;
    // Do not show the previous city's values under the new city's label.
    weather.data = null;
    await refreshWeather();
  }

  Future<void> useCurrentLocation() async {
    if (usingDeviceLocation && weather.loading) return;
    if (!usingDeviceLocation) weather.data = null;
    usingDeviceLocation = true;
    city = null;
    await refreshWeather(requestPermission: true);
  }

  Future<void> refreshWeather({bool requestPermission = false}) async {
    final request = ++weather.request;
    final deviceLocation = usingDeviceLocation;
    weather.loading = true;
    weather.error = null;
    locationIssue = null;
    locating = deviceLocation;
    _changed();
    try {
      late final WeatherCity target;
      if (deviceLocation) {
        final askPermission =
            requestPermission || !_requestedLocationPermission;
        _requestedLocationPermission = true;
        target = await _location.currentLocation(
          requestPermission: askPermission,
        );
        if (_disposed || request != weather.request) return;
        city = target;
        locating = false;
        _changed();
      } else {
        target = city!;
      }
      final result = await _service.weather(target);
      if (_disposed || request != weather.request) return;
      weather.data = result;
      weather.fetchedAt = DateTime.now();
    } catch (error) {
      if (_disposed || request != weather.request) return;
      if (error is WeatherLocationFailure) {
        locationIssue = error.issue;
        weather.error = error.message;
        if (weather.data != null) {
          weather.error =
              '${weather.error} Đang hiển thị dữ liệu đã tải trước đó.';
        }
      } else {
        weather.error = weather.data == null
            ? 'Chưa tải được thời tiết. Hãy thử lại.'
            : 'Chưa cập nhật được thời tiết. Đang hiển thị dữ liệu đã tải trước đó.';
      }
    } finally {
      if (!_disposed && request == weather.request) {
        locating = false;
        weather.loading = false;
        _changed();
      }
    }
  }

  Future<bool> openWeatherLocationSettings() async {
    try {
      return await _location.openSettings(
        locationServices: locationIssue == WeatherLocationIssue.serviceDisabled,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _service.close();
    super.dispose();
  }
}
