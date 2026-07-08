# PoolTemp Firmware — Arduino IDE version

Same firmware as [`firmware/`](../firmware/) (which is for PlatformIO), packaged
as an Arduino IDE sketch. Use whichever toolchain you prefer — they behave
identically.

## Flashing with the Arduino IDE

1. **Open the sketch**: File → Open → `arduino/PoolTemp/PoolTemp.ino`.
   (The Arduino IDE can only open `.ino` sketches whose folder has the same
   name — that's why `firmware/src/main.cpp` doesn't show up.)
2. **Install ESP32 board support** (once): Tools → Board → Boards Manager,
   search **esp32**, install "esp32 by Espressif Systems".
3. **Install the two libraries** (once): Sketch → Include Library → Manage
   Libraries, then install:
   - **OneWire** by Paul Stoffregen
   - **DallasTemperature** by Miles Burton
4. **Edit the CONFIG block** at the top of the sketch: WiFi name/password and
   your timezone.
5. **Select the board and port**: Tools → Board → esp32 → **ESP32 Dev Module**
   (fine for most generic dev boards), and Tools → Port → the USB port that
   appears when you plug the board in.
6. Click **Upload**. If the upload hangs at "Connecting....._____", hold the
   **BOOT** button on the board until it starts writing.
7. Open Tools → **Serial Monitor** at **115200 baud** — you'll see it connect
   and print its IP address. Note that IP for the app.

## Verify it works

From a computer on the same WiFi:

```
http://pooltemp.local/api/temperature     (or http://<the-IP>/api/temperature)
```

You should see something like `{"celsius":27.31,"fahrenheit":81.16,"time":1720012345}`.

Wiring, API details, and how the hourly logging works are documented in
[`firmware/README.md`](../firmware/README.md) — everything there applies to
this sketch too.
