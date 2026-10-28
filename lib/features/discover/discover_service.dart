import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import 'discover_models.dart';

class DiscoverService {
  DiscoverService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<String> _get(Uri uri) async {
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('HTTP ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes);
  }

  Future<WeatherInfo> weather(WeatherCity city) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${city.latitude}',
      'longitude': '${city.longitude}',
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m',
      'timezone': 'Asia/Ho_Chi_Minh',
    });
    final json = jsonDecode(await _get(uri)) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;
    return WeatherInfo(
      city: city,
      temperature: (current['temperature_2m'] as num).toDouble(),
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      code: (current['weather_code'] as num).toInt(),
      observedAt: DateTime.parse('${current['time']}+07:00'),
    );
  }

  Future<PriceBoard> gold() async {
    // Public key published by BTMC in its API documentation; not an app secret.
    final uri = Uri.https('api.btmc.vn', '/api/BTMCAPI/getpricebtmc', {
      'key': '3kd8ub1llcg9t45hnoh8hmn7t5kc2v',
    });
    final json = jsonDecode(await _get(uri)) as Map<String, dynamic>;
    final data = (json['DataList'] as Map<String, dynamic>)['Data'] as List;
    final latest = <String, ({DateTime time, PriceRow row})>{};
    for (final entry in data.cast<Map<String, dynamic>>()) {
      final index = entry['@row'];
      final name = entry['@n_$index'] as String;
      if (!name.contains('SJC') && !name.contains('NHẪN TRÒN TRƠN')) continue;
      final buy = num.parse(entry['@pb_$index'] as String);
      final sell = num.parse(entry['@ps_$index'] as String);
      if (buy <= 0 || sell <= 0) continue;
      final product = name.contains('SJC')
          ? 'Vàng miếng SJC'
          : 'Nhẫn tròn trơn VRTL';
      final updatedAt = entry['@d_$index'] as String;
      final time = DateFormat('dd/MM/yyyy HH:mm').parseStrict(updatedAt);
      if (latest[product] case final previous?
          when !time.isAfter(previous.time)) {
        continue;
      }
      // This endpoint also includes historical rows for the same product.
      latest[product] = (
        time: time,
        row: PriceRow(
          name: product,
          first: buy,
          second: sell,
          updatedAt: updatedAt,
        ),
      );
    }
    final rows = latest.values.map((entry) => entry.row).toList();
    if (rows.isEmpty) throw const FormatException('No gold prices');
    return PriceBoard(
      rows: rows,
      source: 'Bảo Tín Minh Châu',
      sourceUrl: Uri.parse('https://btmc.vn/'),
      firstLabel: 'Mua vào',
      secondLabel: 'Bán ra',
      unit: 'đ / chỉ',
    );
  }

  Future<PriceBoard> fuel() async {
    // Same public CMS query used by Petrolimex's retail-price widget.
    final request = {
      'FilterBy': {
        'And': [
          {
            'SystemID': {'Equals': '6783dc1271ff449e95b74a9520964169'},
          },
          {
            'RepositoryID': {'Equals': 'a95451e23b474fe5886bfb7cf843f53c'},
          },
          {
            'RepositoryEntityID': {
              'Equals': '3801378fe1e045b1afa10de7c5776124',
            },
          },
          {
            'Status': {'Equals': 'Published'},
          },
        ],
      },
      'SortBy': {'LastModified': 'Descending'},
      'Pagination': {
        'TotalRecords': -1,
        'TotalPages': 0,
        'PageSize': 0,
        'PageNumber': 0,
      },
    };
    final uri = Uri.https(
      'portals.petrolimex.com.vn',
      '/~apis/portals/cms.item/search',
      {
        'x-request': base64Url
            .encode(utf8.encode(jsonEncode(request)))
            .replaceAll('=', ''),
      },
    );
    final json = jsonDecode(await _get(uri)) as Map<String, dynamic>;
    final entries =
        (json['Objects'] as List).cast<Map<String, dynamic>>().toList()..sort(
          (a, b) => ((a['DIsplayOrder'] ?? a['OrderIndex'] ?? 0) as num)
              .compareTo((b['DIsplayOrder'] ?? b['OrderIndex'] ?? 0) as num),
        );
    final rows = entries
        .where((entry) {
          final name = entry['Title'] as String;
          return name.contains('RON') || name.contains('DO ');
        })
        .map(
          (entry) => PriceRow(
            name: entry['Title'] as String,
            first: entry['Zone1Price'] as num,
            second: entry['Zone2Price'] as num,
            updatedAt: DateFormat('dd/MM/yyyy · HH:mm').format(
              DateTime.parse(entry['LastModified'] as String)
                  .toUtc()
                  .add(const Duration(hours: 7)),
            ),
          ),
        )
        .where((row) => row.first > 0 && row.second > 0)
        .toList();
    if (rows.isEmpty) throw const FormatException('No fuel prices');
    return PriceBoard(
      rows: rows,
      source: 'Petrolimex',
      sourceUrl: Uri.parse('https://www.petrolimex.com.vn/'),
      firstLabel: 'Vùng 1',
      secondLabel: 'Vùng 2',
      unit: 'đ / lít',
    );
  }

  Future<List<NewsPost>> news(NewsCategory category) async {
    final path = category == NewsCategory.domestic ? 'thoi-su' : 'the-gioi';
    final document = XmlDocument.parse(
      await _get(Uri.https('vnexpress.net', '/rss/$path.rss')),
    );
    final posts = <NewsPost>[];
    for (final item in document.findAllElements('item').take(20)) {
      final title = item.getElement('title')?.innerText.trim() ?? '';
      final uri = Uri.tryParse(item.getElement('link')?.innerText.trim() ?? '');
      if (title.isEmpty ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'vnexpress.net') {
        continue;
      }
      final fragment = html.parseFragment(
        item.getElement('description')?.innerText ?? '',
      );
      final image =
          item.getElement('enclosure')?.getAttribute('url') ??
          fragment.querySelector('img')?.attributes['src'];
      final imageUri = Uri.tryParse(image ?? '');
      posts.add(
        NewsPost(
          title: title,
          summary: fragment.text?.trim() ?? '',
          url: uri,
          category: category,
          imageUrl: imageUri?.scheme == 'https' ? imageUri : null,
          publishedAt: _rssDate(item.getElement('pubDate')?.innerText ?? ''),
        ),
      );
    }
    if (posts.isEmpty) throw const FormatException('No RSS posts');
    return posts;
  }

  DateTime? _rssDate(String value) {
    final match = RegExp(
      r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) ([+-]\d{4}|GMT)',
    ).firstMatch(value);
    if (match == null) return DateTime.tryParse(value);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months.indexOf(match[2]!) + 1;
    if (month == 0) return null;
    final zone = match[7]!;
    final offset = zone == 'GMT'
        ? 0
        : (int.parse(zone.substring(1, 3)) * 60 +
                  int.parse(zone.substring(3))) *
              (zone.startsWith('-') ? -1 : 1);
    return DateTime.utc(
      int.parse(match[3]!),
      month,
      int.parse(match[1]!),
      int.parse(match[4]!),
      int.parse(match[5]!),
      int.parse(match[6]!),
    ).subtract(Duration(minutes: offset));
  }

  void close() => _client.close();
}
