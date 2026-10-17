# RoboCar GPS Controller — Flutter app

Connection architecture: **Android phone → USB OTG → bridge ESP32 → ESP-NOW → car ESP32**. The app communicates with the bridge as a USB serial device.

## Home dashboard

The home screen has a dark navy/electric-blue dashboard style with a compact connection and battery header, Manual Mode and GPS Mode tiles, and an explicit **Activate Mode** button. Switching the selected mode cancels previous drive/navigation commands; the selected mode must be activated again before its matching controls are enabled.

The live map uses Esri dark-gray map tiles with a separate label/reference layer. The **Phone** button centers on the phone's live GPS position, while **Car** centers on the latest valid car GPS telemetry. Tap the map while GPS mode is active to select a destination, then use **Travel to Destination** or **Return to Phone**. The drawn segment on the map is a straight line between coordinates, not turn-by-turn road routing.

The compact Manual Control panel has forward, reverse, left, right, stop, and three speed levels. A direction command repeats while pressed and STOP is sent on release. The full app also retains the advanced GPS tools for saved places, saving phone/car positions, and compass calibration.

The four ultrasonic sensor cards highlight readings **below 10 cm in red**. The optional front-sweep row exposes the seven individual scan values. Emergency Stop remains visible beneath the control panels. Bottom navigation scrolls to Home, Map, Sensors, and Logs, and opens the connection/status Settings sheet.

## Source files

- `lib/main.dart` — app entry and theme setup
- `lib/home_screen.dart` — home dashboard and actions
- `lib/app_theme.dart` — navy/blue color palette
- `lib/live_map_card.dart` — live phone/car map, destination selection, map centering
- `lib/mode_card.dart` — Manual/GPS mode selector and activation
- `lib/car_link.dart` — USB connection, telemetry, and command protocol
- `lib/gps_controller.dart` — GPS destination / return-to-phone logic
- `lib/gps_card.dart` — advanced place-saving and compass tools
- `lib/sensor_card.dart` — ultrasonic readings
- `lib/log_card.dart` — event log
- `lib/usb_picker_dialog.dart` — USB device picker

## Build

The included CodeMagic workflow targets a release APK using Flutter 3.24.5 and Java 17. The Android project uses Kotlin Gradle plugin 1.9.22 to match the Kotlin metadata used by the resolved Android plugins.

```bash
flutter pub get
flutter build apk --release
```

Use CodeMagic's build log to diagnose remaining Android Gradle or dependency incompatibilities; the dashboard source has not been compiled in this environment.
