import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'app_theme.dart';
import 'car_link.dart';
import 'gps_controller.dart';
import 'places_store.dart';

/// Live OpenStreetMap view. Car position comes from car GPS telemetry;
/// phone position comes from the phone's location provider.
class LiveMapCard extends StatefulWidget {
  final CarLink link;
  final GpsController gps;
  final bool gpsMode;

  const LiveMapCard({super.key, required this.link, required this.gps, required this.gpsMode});

  @override
  State<LiveMapCard> createState() => _LiveMapCardState();
}

class _LiveMapCardState extends State<LiveMapCard> {
  final MapController _map = MapController();
  StreamSubscription<Position>? _phoneSub;
  LatLng? _phone;
  LatLng? _destination;
  String _locationMessage = 'Getting phone location…';

  @override
  void initState() {
    super.initState();
    widget.link.addListener(_refresh);
    _startPhoneLocation();
  }

  @override
  void didUpdateWidget(covariant LiveMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link != widget.link) {
      oldWidget.link.removeListener(_refresh);
      widget.link.addListener(_refresh);
    }
  }

  void _refresh() { if (mounted) setState(() {}); }

  Future<void> _startPhoneLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locationMessage = 'Enable phone location to show phone marker');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationMessage = 'Location permission required for phone marker');
        return;
      }
      final current = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      if (mounted) setState(() { _phone = LatLng(current.latitude, current.longitude); _locationMessage = 'Phone GPS active'; });
      _phoneSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best, distanceFilter: 2,
      )).listen((p) {
        if (mounted) setState(() { _phone = LatLng(p.latitude, p.longitude); _locationMessage = 'Phone GPS active'; });
      }, onError: (_) { if (mounted) setState(() => _locationMessage = 'Phone GPS unavailable'); });
    } catch (_) {
      if (mounted) setState(() => _locationMessage = 'Could not read phone location');
    }
  }

  LatLng? get _car {
    final l = widget.link;
    if (!l.hasFix || l.carLat.abs() > 90 || l.carLon.abs() > 180 || (l.carLat == 0 && l.carLon == 0)) return null;
    return LatLng(l.carLat, l.carLon);
  }

  LatLng get _initialCenter => _car ?? _phone ?? const LatLng(30.0444, 31.2357);

  List<Marker> _markers() {
    final result = <Marker>[];
    final car = _car;
    if (car != null) result.add(Marker(point: car, width: 48, height: 48, child: _marker(Icons.directions_car_filled, AppTheme.blueLight, 'CAR')));
    if (_phone != null) result.add(Marker(point: _phone!, width: 48, height: 48, child: _marker(Icons.phone_android, AppTheme.green, 'PHONE')));
    if (_destination != null) result.add(Marker(point: _destination!, width: 42, height: 48, child: _marker(Icons.location_on, AppTheme.red, 'DEST')));
    return result;
  }

  Widget _marker(IconData icon, Color color, String label) => Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: color, size: 28, shadows: const [Shadow(color: Colors.black87, blurRadius: 5)]),
    Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: AppTheme.bgPrimary.withOpacity(.9), borderRadius: BorderRadius.circular(4)), child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold))),
  ]);

  @override
  void dispose() {
    widget.link.removeListener(_refresh);
    _phoneSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final car = _car;
    return Container(
      height: 350,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderColor)),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 8), child: Row(children: [
          const Icon(Icons.map_outlined, color: AppTheme.blueLight, size: 18),
          const SizedBox(width: 7),
          const Expanded(child: Text('LIVE MAP', style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1))),
          Icon(Icons.circle, size: 8, color: car != null ? AppTheme.green : AppTheme.yellow),
          const SizedBox(width: 5),
          Text(car != null ? 'Car GPS fix' : 'Waiting for car GPS', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ])),
        Expanded(child: FlutterMap(
          mapController: _map,
          options: MapOptions(initialCenter: _initialCenter, initialZoom: 16, onTap: (_, point) {
            if (!widget.gpsMode) return;
            setState(() => _destination = point);
          }),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.robocar_controller'),
            if (car != null && _destination != null) PolylineLayer(polylines: [Polyline(points: [car, _destination!], strokeWidth: 4, color: AppTheme.blueLight)]),
            MarkerLayer(markers: _markers()),
            RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors', onTap: () {})]),
          ],
        )),
        Container(color: AppTheme.bgDeep, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Row(children: [
          Expanded(child: Text(car == null ? 'Car: waiting for valid GPS telemetry' : 'Car: ${car.latitude.toStringAsFixed(5)}, ${car.longitude.toStringAsFixed(5)}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          if (_phone != null) Text('Phone GPS ✓', style: const TextStyle(color: AppTheme.green, fontSize: 10)) else Flexible(child: Text(_locationMessage, style: const TextStyle(color: AppTheme.yellow, fontSize: 9), textAlign: TextAlign.end)),
        ])),
        if (widget.gpsMode) Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          Expanded(child: Text(_destination == null ? 'Tap the map to choose a destination' : 'Destination: ${_destination!.latitude.toStringAsFixed(5)}, ${_destination!.longitude.toStringAsFixed(5)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
          TextButton.icon(onPressed: _destination == null || !widget.link.connected ? null : () {
            final p = _destination!;
            widget.gps.goToPlace(Place('Map destination', p.latitude, p.longitude));
          }, icon: const Icon(Icons.navigation, size: 15), label: const Text('TRAVEL')),
          IconButton(tooltip: 'Return to phone', onPressed: widget.link.connected ? widget.gps.goHome : null, icon: const Icon(Icons.home_filled, color: AppTheme.blueLight)),
        ])),
      ]),
    );
  }
}
