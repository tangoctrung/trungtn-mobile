import 'dart:io';

import 'package:flutter_demo/features/discover/discover_models.dart';
import 'package:flutter_demo/features/discover/discover_service.dart';

// Optional online smoke check. Unit tests use offline fixtures instead.
Future<void> main() async {
  final service = DiscoverService();
  try {
    final checks = <String, Future<Object> Function()>{
      'Open-Meteo': () async =>
          (await service.weather(WeatherCity.choices.first)).city.name,
      'BTMC': () async => '${(await service.gold()).rows.length} products',
      'Petrolimex': () async =>
          '${(await service.fuel()).rows.length} products',
      'VnExpress domestic': () async =>
          '${(await service.news(NewsCategory.domestic)).length} posts',
      'VnExpress world': () async =>
          '${(await service.news(NewsCategory.world)).length} posts',
    };
    await Future.wait(
      checks.entries.map((entry) async {
        try {
          stdout.writeln('${entry.key}: OK (${await entry.value()})');
        } catch (error) {
          stderr.writeln('${entry.key}: FAILED ($error)');
          exitCode = 1;
        }
      }),
    );
  } finally {
    service.close();
  }
}
