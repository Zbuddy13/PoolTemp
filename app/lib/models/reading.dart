/// A single logged temperature sample from the ESP32's hourly history.
class TempReading {
  const TempReading({required this.time, required this.celsius});

  final DateTime time;
  final double celsius;

  double get fahrenheit => celsius * 9 / 5 + 32;

  factory TempReading.fromJson(Map<String, dynamic> json) => TempReading(
        time: DateTime.fromMillisecondsSinceEpoch(
            (json['t'] as num).toInt() * 1000),
        celsius: (json['c'] as num).toDouble(),
      );
}

/// The live reading returned by GET /api/temperature.
class CurrentTemp {
  const CurrentTemp({required this.celsius, required this.time});

  final double celsius;
  final DateTime time;

  double get fahrenheit => celsius * 9 / 5 + 32;

  factory CurrentTemp.fromJson(Map<String, dynamic> json) => CurrentTemp(
        celsius: (json['celsius'] as num).toDouble(),
        time: DateTime.fromMillisecondsSinceEpoch(
            (json['time'] as num).toInt() * 1000),
      );
}

/// Time windows the history chart can display.
enum HistoryRange {
  day('24H', Duration(hours: 24)),
  week('7D', Duration(days: 7)),
  month('30D', Duration(days: 30));

  const HistoryRange(this.label, this.duration);

  final String label;
  final Duration duration;
}
