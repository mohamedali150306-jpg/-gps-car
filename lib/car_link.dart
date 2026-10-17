import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Link: phone ──USB (OTG cable)──> bridge ESP32 ──ESP-NOW──> car ESP32
//
// The bridge shows up as a USB serial port (115200 baud). Everything is text
// lines ending with \n, exactly the protocol of the car firmware README:
//
//   phone -> bridge   DRIVE s,t | GOTO lat,lon | HOME lat,lon | STOP | PING | CALIB
//   bridge -> phone   T,mode,fix,lat,lon,sats,hdg,servo,avoid,a0..a6,
//                       right,back,left,batPct,batV        (-1 = no reading)
//                     E,event[,dir[,value]]
//                     L,1 / L,0                            (car heard in last 2 s)
// ─────────────────────────────────────────────────────────────────────────────

enum LinkState { disconnected, connecting, connected }

class CarLink extends ChangeNotifier {
  static const int baud = 115200;

  // ── link state ────────────────────────────────────────────────────────────
  LinkState state      = LinkState.disconnected;
  String    deviceName = '';
  bool      carOnline  = false;       // from the bridge "L,1 / L,0" line

  // ── telemetry from the car ────────────────────────────────────────────────
  String mode        = 'IDLE';        // IDLE | DRIVE | GOTO | HOME
  bool   hasFix      = false;
  double carLat      = 0;
  double carLon      = 0;
  int    sats        = 0;
  double heading     = 0;             // degrees
  int    servoAngle  = 0;             // front sensor angle
  bool   avoiding    = false;
  final List<int?> arc = List<int?>.filled(7, null);   // front sweep, -45..45
  int?   distRight;
  int?   distBack;
  int?   distLeft;
  int    batteryPct   = 0;
  double batteryVolts = 0;
  bool   lowBattAlert = false;
  DateTime? lastTelemetry;

  final List<String> logs = [];

  UsbPort? _port;
  StreamSubscription<Uint8List>? _sub;
  StreamSubscription<UsbEvent>? _usbEvents;
  Timer? _heartbeat;
  String _buffer = '';

  bool get connected => state == LinkState.connected;

  /// Smallest valid distance of the front sweep (this is what safety uses).
  int? get distFront {
    int? m;
    for (final v in arc) {
      if (v != null && (m == null || v < m)) m = v;
    }
    return m;
  }

  // ── USB ───────────────────────────────────────────────────────────────────
  Future<List<UsbDevice>> listDevices() => UsbSerial.listDevices();

  Future<void> connect(UsbDevice device) async {
    if (connected) await disconnect();
    state = LinkState.connecting;
    notifyListeners();
    try {
      final port = await device.create();
      if (port == null) throw 'unsupported USB chip';
      final ok = await port.open();
      if (!ok) throw 'permission denied or port busy';

      // Keep DTR/RTS low so the ESP32 is not held in reset / download mode.
      await port.setDTR(false);
      await port.setRTS(false);
      await port.setPortParameters(
          baud, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

      _port = port;
      _buffer = '';
      deviceName = (device.productName?.isNotEmpty ?? false)
          ? device.productName!
          : 'USB ${device.vid?.toRadixString(16)}:${device.pid?.toRadixString(16)}';
      state = LinkState.connected;
      _addLog('ok', 'USB connected — $deviceName');

      _sub = port.inputStream?.listen(_onData, onError: (_) {
        _addLog('warn', 'USB read error');
        _handleDisconnect();
      }, onDone: () {
        _addLog('warn', 'USB closed');
        _handleDisconnect();
      });

      // Unplugging the cable also ends the session.
      _usbEvents ??= UsbSerial.usbEventStream?.listen((e) {
        if (e.event == UsbEvent.ACTION_USB_DETACHED && connected) {
          _addLog('warn', 'USB cable removed');
          _handleDisconnect();
        }
      });

      // The car stops by itself when it hears nothing for 1-3 s, so keep
      // a message flowing even when the user is not touching anything.
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 1), (_) {
        if (connected) send('PING', log: false);
      });
      notifyListeners();
    } catch (e) {
      state = LinkState.disconnected;
      _addLog('warn', 'Failed to connect: $e');
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (connected) send('STOP');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _sub?.cancel();
    _sub = null;
    _port?.close();
    _port = null;
    state        = LinkState.disconnected;
    deviceName   = '';
    carOnline    = false;
    mode         = 'IDLE';
    hasFix       = false;
    avoiding     = false;
    lowBattAlert = false;
    batteryPct   = 0;
    batteryVolts = 0;
    distRight = distBack = distLeft = null;
    for (var i = 0; i < arc.length; i++) {
      arc[i] = null;
    }
    lastTelemetry = null;
    notifyListeners();
  }

  // ── sending ───────────────────────────────────────────────────────────────
  void send(String cmd, {bool log = true}) {
    final p = _port;
    if (!connected || p == null) {
      if (log) _addLog('warn', 'Not connected');
      return;
    }
    try {
      p.write(Uint8List.fromList('$cmd\n'.codeUnits));
      if (log) _addLog('info', 'TX → $cmd');
    } catch (_) {
      _addLog('warn', 'Send failed');
    }
  }

