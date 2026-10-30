import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_demo/features/discover/discover_controller.dart';
import 'package:flutter_demo/features/discover/discover_models.dart';
import 'package:flutter_demo/features/discover/discover_service.dart';
import 'package:flutter_demo/features/discover/discover_widgets.dart';
import 'package:flutter_demo/features/discover/weather_location.dart';
import 'package:flutter_demo/shared/app_theme.dart';

Position position({double latitude = 12.34, double longitude = 105.67}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.utc(2026, 10, 29),
      accuracy: 100,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _Platform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requested = LocationPermission.whileInUse;
  int requests = 0, reads = 0;
  Future<Position> Function()? locate;
  LocationSettings? settings;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    reads++;
    settings = locationSettings;
    return locate?.call() ?? Future.value(position());
  }
}

class _Location implements WeatherLocationProvider {
  WeatherCity target = const WeatherCity('Vị trí hiện tại', 12.34, 105.67);
  WeatherLocationIssue? issue;
  Future<WeatherCity> Function()? handler;
  final permissions = <bool>[];
  bool? openedLocationServices;
  @override
  Future<WeatherCity> currentLocation({required bool requestPermission}) async {
    permissions.add(requestPermission);
    if (issue case final failure?) throw WeatherLocationFailure(failure);
    return handler?.call() ?? target;
  }

  @override
  Future<bool> openSettings({required bool locationServices}) async {
    openedLocationServices = locationServices;
    return true;
  }
}

http.Response forecast([double temperature = 28]) => http.Response(
  jsonEncode({
    'current': {
      'temperature_2m': temperature,
      'apparent_temperature': 30,
      'relative_humidity_2m': 70,
      'wind_speed_10m': 8,
      'weather_code': 2,
      'time': DateTime.utc(2026, 10, 29, 8).millisecondsSinceEpoch ~/ 1000,
    },
  }),
  200,
);

