# GPS Robot Car — phone app (Flutter)

Link: **phone —USB OTG cable→ bridge ESP32 —ESP-NOW→ car ESP32**.
The bridge firmware is in `gps_robot_car` (`ROBOT_ROLE ROLE_BRIDGE`). The app talks to it as a USB serial port, 115200 baud, text lines.

## What the app does
| Part | Logic |
|---|---|
| Top bar | tap to pick the USB device and connect; shows USB status and whether the car answers |
| STOP | always visible; sends `STOP` and cancels GOTO / HOME |
| Manual | 8-direction D-pad + 9 speed levels, sends `DRIVE speed,turn` every 100 ms while held, `STOP` on release |
| GPS | **Home** (car drives to the phone, `HOME lat,lon` every 2 s), saved places (type a name → `GOTO lat,lon`), save phone position / car position, compass calibration (`CALIB`) |
| Sensors | front / right / back / left in cm, plus the 7-point front sweep; red under 30 cm, yellow under 60 cm |
| Battery | percent and volts from the car; low-battery banner when the car sends `E,low_battery` |
| Log | events from the car (obstacle, arrived, link lost, GPS lost…) |

## Files (lib/)
```
main.dart                 entry
app_theme.dart            colours (unchanged)
car_link.dart             USB connection, heartbeat, protocol parsing, telemetry values
gps_controller.dart       GOTO / HOME logic, phone GPS, distance to target
places_store.dart         saved places (kept on the phone)
home_screen.dart          screen layout, wires everything together
usb_picker_dialog.dart    USB device list
mode_card.dart            Manual / GPS tabs
manual_control_card.dart  D-pad and speed knob
gps_card.dart             Home button, place name, saved list, calibrate
sensor_card.dart          ultrasonic distances
battery_card.dart         battery
log_card.dart             log
```

## Build
```bash
flutter pub get
flutter build apk --release
```
Android build files were moved to the Flutter 3.10 defaults (Gradle 7.5, Android Gradle Plugin 7.3.0, Kotlin 1.7.10) because the new plugins need them.

## Using it
1. Plug the bridge ESP32 into the phone with an OTG cable (the phone powers it).
2. Open the app, tap the top-right chip, choose the device, allow USB access.
3. "Car" turns green in the top bar when the car answers.
4. GPS mode needs the car GPS fix and a calibrated compass; Home also needs the phone location turned on.
