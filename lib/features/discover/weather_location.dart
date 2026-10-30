import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'discover_models.dart';

enum WeatherLocationIssue {
  denied,
  deniedForever,
  serviceDisabled,
  timeout,
  unavailable,
}

class WeatherLocationFailure implements Exception {
  const WeatherLocationFailure(this.issue);
  final WeatherLocationIssue issue;
  String get message => switch (issue) {
    WeatherLocationIssue.denied => 'Chưa được cấp quyền vị trí. Cho phép vị trí hoặc chọn thành phố để xem thời tiết.',
    WeatherLocationIssue.deniedForever =>
      'Quyền vị trí đã bị tắt. Mở cài đặt để cho phép hoặc chọn thành phố.',
    WeatherLocationIssue.serviceDisabled => 'Dịch vụ vị trí đang tắt. Bật vị trí hoặc chọn thành phố để xem thời tiết.',
    WeatherLocationIssue.timeout =>
      'Chưa xác định được vị trí. Hãy thử lại hoặc chọn thành phố.',
    WeatherLocationIssue.unavailable =>
      'Không lấy được vị trí thiết bị. Hãy thử lại hoặc chọn thành phố.',
  };
}

abstract interface class WeatherLocationProvider {
  Future<WeatherCity> currentLocation({required bool requestPermission});
  Future<bool> openSettings({required bool locationServices});
}

class DeviceWeatherLocation implements WeatherLocationProvider {
  Future<WeatherCity>? _pending;

  @override
  Future<WeatherCity> currentLocation({required bool requestPermission}) =>
      _pending ??= _locate(requestPermission)
          .whenComplete(() => _pending = null);

  Future<WeatherCity> _locate(bool requestPermission) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const WeatherLocationFailure(
          WeatherLocationIssue.serviceDisabled,
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const WeatherLocationFailure(WeatherLocationIssue.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        throw const WeatherLocationFailure(WeatherLocationIssue.denied);
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw const WeatherLocationFailure(WeatherLocationIssue.unavailable);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180) {
        throw const WeatherLocationFailure(WeatherLocationIssue.unavailable);
      }
      return WeatherCity(
        'Vị trí hiện tại',
        position.latitude,
        position.longitude,
      );
    } on WeatherLocationFailure {
      rethrow;
    } on TimeoutException {
      throw const WeatherLocationFailure(WeatherLocationIssue.timeout);
    } on LocationServiceDisabledException {
      throw const WeatherLocationFailure(WeatherLocationIssue.serviceDisabled);
    } on PermissionDeniedException {
      throw const WeatherLocationFailure(WeatherLocationIssue.denied);
    } catch (_) {
      throw const WeatherLocationFailure(WeatherLocationIssue.unavailable);
    }
  }

  @override
  Future<bool> openSettings({required bool locationServices}) =>
      locationServices
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings();
}
