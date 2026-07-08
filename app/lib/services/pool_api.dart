import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/reading.dart';

class PoolApiException implements Exception {
  const PoolApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thin HTTP client for the ESP32's JSON API.
class PoolApi {
  PoolApi(String host)
      : baseUri = Uri.parse(host.contains('://') ? host : 'http://$host');

  final Uri baseUri;
  static const _timeout = Duration(seconds: 8);

  Future<CurrentTemp> fetchCurrent() async {
    final json = await _getJson('/api/temperature');
    return CurrentTemp.fromJson(json as Map<String, dynamic>);
  }

  /// Fetches logged samples for the last [hours] hours, oldest first.
  Future<List<TempReading>> fetchHistory({int hours = 720}) async {
    final json = await _getJson('/api/history', {'hours': '$hours'});
    return (json as List)
        .map((e) => TempReading.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<dynamic> _getJson(String path, [Map<String, String>? query]) async {
    final uri = baseUri.replace(path: path, queryParameters: query);
    late http.Response response;
    try {
      response = await http.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw PoolApiException(
          'Timed out reaching ${baseUri.host} — is the sensor online?');
    } catch (_) {
      throw PoolApiException(
          'Could not reach ${baseUri.host} — check the device address in Settings.');
    }
    if (response.statusCode == 503) {
      throw const PoolApiException(
          'The device is online but cannot read its temperature sensor.');
    }
    if (response.statusCode != 200) {
      throw PoolApiException('Device returned HTTP ${response.statusCode}.');
    }
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw const PoolApiException('Device returned an unexpected response.');
    }
  }
}
