# PoolTemp

Monitor your pool temperature from your phone. An ESP32 with a waterproof
DS18B20 probe measures the water, serves the live reading over your home WiFi,
and logs one sample every hour. A Flutter app (Android + iOS from one codebase)
shows the current temperature when opened and graphs the history over 24 hours,
7 days, or 30 days.

```
 ┌──────────────┐   OneWire    ┌─────────────────────┐    WiFi / HTTP+JSON    ┌─────────────┐
 │   DS18B20    ├─────────────▶│        ESP32        │◀───────────────────────┤  Phone app  │
 │ (waterproof  │   GPIO 4     │ · /api/temperature  │   GET on app open      │ Android/iOS │
 │   probe)     │              │ · /api/history      │   GET for the graph    │  (Flutter)  │
 └──────────────┘              │ · hourly log ➜ flash│                        └─────────────┘
                               └─────────────────────┘
```

## Repo layout

| Directory | What it is |
|---|---|
| [`firmware/`](firmware/) | PlatformIO project for the ESP32: DS18B20 reading, WiFi + mDNS (`pooltemp.local`), JSON API, hourly logging to flash (30 days retained, survives reboots). |
| [`arduino/`](arduino/) | The same firmware as an **Arduino IDE** sketch (`arduino/PoolTemp/PoolTemp.ino`) — use this if you prefer the Arduino IDE over PlatformIO. |
| [`app/`](app/) | Flutter app: live temperature on open, pull-to-refresh, history graph (24H / 7D / 30D), °F/°C toggle, configurable device address. |

## Hardware

- ESP32 dev board (any common "ESP32 DevKit" style board)
- DS18B20 waterproof temperature probe
- 4.7 kΩ resistor (pull-up between the data line and 3.3 V)
- USB or 5 V power supply near the pool (in a weatherproof enclosure)

Wiring: probe **red → 3V3**, **black → GND**, **yellow → GPIO 4**, with the
4.7 kΩ resistor between GPIO 4 and 3V3. Details in [`firmware/README.md`](firmware/README.md).

## Quick start

1. **Firmware** — `cd firmware`, copy `include/config.example.h` to
   `include/config.h`, fill in WiFi credentials and timezone, then
   `pio run -t upload`. Verify with `curl http://pooltemp.local/api/temperature`.
2. **App** — `cd app`, run `flutter create . --platforms android,ios
   --project-name pooltemp --org com.pooltemp`, apply the two small platform
   tweaks that allow plain-HTTP local traffic (step 2 in
   [`app/README.md`](app/README.md)), then `flutter run`.

## How it fits together

- **On app open** the app calls `GET /api/temperature` and shows the reading
  (the firmware caches sensor reads for 10 s so taps are instant).
- **Every hour on the hour** the firmware appends `{"t":<epoch>,"c":<celsius>}`
  to a log file in flash. NTP keeps the clock right; the newest 720 samples
  (30 days) are retained and survive power cuts.
- **The graph** comes from `GET /api/history` — the app fetches the full 30
  days on refresh and filters locally when you switch between 24H / 7D / 30D.

## Notes & future ideas

- The phone must be on the same network as the ESP32. For away-from-home
  access, the simplest safe option is a VPN into your home network (e.g.
  Tailscale/WireGuard); alternatively push samples to a cloud service.
- Other easy extensions: temperature alerts via push notification, multiple
  sensors (air + water), OTA firmware updates, a Home Assistant integration
  (the JSON API is trivial to scrape).
