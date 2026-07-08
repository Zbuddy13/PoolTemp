import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reading.dart';
import '../services/pool_api.dart';
import '../services/settings.dart';
import '../widgets/history_chart.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Settings? _settings;
  PoolApi? _api;

  CurrentTemp? _current;
  String? _currentError;
  List<TempReading> _history = const [];
  String? _historyError;
  bool _refreshing = false;
  HistoryRange _range = HistoryRange.day;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final settings = await Settings.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _api = PoolApi(settings.host);
    });
    await _refresh();
  }

  Future<void> _refresh() async {
    final api = _api;
    if (api == null || _refreshing) return;
    setState(() => _refreshing = true);
    await Future.wait([_fetchCurrent(api), _fetchHistory(api)]);
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _fetchCurrent(PoolApi api) async {
    try {
      final current = await api.fetchCurrent();
      if (mounted) {
        setState(() {
          _current = current;
          _currentError = null;
        });
      }
    } on PoolApiException catch (e) {
      if (mounted) setState(() => _currentError = e.message);
    }
  }

  Future<void> _fetchHistory(PoolApi api) async {
    try {
      // Fetch the full 30 days once; range switching filters locally.
      final history = await api.fetchHistory(hours: 720);
      if (mounted) {
        setState(() {
          _history = history;
          _historyError = null;
        });
      }
    } on PoolApiException catch (e) {
      if (mounted) setState(() => _historyError = e.message);
    }
  }

  Future<void> _openSettings() async {
    final settings = _settings;
    if (settings == null) return;
    final updated = await Navigator.push<Settings>(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen(settings: settings)),
    );
    if (updated != null && mounted) {
      setState(() {
        _settings = updated;
        _api = PoolApi(updated.host);
        _current = null;
        _currentError = null;
        _history = const [];
        _historyError = null;
      });
      await _refresh();
    }
  }

  List<TempReading> get _rangeReadings {
    final cutoff = DateTime.now().subtract(_range.duration);
    return [
      for (final r in _history)
        if (r.time.isAfter(cutoff)) r,
    ];
  }

  String _format(double celsius) {
    final settings = _settings!;
    final value = settings.useFahrenheit ? celsius * 9 / 5 + 32 : celsius;
    final unit = settings.useFahrenheit ? '°F' : '°C';
    return '${value.toStringAsFixed(1)}$unit';
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pool Temperature'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCurrentCard(context),
                  const SizedBox(height: 16),
                  _buildHistoryCard(context),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentCard(BuildContext context) {
    final theme = Theme.of(context);
    final current = _current;

    Widget content;
    if (current != null) {
      content = Column(
        children: [
          Icon(Icons.water, size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            _format(current.celsius),
            style: theme.textTheme.displayLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Updated ${DateFormat('MMM d, h:mm a').format(current.time)}',
            style: theme.textTheme.bodySmall,
          ),
          if (_currentError != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last refresh failed: $_currentError',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      );
    } else if (_currentError != null) {
      content = Column(
        children: [
          Icon(Icons.cloud_off, size: 40, color: theme.colorScheme.error),
          const SizedBox(height: 8),
          Text(_currentError!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    } else {
      content = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: content,
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('History', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<HistoryRange>(
              segments: [
                for (final range in HistoryRange.values)
                  ButtonSegment(value: range, label: Text(range.label)),
              ],
              selected: {_range},
              onSelectionChanged: (selection) =>
                  setState(() => _range = selection.first),
            ),
            const SizedBox(height: 16),
            if (_historyError != null && _history.isEmpty)
              SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    _historyError!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else
              HistoryChart(
                readings: _rangeReadings,
                useFahrenheit: _settings!.useFahrenheit,
                range: _range,
              ),
          ],
        ),
      ),
    );
  }
}
