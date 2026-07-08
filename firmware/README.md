# PoolTemp Firmware (ESP32 + DS18B20)

Reads the pool temperature, serves it over WiFi as JSON, and logs one sample
per hour to flash so the mobile app can draw a history graph. Timestamps come
from NTP, hostname is announced over mDNS as `pooltemp.local`.

## Wiring

Use a waterproof DS18B20 probe (the kind with a stainless tip and long cable).

```
DS18B20 red    (VDD)  ->  ESP32 3V3
DS18B20 black  (GND)  ->  ESP32 GND
DS18B20 yellow (DATA) ->  ESP32 GPIO 4
4.7 kΩ resistor between DATA and 3V3  (required pull-up)
```

Notes:
- The pull-up resistor is not optional — without it you'll get -127 °C readings.
- Powered (3-wire) mode as wired above is more reliable than parasite power,
  especially over a long cable run.
- Power the ESP32 from USB or a 5V supply; WiFi sleep is disabled for fast
  responses, so battery power is not a good fit.

## Setup

1. Install [PlatformIO](https://platformio.org/) (VS Code extension or `pip install platformio`).
2. Copy the config template and fill in your WiFi details and timezone:

   ```sh
   cp include/config.example.h include/config.h
   ```

3. Build and flash (with the board plugged in over USB):

   ```sh
   pio run -t upload
   pio device monitor   # watch it connect and print its IP
   ```

## Try it

```sh
curl http://pooltemp.local/api/temperature
# {"celsius":27.31,"fahrenheit":81.16,"time":1720012345}

curl "http://pooltemp.local/api/history?hours=24"
# [{"t":1720008000,"c":27.10},{"t":1720011600,"c":27.25}, ...]

curl http://pooltemp.local/api/status
```

If `pooltemp.local` doesn't resolve on your network, use the IP address printed
on the serial monitor (and consider giving the ESP32 a DHCP reservation in your
router so it never changes).

## How logging works

- Every hour on the hour (once the clock is NTP-synced), the firmware reads the
  sensor and appends `{"t":<epoch>,"c":<celsius>}` to `/log.jsonl` in LittleFS.
- The log keeps the most recent **720 samples (30 days)**; older entries are
  compacted away automatically.
- The log survives reboots and power cuts, and a reboot within the same hour
  won't produce a duplicate sample.
- `GET /api/history` returns everything; `?hours=N` filters to the last N hours.

## API

| Endpoint | Response |
|---|---|
| `GET /api/temperature` | `{"celsius":27.31,"fahrenheit":81.16,"time":1720012345}` — current reading (cached up to 10 s). `503` if the sensor is unreachable. |
| `GET /api/history?hours=N` | JSON array of `{"t":epoch,"c":celsius}`, oldest first. Omit `hours` for the full 30 days. |
| `GET /api/status` | IP, WiFi RSSI, uptime, sample count, free heap, clock-sync state. |

All endpoints send `Access-Control-Allow-Origin: *`, so a web dashboard could
call them directly too.