void main() {
  group('Native device location', () {
    late GeolocatorPlatform original;
    late _Platform platform;
    setUp(() {
      original = GeolocatorPlatform.instance;
      platform = _Platform();
      GeolocatorPlatform.instance = platform;
    });
    tearDown(() => GeolocatorPlatform.instance = original);

    test('Requests foreground permission, reads current coordinates and bounds the wait', () async {
      platform.permission = LocationPermission.denied;
      final result = await DeviceWeatherLocation().currentLocation(
        requestPermission: true,
      );
      expect(platform.requests, 1);
      expect(result.latitude, 12.34);
      expect(result.longitude, 105.67);
      expect(platform.settings!.accuracy, LocationAccuracy.medium);
      expect(platform.settings!.timeLimit, const Duration(seconds: 15));
    });

    for (final issue in [
      WeatherLocationIssue.denied,
      WeatherLocationIssue.deniedForever,
      WeatherLocationIssue.serviceDisabled,
    ]) {
      test(
        'Reports $issue without reading a position or repeatedly asking permission',
        () async {
          platform.enabled = issue != WeatherLocationIssue.serviceDisabled;
          platform.permission = issue == WeatherLocationIssue.deniedForever
              ? LocationPermission.deniedForever
              : LocationPermission.denied;
          await expectLater(
            DeviceWeatherLocation().currentLocation(requestPermission: false),
            throwsA(
              isA<WeatherLocationFailure>().having(
                (e) => e.issue,
                'issue',
                issue,
              ),
            ),
          );
          expect(platform.requests, 0);
          expect(platform.reads, 0);
        },
      );
    }

    test(
      'Coalesces concurrent native requests and reports GPS timeout',
      () async {
        final pending = Completer<Position>();
        platform.locate = () => pending.future;
        final service = DeviceWeatherLocation();
        final first = service.currentLocation(requestPermission: true);
        final second = service.currentLocation(requestPermission: true);
        pending.complete(position());
        await Future.wait([first, second]);
        expect(platform.reads, 1);
        platform.locate = () => Future.error(TimeoutException('GPS timeout'));
        await expectLater(
          service.currentLocation(requestPermission: false),
          throwsA(
            isA<WeatherLocationFailure>().having(
              (e) => e.issue,
              'issue',
              WeatherLocationIssue.timeout,
            ),
          ),
        );
      },
    );
  });

  test('Default weather uses fresh device coordinates and prompts once on automatic refresh', () async {
    final location = _Location();
    final queried = <String>[];
    final controller = DiscoverController(
      locationProvider: location,
      service: DiscoverService(
        client: MockClient((r) async {
          queried.add(r.url.queryParameters['latitude']!);
          expect(r.url.queryParameters['timeformat'], 'unixtime');
          return forecast();
        }),
      ),
    );
    addTearDown(controller.dispose);
    await controller.refreshWeather();
    expect(controller.usingDeviceLocation, isTrue);
    expect(controller.weather.data!.city.latitude, 12.34);
    expect(controller.weather.data!.observedAt, DateTime.utc(2026, 10, 29, 8));
    location.target = const WeatherCity('Vị trí hiện tại', 15, 108);
    await controller.refreshWeather();
    expect(queried, ['12.34', '15.0']);
    expect(location.permissions, [true, false]);
    expect(controller.weather.data!.city.latitude, 15);
  });

  test('Denied location does not silently load a fixed city and manual fallback works', () async {
    final location = _Location()..issue = WeatherLocationIssue.denied;
    var calls = 0;
    final controller = DiscoverController(
      locationProvider: location,
      service: DiscoverService(
        client: MockClient((_) async {
          calls++;
          return forecast();
        }),
      ),
    );
    addTearDown(controller.dispose);
    await controller.refreshWeather();
    expect(calls, 0);
    expect(controller.city, isNull);
    expect(controller.weather.data, isNull);
    expect(controller.locationIssue, WeatherLocationIssue.denied);
    await controller.changeCity(WeatherCity.choices[1]);
    expect(controller.weather.data!.city.name, 'Hà Nội');
    expect(controller.usingDeviceLocation, isFalse);
    expect(location.permissions.length, 1);
  });

  test('A late GPS result cannot replace a manually selected city', () async {
    final pending = Completer<WeatherCity>();
    final location = _Location()..handler = () => pending.future;
    var calls = 0;
    final controller = DiscoverController(
      locationProvider: location,
      service: DiscoverService(
        client: MockClient((_) async {
          calls++;
          return forecast();
        }),
      ),
    );
    addTearDown(controller.dispose);
    final gps = controller.refreshWeather();
    await controller.changeCity(WeatherCity.choices[1]);
    pending.complete(location.target);
    await gps;
    expect(calls, 1);
    expect(controller.weather.data!.city.name, 'Hà Nội');
    expect(controller.city!.name, 'Hà Nội');
  });

  test('Switching from an in-flight manual request to GPS ignores the old forecast', () async {
    final pending = Completer<http.Response>();
    final location = _Location();
    final controller = DiscoverController(
      locationProvider: location,
      service: DiscoverService(
        client: MockClient(
          (r) async => r.url.queryParameters['latitude'] == '21.0285'
              ? pending.future
              : forecast(23),
        ),
      ),
    );
    addTearDown(controller.dispose);
    final manual = controller.changeCity(WeatherCity.choices[1]);
    await controller.useCurrentLocation();
    pending.complete(forecast(38));
    await manual;
    expect(controller.usingDeviceLocation, isTrue);
    expect(controller.weather.data!.city.latitude, 12.34);
    expect(controller.weather.data!.temperature, 23);
  });

  test('A failed location refresh keeps the last forecast visibly stale and opens the right settings', () async {
    final location = _Location();
    final controller = DiscoverController(
      locationProvider: location,
      service: DiscoverService(client: MockClient((_) async => forecast())),
    );
    addTearDown(controller.dispose);
    await controller.refreshWeather();
    final previous = controller.weather.data;
    location.issue = WeatherLocationIssue.deniedForever;
    await controller.refreshWeather();
    expect(controller.weather.data, same(previous));
    expect(controller.weather.error, contains('đã tải trước đó'));
    await controller.openWeatherLocationSettings();
    expect(location.openedLocationServices, isFalse);
    location.issue = WeatherLocationIssue.serviceDisabled;
    await controller.refreshWeather();
    await controller.openWeatherLocationSettings();
    expect(location.openedLocationServices, isTrue);
  });

  testWidgets(
    'Weather card handles permission settings and switches between city and current location on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final location = _Location()..issue = WeatherLocationIssue.deniedForever;
      final controller = DiscoverController(
        locationProvider: location,
        service: DiscoverService(client: MockClient((_) async => forecast())),
      );
      addTearDown(controller.dispose);
      await controller.refreshWeather();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (_, _) => SingleChildScrollView(
                child: WeatherCard(controller: controller),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('weather-location-settings')));
      await tester.pumpAndSettle();
      expect(location.openedLocationServices, isFalse);
      await tester.tap(find.byKey(const Key('weather-location-menu')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Hà Nội'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(find.text('Hà Nội'), findsOneWidget);
      expect(controller.usingDeviceLocation, isFalse);
      location.issue = null;
      await tester.tap(find.byKey(const Key('weather-location-menu')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('weather-current-location')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(find.text('Vị trí hiện tại'), findsOneWidget);
      expect(controller.weather.data!.city.latitude, 12.34);
      expect(tester.takeException(), isNull);
    },
  );
}
