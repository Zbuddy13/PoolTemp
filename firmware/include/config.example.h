// Copy this file to include/config.h and fill in your values.
// config.h is gitignored so your WiFi credentials never get committed.
#pragma once

#define WIFI_SSID     "your-wifi-name"
#define WIFI_PASSWORD "your-wifi-password"

// The device will be reachable at http://<MDNS_HOSTNAME>.local
#define MDNS_HOSTNAME "pooltemp"

// GPIO the DS18B20 data line is wired to (4.7k pull-up to 3V3 required)
#define ONE_WIRE_PIN  4

// POSIX timezone string, used so hourly log timestamps are in real local time.
// US Eastern: "EST5EDT,M3.2.0,M11.1.0"   US Central: "CST6CDT,M3.2.0,M11.1.0"
// US Mountain: "MST7MDT,M3.2.0,M11.1.0"  US Pacific: "PST8PDT,M3.2.0,M11.1.0"
#define TZ_INFO       "EST5EDT,M3.2.0,M11.1.0"

#define NTP_SERVER    "pool.ntp.org"
