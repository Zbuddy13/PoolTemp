import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reading.dart';

/// Single-series line chart of hourly temperature samples.
///
/// Colors follow the validated dataviz palette: series blue #2A78D6 (light) /
/// #3987E5 (dark), muted axis ink, hairline gridlines, tooltip on touch.
class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.readings,
    required this.useFahrenheit,
    required this.range,
  });

  final List<TempReading> readings;
  final bool useFahrenheit;
  final HistoryRange range;

  static const _seriesLight = Color(0xFF2A78D6);
  static const _seriesDark = Color(0xFF3987E5);
  static const _mutedInk = Color(0xFF898781);
  static const _gridLight = Color(0xFFE1E0D9);
  static const _gridDark = Color(0xFF2C2C2A);

  double _display(TempReading r) => useFahrenheit ? r.fahrenheit : r.celsius;

  DateFormat get _tickFormat => switch (range) {
        HistoryRange.day => DateFormat('ha'),
        HistoryRange.week => DateFormat('E'),
        HistoryRange.month => DateFormat('M/d'),
      };

  double get _tickIntervalMs => switch (range) {
        HistoryRange.day => 6 * Duration.millisecondsPerHour.toDouble(),
        HistoryRange.week => 1 * Duration.millisecondsPerDay.toDouble(),
        HistoryRange.month => 7 * Duration.millisecondsPerDay.toDouble(),
      };

  @override
  Widget build(BuildContext context) {
    if (readings.length < 2) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Not enough data yet.\nThe sensor logs one sample per hour.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: _mutedInk),
          ),
        ),
      );
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final series = dark ? _seriesDark : _seriesLight;
    final grid = dark ? _gridDark : _gridLight;
    final unit = useFahrenheit ? '°F' : '°C';

    final spots = [
      for (final r in readings)
        FlSpot(r.time.millisecondsSinceEpoch.toDouble(), _display(r)),
    ];
    var minTemp = spots.first.y, maxTemp = spots.first.y;
    for (final s in spots) {
      minTemp = math.min(minTemp, s.y);
      maxTemp = math.max(maxTemp, s.y);
    }
    final pad = math.max(1.0, (maxTemp - minTemp) * 0.15);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: minTemp - pad,
          maxY: maxTemp + pad,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toStringAsFixed(0)}°',
                  style: const TextStyle(fontSize: 11, color: _mutedInk),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: _tickIntervalMs,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink(); // avoid edge collisions
                  }
                  final dt =
                      DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _tickFormat.format(dt),
                      style: const TextStyle(fontSize: 11, color: _mutedInk),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  dark ? const Color(0xFF383835) : const Color(0xFF0B0B0B),
              getTooltipItems: (touched) => [
                for (final spot in touched)
                  LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)}$unit\n'
                    '${DateFormat('MMM d, h a').format(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()))}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: series,
              barWidth: 2,
              isCurved: true,
              preventCurveOverShooting: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: series.withAlpha(31), // ~12% wash under the line
              ),
            ),
          ],
        ),
      ),
    );
  }
}
