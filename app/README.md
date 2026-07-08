# PoolTemp App (Flutter — Android & iOS)

One Flutter codebase for both phones. On launch it fetches the current pool
temperature from the ESP32, and the History card graphs the hourly log over
the last 24 hours, 7 days, or 30 days. Pull down to refresh. The device
address and °F/°C preference live in Settings.

## 1. Generate the platform folders

The repo tracks only the Dart code; generate the Android/iOS projects once:

```sh
cd app
flutter create . --platforms android,ios --project-name pooltemp --org com.pooltemp
flutter pub get
```

If `flutter create` replaced any tracked file (check `git status`), restore the
repo's version with `git checkout -- <file>`.

## 2. Allow plain-HTTP access to the ESP32 (required)

The ESP32 serves plain HTTP on your local network, which both platforms block
by default. Without these two edits the app will show "could not reach" errors
even though `curl` works.

**Android** — in `android/app/src/main/AndroidManifest.xml`, add the attribute
to the `<application>` tag:

```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

**iOS** — in `ios/Runner/Info.plist`, add inside the top-level `<dict>`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
<key>NSLocalNetworkUsageDescription</key>
<string>PoolTemp connects to your pool temperature sensor on your local network.</string>
<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
</array>
```

(The last two keys let iOS resolve `pooltemp.local` and show the standard
local-network permission prompt.)

## 3. Run it

```sh
flutter run          # with a phone plugged in or an emulator running
```

For release builds: `flutter build apk` (Android) or open `ios/Runner.xcworkspace`
in Xcode and archive (iOS — requires a Mac and an Apple developer account to
install on a physical phone; a free account works for personal sideloading).

## Troubleshooting

- **"Could not reach pooltemp.local" on Android** — Android's mDNS support for
  `.local` names in plain HTTP requests is unreliable. Open Settings in the app
  and enter the ESP32's IP address instead (shown on the firmware's serial
  monitor, or in your router's client list). Give the ESP32 a DHCP reservation
  so the IP never changes.
- **Works on WiFi, fails on cellular** — expected: the ESP32 is only reachable
  from your home network. Remote access would need port forwarding or a VPN
  (e.g. Tailscale) — see ideas in the root README.
- **Flat or empty graph** — the sensor logs once per hour, so a freshly flashed
  device needs a few hours before the chart has anything to show.

## Code layout

```
lib/
├── main.dart                    # app entry + theme
├── models/reading.dart          # TempReading, CurrentTemp, HistoryRange
├── services/pool_api.dart       # HTTP client for the ESP32 JSON API
├── services/settings.dart       # persisted host + unit preference
├── screens/home_screen.dart     # current temp card + history card
├── screens/settings_screen.dart # device address, °F/°C toggle
└── widgets/history_chart.dart   # fl_chart line chart of the hourly log
```