  // Manual driving. Called every 100 ms while a button is held (not logged).
  void drive(double speed, double turn) => send(
      'DRIVE ${speed.clamp(-1.0, 1.0).toStringAsFixed(2)},'
      '${turn.clamp(-1.0, 1.0).toStringAsFixed(2)}',
      log: false);

  void stop()      => send('STOP');
  void calibrate() => send('CALIB');

  void goTo(double lat, double lon) =>
      send('GOTO ${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}');

  // HOME is re-sent every ~2 s with the phone position (not logged each time).
  void home(double lat, double lon, {bool log = false}) =>
      send('HOME ${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}', log: log);

  // ── receiving ─────────────────────────────────────────────────────────────
  void _onData(Uint8List data) {
    _buffer += String.fromCharCodes(data);
    while (_buffer.contains('\n')) {
      final idx  = _buffer.indexOf('\n');
      final line = _buffer.substring(0, idx).trim();
      _buffer    = _buffer.substring(idx + 1);
      if (line.isNotEmpty) _parseLine(line);
    }
    if (_buffer.length > 400) _buffer = '';   // garbage guard
  }

  int? _cm(String s) {
    final v = double.tryParse(s.trim());
    if (v == null || v < 0) return null;
    return v.round();
  }

  void _parseLine(String line) {
    if (line.startsWith('T,')) {
      _parseTelemetry(line.split(','));
    } else if (line.startsWith('E,')) {
      _parseEvent(line.split(','));
    } else if (line.startsWith('L,')) {
      final on = line.endsWith('1');
      if (on != carOnline) {
        carOnline = on;
        _addLog(on ? 'ok' : 'warn', on ? 'Car online' : 'Car not responding');
      }
      notifyListeners();
    } else {
      _addLog('info', 'RX ← $line');           // bridge boot text etc.
    }
  }

  // T,mode,fix,lat,lon,sats,hdg,servo,avoid,a0..a6,right,back,left,batPct,batV
  void _parseTelemetry(List<String> p) {
    if (p.length < 21) return;
    mode       = p[1];
    hasFix     = p[2] == '1';
    carLat     = double.tryParse(p[3]) ?? carLat;
    carLon     = double.tryParse(p[4]) ?? carLon;
    sats       = int.tryParse(p[5]) ?? sats;
    heading    = double.tryParse(p[6]) ?? heading;
    servoAngle = int.tryParse(p[7]) ?? servoAngle;
    avoiding   = p[8] == '1';
    for (var i = 0; i < 7; i++) {
      arc[i] = _cm(p[9 + i]);
    }
    distRight    = _cm(p[16]);
    distBack     = _cm(p[17]);
    distLeft     = _cm(p[18]);
    batteryPct   = (int.tryParse(p[19]) ?? batteryPct).clamp(0, 100);
    batteryVolts = double.tryParse(p[20]) ?? batteryVolts;
    if (batteryVolts >= 6.7) lowBattAlert = false;   // BATTERY_LOW_CLEAR_V
    carOnline     = true;
    lastTelemetry = DateTime.now();
    notifyListeners();
  }

  // E,name[,dir[,value]]   e.g.  E,obstacle,front,24.5   E,arrived,,2.1
  void _parseEvent(List<String> p) {
    final name  = p.length > 1 ? p[1] : '';
    final dir   = p.length > 2 ? p[2] : '';
    final value = p.length > 3 ? p[3] : '';
    final where = dir.isEmpty ? '' : ' ($dir)';
    switch (name) {
      case 'obstacle':
        _addLog('warn', 'Obstacle$where ${value}cm — car stopped');
        break;
      case 'warning':
        _addLog('warn', 'Close object$where ${value}cm');
        break;
      case 'blocked':
        _addLog('warn', 'Blocked$where — car stopped');
        break;
      case 'arrived':
        _addLog('ok', 'Arrived (${value}m from target)');
        break;
      case 'link_lost':
        _addLog('warn', 'Car lost the link — stopped');
        break;
      case 'gps_lost':
        _addLog('warn', 'Car lost GPS fix — stopped');
        break;
      case 'low_battery':
        lowBattAlert = true;
        _addLog('warn', 'LOW BATTERY ${value}V — car stopped');
        break;
      default:
        _addLog('info', 'RX ← ${p.join(',')}');
    }
    notifyListeners();
  }

  // ── log ───────────────────────────────────────────────────────────────────
  void _addLog(String type, String msg) {
    final prefix = type == 'ok' ? '✓' : type == 'warn' ? '⚠' : '›';
    logs.add('$prefix $msg');
    if (logs.length > 20) logs.removeAt(0);
    notifyListeners();
  }

  void addExternalLog(String type, String msg) => _addLog(type, msg);

  @override
  void dispose() {
    _heartbeat?.cancel();
    _sub?.cancel();
    _usbEvents?.cancel();
    _port?.close();
    super.dispose();
  }
}
