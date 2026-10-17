import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'car_link.dart';
import 'places_store.dart';

/// Automatic GPS driving: go to a saved place, or come Home to the phone.
///
///  GOTO lat,lon  is sent once (the car keeps the target).
///  HOME lat,lon  must be repeated about every 2 s with the phone position;
///                the car stops if it hears no HOME update for 6 s.
class GpsController extends ChangeNotifier {
  final CarLink link;
  final PlacesStore places;

  GpsController(this.link, this.places) {
    link.addListener(_onLink);
  }

  // current goal
  String  targetName = '';
  double? targetLat;
  double? targetLon;
  bool    homing = false;

  // phone position (only used for Home and "save phone position")
  double? phoneLat;
  double? phoneLon;
  String  message = '';          // last problem to show under the buttons

  Timer? _homeTimer;
  StreamSubscription<Position>? _posSub;
  bool _sawHome = false;
  DateTime? _homeStarted;

  bool get hasTarget => targetLat != null && targetLon != null;

  /// Metres from the car to the current goal, or null if unknown.
  double? get distanceToTarget {
    if (!hasTarget || !link.hasFix) return null;
    return _haversine(link.carLat, link.carLon, targetLat!, targetLon!);
  }

  // ── phone location ──────────────────────────────────────────────────────
  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      message = 'Turn on the phone location (GPS)';
      notifyListeners();
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      message = 'Location permission is needed';
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<Position?> phonePosition() async {
    if (!await _ensurePermission()) return null;
    try {
      final p = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.best)
          .timeout(const Duration(seconds: 10));
      phoneLat = p.latitude;
      phoneLon = p.longitude;
      return p;
    } catch (_) {
      message = 'Could not read the phone position';
      notifyListeners();
      return null;
    }
  }

  // ── actions ─────────────────────────────────────────────────────────────
  Future<void> goToPlace(Place p) async {
    if (!link.connected) { message = 'Connect the USB cable first'; notifyListeners(); return; }
    _stopHoming();
    message = '';
    targetName = p.name;
    targetLat  = p.lat;
    targetLon  = p.lon;
    link.goTo(p.lat, p.lon);
    notifyListeners();
  }

  Future<void> goHome() async {
    if (!link.connected) { message = 'Connect the USB cable first'; notifyListeners(); return; }
    message = '';
    final pos = await phonePosition();
    if (pos == null) return;

    _stopHoming();
    homing = true;
    _sawHome = false;
    _homeStarted = DateTime.now();
    targetName = 'You (phone)';
    targetLat  = pos.latitude;
    targetLon  = pos.longitude;
    link.home(pos.latitude, pos.longitude, log: true);

    // Keep the newest phone position and send it every 2 s.
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 0),
    ).listen((p) {
      phoneLat = p.latitude;
      phoneLon = p.longitude;
    }, onError: (_) {});
    _homeTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!homing || !link.connected || phoneLat == null || phoneLon == null) return;
      targetLat = phoneLat;
      targetLon = phoneLon;
      link.home(phoneLat!, phoneLon!);
      notifyListeners();
    });
    notifyListeners();
  }

  void stopAll() {
    _stopHoming();
    targetName = '';
    targetLat = null;
    targetLon = null;
    message = '';
    link.stop();
    notifyListeners();
  }

  void _stopHoming() {
    homing = false;
    _homeTimer?.cancel();
    _homeTimer = null;
    _posSub?.cancel();
    _posSub = null;
  }

  // ── follow the car's own mode ───────────────────────────────────────────
  void _onLink() {
    if (!link.connected && (homing || hasTarget)) {
      _stopHoming();
      targetName = '';
      targetLat = targetLon = null;
      notifyListeners();
      return;
    }
    if (homing) {
      if (link.mode == 'HOME') {
        _sawHome = true;
      } else if (_sawHome) {
        // car arrived, or a safety stop happened: stop sending HOME updates
        _stopHoming();
        notifyListeners();
      } else if (_homeStarted != null &&
          DateTime.now().difference(_homeStarted!).inSeconds > 12) {
        _stopHoming();
        message = 'Car did not start. Check the car link.';
        notifyListeners();
      }
    }
  }

  static double _haversine(double la1, double lo1, double la2, double lo2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180.0;
    final dLa = rad(la2 - la1), dLo = rad(lo2 - lo1);
    final a = math.pow(math.sin(dLa / 2), 2) +
        math.cos(rad(la1)) * math.cos(rad(la2)) * math.pow(math.sin(dLo / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  @override
  void dispose() {
    link.removeListener(_onLink);
    _stopHoming();
    super.dispose();
  }
}
