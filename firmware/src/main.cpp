// PoolTemp firmware
//
// Reads a DS18B20 temperature sensor, serves the current reading over HTTP,
// and appends one sample per hour to a log in flash (LittleFS) so the app
// can draw a history graph.
//
// HTTP API (all responses are JSON with CORS enabled):
//   GET /api/temperature        -> {"celsius":27.31,"fahrenheit":81.16,"time":1720012345}
//   GET /api/history[?hours=N]  -> [{"t":1720008000,"c":27.10}, ...]
//   GET /api/status             -> device diagnostics

#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <LittleFS.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <time.h>
#include <math.h>

#if __has_include("config.h")
#include "config.h"
#else
#error "Copy include/config.example.h to include/config.h and fill in your WiFi credentials"
#endif

static const char *LOG_PATH = "/log.jsonl";
static const char *LOG_TMP_PATH = "/log.tmp";
static const size_t MAX_LOG_ENTRIES = 720;        // 30 days of hourly samples
static const time_t MIN_VALID_EPOCH = 1700000000; // clock counts as synced past this
static const unsigned long CACHE_FRESH_MS = 10000;  // serve cached reading up to 10 s old
static const unsigned long CACHE_MAX_AGE_MS = 60000; // past this a failed read reports an error

OneWire oneWire(ONE_WIRE_PIN);
DallasTemperature sensors(&oneWire);
WebServer server(80);

time_t lastLoggedHour = 0;
unsigned long lastLogAttemptMs = 0;
size_t logEntryCount = 0;

float cachedC = NAN;
unsigned long cachedAtMs = 0;

// ---------------------------------------------------------------- sensor ---

float readSensorC() {
  sensors.requestTemperatures();
  float c = sensors.getTempCByIndex(0);
  if (c == DEVICE_DISCONNECTED_C || c < -55.0f || c > 125.0f) return NAN;
  return c;
}

float currentTempC() {
  unsigned long age = millis() - cachedAtMs;
  if (isnan(cachedC) || age > CACHE_FRESH_MS) {
    float c = readSensorC();
    if (!isnan(c)) {
      cachedC = c;
      cachedAtMs = millis();
    } else if (!isnan(cachedC) && age > CACHE_MAX_AGE_MS) {
      cachedC = NAN; // stale cache and the sensor is gone — stop reporting it
    }
  }
  return cachedC;
}

// ------------------------------------------------------------------- log ---

// Parse the epoch out of a {"t":<epoch>,"c":<temp>} line; 0 if absent.
time_t lineEpoch(const String &line) {
  int i = line.indexOf("\"t\":");
  if (i < 0) return 0;
  return (time_t)strtoul(line.c_str() + i + 4, nullptr, 10);
}

void initLogState() {
  File f = LittleFS.open(LOG_PATH, "r");
  if (!f) return;
  String lastLine;
  while (f.available()) {
    String line = f.readStringUntil('\n');
    line.trim();
    if (line.length()) {
      logEntryCount++;
      lastLine = line;
    }
  }
  f.close();
  // Remember the last logged hour so a reboot doesn't produce a duplicate sample.
  time_t t = lineEpoch(lastLine);
  if (t > 0) lastLoggedHour = t - (t % 3600);
  Serial.printf("Log: %u samples, last at %lu\n", (unsigned)logEntryCount,
                (unsigned long)lastLoggedHour);
}

// Rewrite the log keeping only the newest MAX_LOG_ENTRIES lines.
void compactLog() {
  File in = LittleFS.open(LOG_PATH, "r");
  if (!in) return;
  File out = LittleFS.open(LOG_TMP_PATH, "w");
  if (!out) {
    in.close();
    return;
  }
  size_t drop = logEntryCount > MAX_LOG_ENTRIES ? logEntryCount - MAX_LOG_ENTRIES : 0;
  size_t kept = 0;
  while (in.available()) {
    String line = in.readStringUntil('\n');
    line.trim();
    if (!line.length()) continue;
    if (drop > 0) {
      drop--;
      continue;
    }
    out.println(line);
    kept++;
  }
  in.close();
  out.close();
  LittleFS.remove(LOG_PATH);
  LittleFS.rename(LOG_TMP_PATH, LOG_PATH);
  logEntryCount = kept;
}

void appendLog(time_t t, float c) {
  File f = LittleFS.open(LOG_PATH, "a");
  if (!f) {
    Serial.println("Log: append failed");
    return;
  }
  char line[48];
  snprintf(line, sizeof(line), "{\"t\":%lu,\"c\":%.2f}", (unsigned long)t, c);
  f.println(line);
  f.close();
  logEntryCount++;
  if (logEntryCount > MAX_LOG_ENTRIES) compactLog();
}

