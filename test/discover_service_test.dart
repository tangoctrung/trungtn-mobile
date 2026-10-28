import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_demo/features/discover/discover_controller.dart';
import 'package:flutter_demo/features/discover/discover_models.dart';
import 'package:flutter_demo/features/discover/discover_service.dart';

http.Response jsonResponse(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const rss = '''<?xml version="1.0"?><rss><channel>
<item><title>Bài viết thử nghiệm</title>
<description><![CDATA[<a><img src="https://example.com/image.jpg"></a><br>Thông tin mới.]]></description>
<link>https://vnexpress.net/bai-viet-123.html</link><pubDate>Wed, 28 Oct 2026 08:24:07 +0700</pubDate></item>
<item><title>Unsafe</title><link>javascript:alert(1)</link></item>
</channel></rss>''';

Map<String, Object> weather(double temperature) => {
  'current': {
    'temperature_2m': temperature,
    'apparent_temperature': 31,
    'relative_humidity_2m': 75,
    'wind_speed_10m': 12,
    'weather_code': 3,
    'time': '2026-10-28T08:30',
  },
};

void main() {
  test('Weather requests selected coordinates and parses the Vietnam observation time', () async {
    final service = DiscoverService(
      client: MockClient((request) async {
        expect(request.url.queryParameters['latitude'], '21.0285');
        expect(request.url.queryParameters['timezone'], 'Asia/Ho_Chi_Minh');
        return jsonResponse(weather(28.5));
      }),
    );
    addTearDown(service.close);
    final result = await service.weather(WeatherCity.choices[1]);
    expect(result.city.name, 'Hà Nội');
    expect(result.temperature, 28.5);
    expect(result.observedAt.toUtc(), DateTime.utc(2026, 10, 28, 1, 30));
  });

  test('Gold keeps BTMC buy/sell values and product units without inventing a price', () async {
    final service = DiscoverService(
      client: MockClient(
        (_) async => jsonResponse({
          'DataList': {
            'Data': [
              {
                '@row': '6',
                '@n_6': 'VÀNG MIẾNG SJC (Vàng SJC)',
                '@pb_6': '10000000',
                '@ps_6': '11000000',
                '@d_6': '28/10/2026 08:00',
              },
              {
                '@row': '17',
                '@n_17': 'VÀNG MIẾNG SJC (Vàng SJC)',
                '@pb_17': '9000000',
                '@ps_17': '9500000',
                '@d_17': '27/10/2026 09:00',
              },
            ],
          },
        }),
      ),
    );
    addTearDown(service.close);
    final result = await service.gold();
    expect(result.rows.single.first, 10000000);
    expect(result.rows.single.second, 11000000);
    expect(result.unit, 'đ / chỉ');
    expect(result.rows.single.updatedAt, '28/10/2026 08:00');
  });

  test(
    'Fuel preserves both regions and excludes products sold by mass',
    () async {
      final service = DiscoverService(
        client: MockClient((request) async {
          final query = jsonDecode(
            utf8.decode(
              base64Url.decode(
                base64Url.normalize(request.url.queryParameters['x-request']!),
              ),
            ),
          ) as Map;
          expect(query['FilterBy'], isNotNull);
          return jsonResponse({
            'Objects': [
              {
                'Title': 'FO 3,5S',
                'Zone1Price': 15000,
                'Zone2Price': 16000,
                'LastModified': '2026-10-22T07:55:00Z',
                'DIsplayOrder': 9,
              },
              {
                'Title': 'Xăng RON 95-V',
                'Zone1Price': 20000,
                'Zone2Price': 20400,
                'LastModified': '2026-10-22T07:55:00Z',
                'DIsplayOrder': 1,
              },
            ],
          });
        }),
      );
      addTearDown(service.close);
      final board = await service.fuel();
      expect(board.rows, hasLength(1));
      expect(board.rows.single.first, 20000);
      expect(board.rows.single.second, 20400);
      expect(board.rows.single.updatedAt, '22/10/2026 · 14:55');
    },
  );

  test('RSS extracts post text, image, category and timezone; unsafe links are skipped', () async {
    final service = DiscoverService(
      client: MockClient(
        (_) async => http.Response(
          rss,
          200,
          headers: {'content-type': 'application/xml; charset=utf-8'},
        ),
      ),
    );
    addTearDown(service.close);
    final posts = await service.news(NewsCategory.domestic);
    expect(posts, hasLength(1));
    expect(posts.single.summary, 'Thông tin mới.');
    expect(posts.single.imageUrl.toString(), 'https://example.com/image.jpg');
    expect(posts.single.category, NewsCategory.domestic);
    expect(posts.single.publishedAt, DateTime.utc(2026, 10, 28, 1, 24, 7));
  });

  test(
    'One unavailable source does not prevent other feeds from loading',
    () async {
      final controller = DiscoverController(
        service: DiscoverService(
          client: MockClient((request) async {
            if (request.url.host == 'api.open-meteo.com') {
              return jsonResponse(weather(28));
            }
            if (request.url.host == 'vnexpress.net') {
              return http.Response(
                rss,
                200,
                headers: {'content-type': 'text/xml; charset=utf-8'},
              );
            }
            return http.Response('Unavailable', 503);
          }),
        ),
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.weather.data, isNotNull);
      expect(controller.domestic.data, hasLength(1));
      expect(controller.gold.data, isNull);
      expect(controller.gold.error, isNotNull);
      expect(controller.fuel.loading, isFalse);
    },
  );

  test(
    'A slower previous city response cannot replace the newly selected city',
    () async {
      final oldResponse = Completer<http.Response>();
      final controller = DiscoverController(
        service: DiscoverService(
          client: MockClient((request) async {
            if (request.url.queryParameters['latitude'] == '10.8231') {
              return oldResponse.future;
            }
            return jsonResponse(weather(20));
          }),
        ),
      );
      addTearDown(controller.dispose);
      final first = controller.changeCity(WeatherCity.choices[0]);
      await controller.changeCity(WeatherCity.choices[1]);
      oldResponse.complete(jsonResponse(weather(35)));
      await first;
      expect(controller.weather.data!.city.name, 'Hà Nội');
      expect(controller.weather.data!.temperature, 20);
    },
  );
}
