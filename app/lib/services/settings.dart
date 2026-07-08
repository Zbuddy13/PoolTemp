import 'package:shared_preferences/shared_preferences.dart';

/// User preferences, persisted locally on the phone.
class Settings {
  Settings({required this.host, required this.useFahrenheit});

  /// Hostname or IP of the ESP32 (with or without http://).
  String host;
  bool useFahrenheit;

  static const defaultHost = 'pooltemp.local';
  static const _hostKey = 'host';
  static const _fahrenheitKey = 'useFahrenheit';

  static Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Settings(
      host: prefs.getString(_hostKey) ?? defaultHost,
      useFahrenheit: prefs.getBool(_fahrenheitKey) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, host);
    await prefs.setBool(_fahrenheitKey, useFahrenheit);
  }
}