void maybeLogHourly() {
  time_t now = time(nullptr);
  if (now < MIN_VALID_EPOCH) return; // clock not NTP-synced yet
  time_t hour = now - (now % 3600);
  if (hour == lastLoggedHour) return;
  // If the sensor read fails, retry once a minute instead of every loop pass.
  if (lastLogAttemptMs != 0 && millis() - lastLogAttemptMs < 60000UL) return;
  lastLogAttemptMs = millis();
  float c = readSensorC();
  if (isnan(c)) {
    Serial.println("Log: sensor read failed, will retry");
    return;
  }
  lastLoggedHour = hour;
  appendLog(hour, c);
  Serial.printf("Log: %.2f C at %lu (%u samples)\n", c, (unsigned long)hour,
                (unsigned)logEntryCount);
}

// ------------------------------------------------------------------ http ---

void sendCors() { server.sendHeader("Access-Control-Allow-Origin", "*"); }

void handleTemperature() {
  sendCors();
  float c = currentTempC();
  if (isnan(c)) {
    server.send(503, "application/json", "{\"error\":\"sensor unavailable\"}");
    return;
  }
  char body[96];
  snprintf(body, sizeof(body),
           "{\"celsius\":%.2f,\"fahrenheit\":%.2f,\"time\":%lu}", c,
           c * 9.0f / 5.0f + 32.0f, (unsigned long)time(nullptr));
  server.send(200, "application/json", body);
}

void handleHistory() {
  sendCors();
  time_t since = 0;
  if (server.hasArg("hours")) {
    long hours = server.arg("hours").toInt();
    time_t now = time(nullptr);
    if (hours > 0 && now > MIN_VALID_EPOCH) since = now - (time_t)hours * 3600;
  }
  // Stream the log as a JSON array so we never hold it all in RAM.
  server.setContentLength(CONTENT_LENGTH_UNKNOWN);
  server.send(200, "application/json", "");
  server.sendContent("[");
  File f = LittleFS.open(LOG_PATH, "r");
  bool first = true;
  if (f) {
    while (f.available()) {
      String line = f.readStringUntil('\n');
      line.trim();
      if (!line.length()) continue;
      if (since > 0 && lineEpoch(line) < since) continue;
      if (!first) server.sendContent(",");
      server.sendContent(line);
      first = false;
    }
    f.close();
  }
  server.sendContent("]");
  server.sendContent(""); // terminate chunked response
}

void handleStatus() {
  sendCors();
  time_t now = time(nullptr);
  char body[224];
  snprintf(body, sizeof(body),
           "{\"ip\":\"%s\",\"rssi\":%d,\"uptime_s\":%lu,\"samples\":%u,"
           "\"free_heap\":%u,\"time\":%lu,\"time_synced\":%s}",
           WiFi.localIP().toString().c_str(), WiFi.RSSI(),
           (unsigned long)(millis() / 1000), (unsigned)logEntryCount,
           (unsigned)ESP.getFreeHeap(), (unsigned long)now,
           now > MIN_VALID_EPOCH ? "true" : "false");
  server.send(200, "application/json", body);
}

void handleNotFound() {
  sendCors();
  server.send(404, "application/json", "{\"error\":\"not found\"}");
}

// ------------------------------------------------------------------ wifi ---

void ensureWiFi() {
  static unsigned long lastAttempt = 0;
  if (WiFi.status() == WL_CONNECTED) return;
  if (lastAttempt != 0 && millis() - lastAttempt < 15000UL) return;
  lastAttempt = millis();
  Serial.println("WiFi: reconnecting...");
  WiFi.disconnect();
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

// ----------------------------------------------------------------- setup ---

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\nPoolTemp starting");

  sensors.begin();
  sensors.setResolution(12);

  if (!LittleFS.begin(true)) {
    Serial.println("LittleFS mount failed — history logging disabled");
  } else {
    initLogState();
  }

  WiFi.mode(WIFI_STA);
  WiFi.setHostname(MDNS_HOSTNAME);
  WiFi.setSleep(false); // keeps HTTP responses snappy; fine on USB/mains power
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.printf("WiFi: connecting to %s", WIFI_SSID);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000UL) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("WiFi: connected, IP %s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println("WiFi: not connected yet, retrying in background");
  }

  configTzTime(TZ_INFO, NTP_SERVER);

  if (MDNS.begin(MDNS_HOSTNAME)) {
    MDNS.addService("http", "tcp", 80);
    Serial.printf("mDNS: http://%s.local\n", MDNS_HOSTNAME);
  }

  server.on("/api/temperature", HTTP_GET, handleTemperature);
  server.on("/api/history", HTTP_GET, handleHistory);
  server.on("/api/status", HTTP_GET, handleStatus);
  server.onNotFound(handleNotFound);
  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient();
  ensureWiFi();
  maybeLogHourly();
  delay(2);
}
