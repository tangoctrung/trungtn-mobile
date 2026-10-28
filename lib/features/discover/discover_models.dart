class WeatherCity {
  const WeatherCity(this.name, this.latitude, this.longitude);
  final String name;
  final double latitude;
  final double longitude;

  static const choices = [
    WeatherCity('TP. Hồ Chí Minh', 10.8231, 106.6297),
    WeatherCity('Hà Nội', 21.0285, 105.8542),
    WeatherCity('Đà Nẵng', 16.0544, 108.2022),
    WeatherCity('Huế', 16.4637, 107.5909),
    WeatherCity('Cần Thơ', 10.0452, 105.7469),
    WeatherCity('Đà Lạt', 11.9404, 108.4583),
    WeatherCity('Hải Phòng', 20.8449, 106.6881),
  ];
}

class WeatherInfo {
  const WeatherInfo({
    required this.city,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.code,
    required this.observedAt,
  });
  final WeatherCity city;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int code;
  final DateTime observedAt;

  String get description => switch (code) {
    0 => 'Trời quang',
    1 || 2 => 'Có mây',
    3 => 'Nhiều mây',
    45 || 48 => 'Sương mù',
    >= 51 && <= 57 => 'Mưa phùn',
    >= 61 && <= 67 => 'Có mưa',
    >= 71 && <= 77 => 'Có tuyết',
    >= 80 && <= 82 => 'Mưa rào',
    >= 95 => 'Mưa dông',
    _ => 'Thời tiết hiện tại',
  };
}

class PriceRow {
  const PriceRow({
    required this.name,
    required this.first,
    required this.second,
    required this.updatedAt,
  });
  final String name;
  final num first;
  final num second;
  final String updatedAt;
}

class PriceBoard {
  const PriceBoard({
    required this.rows,
    required this.source,
    required this.sourceUrl,
    required this.firstLabel,
    required this.secondLabel,
    required this.unit,
  });
  final List<PriceRow> rows;
  final String source;
  final Uri sourceUrl;
  final String firstLabel;
  final String secondLabel;
  final String unit;
}

enum NewsCategory { domestic, world }

class NewsPost {
  const NewsPost({
    required this.title,
    required this.summary,
    required this.url,
    required this.category,
    this.imageUrl,
    this.publishedAt,
  });
  final String title;
  final String summary;
  final Uri url;
  final Uri? imageUrl;
  final NewsCategory category;
  final DateTime? publishedAt;
  String get categoryName =>
      category == NewsCategory.domestic ? 'Trong nước' : 'Thế giới';
}

class FeedResource<T> {
  T? data;
  bool loading = false;
  String? error;
  DateTime? fetchedAt;
  int request = 0;
}
