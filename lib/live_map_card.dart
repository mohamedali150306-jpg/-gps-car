import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'app_theme.dart';
import 'car_link.dart';
import 'gps_controller.dart';
import 'places_store.dart';

/// Live map. The car position comes from car GPS telemetry and the phone
/// position comes from the phone's location provider.
class LiveMapCard extends StatefulWidget {
  final CarLink link;
  final GpsController gps;
  final bool gpsMode;

  const LiveMapCard({
    super.key,
    required this.link,
    required this.gps,
    required this.gpsMode,
  });

  @override
  State<LiveMapCard> createState() => _LiveMapCardState();
}

class _LiveMapCardState extends State<LiveMapCard> {
  final MapController _map = MapController();
  StreamSubscription<Position>? _phoneSub;
  LatLng? _phone;
  LatLng? _destination;
  String _locationMessage = 'Getting phone location…';
  bool _mapReady = false;
  bool _didInitialCenter = false;

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

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    _maybeCenterOnFirstFix();
  }

  void _maybeCenterOnFirstFix() {
    if (!_mapReady || _didInitialCenter) return;
    final target = _car ?? _phone;
    if (target == null) return;

    _didInitialCenter = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mapReady) _map.move(target, 16);
    });
  }

  Future<void> _startPhoneLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() => _locationMessage = 'Enable phone location to show phone marker');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationMessage = 'Location permission required for phone marker');
        }
        return;
      }

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      if (mounted) {
        setState(() {
          _phone = LatLng(current.latitude, current.longitude);
          _locationMessage = 'Phone GPS active';
        });
        _maybeCenterOnFirstFix();
      }

      _phoneSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 2,
        ),
      ).listen((position) {
        if (!mounted) return;
        setState(() {
          _phone = LatLng(position.latitude, position.longitude);
          _locationMessage = 'Phone GPS active';
        });
        _maybeCenterOnFirstFix();
      }, onError: (_) {
        if (mounted) setState(() => _locationMessage = 'Phone GPS unavailable');
      });
    } catch (_) {
      if (mounted) setState(() => _locationMessage = 'Could not read phone location');
    }
  }

  LatLng? get _car {
    final link = widget.link;
    if (!link.hasFix ||
        link.carLat.abs() > 90 ||
        link.carLon.abs() > 180 ||
        (link.carLat == 0 && link.carLon == 0)) {
      return null;
    }
    return LatLng(link.carLat, link.carLon);
  }

  LatLng get _initialCenter =>
      _car ?? _phone ?? const LatLng(30.0444, 31.2357);

  void _centerOnPhone() {
    final phone = _phone;
    if (!_mapReady || phone == null) return;
    _map.move(phone, 16);
  }

  void _centerOnCar() {
    final car = _car;
    if (!_mapReady || car == null) return;
    _map.move(car, 16);
  }

  List<Marker> _markers() {
    final result = <Marker>[];
    final car = _car;
    if (car != null) {
      result.add(Marker(
        point: car,
        width: 48,
        height: 48,
        child: _marker(Icons.directions_car_filled, AppTheme.blueLight, 'CAR'),
      ));
    }
    if (_phone != null) {
      result.add(Marker(
        point: _phone!,
        width: 48,
        height: 48,
        child: _marker(Icons.phone_android, AppTheme.green, 'PHONE'),
      ));
    }
    if (_destination != null) {
      result.add(Marker(
        point: _destination!,
        width: 42,
        height: 48,
        child: _marker(Icons.location_on, AppTheme.red, 'DEST'),
      ));
    }
    return result;
  }

  Widget _marker(IconData icon, Color color, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28, shadows: const [
            Shadow(color: Colors.black87, blurRadius: 5),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.bgPrimary.withOpacity(.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );

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
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.map_outlined, color: AppTheme.blueLight, size: 18),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'LIVE MAP',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Icon(Icons.circle, size: 8, color: car != null ? AppTheme.green : AppTheme.yellow),
                const SizedBox(width: 5),
                Text(
                  car != null ? 'Car GPS fix' : 'Waiting for car GPS',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 16,
                onMapReady: () {
                  if (!mounted) return;
                  setState(() => _mapReady = true);
                  _maybeCenterOnFirstFix();
                },
                onTap: (_, point) {
                  if (!widget.gpsMode) return;
                  setState(() => _destination = point);
                },
              ),
              children: [
                // This world street basemap uses English global place labels.
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.example.robocar_controller',
                  maxNativeZoom: 19,
                ),
                if (car != null && _destination != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [car, _destination!],
                        strokeWidth: 4,
                        color: AppTheme.blueLight,
                      ),
                    ],
                  ),
                MarkerLayer(markers: _markers()),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _MapCenterButton(
                          icon: Icons.phone_android,
                          label: 'Phone',
                          tooltip: 'Center map on phone',
                          enabled: _mapReady && _phone != null,
                          onPressed: _centerOnPhone,
                        ),
                        const SizedBox(height: 6),
                        _MapCenterButton(
                          icon: Icons.directions_car_filled,
                          label: 'Car',
                          tooltip: 'Center map on car',
                          enabled: _mapReady && car != null,
                          onPressed: _centerOnCar,
                        ),
                      ],
                    ),
                  ),
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'Sources: Esri, HERE, Garmin, USGS, Intermap, NRCAN, TomTom',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: AppTheme.bgDeep,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    car == null
                        ? 'Car: waiting for valid GPS telemetry'
                        : 'Car: ${car.latitude.toStringAsFixed(5)}, ${car.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (_phone != null)
                  const Text(
                    'Phone GPS ✓',
                    style: TextStyle(color: AppTheme.green, fontSize: 10),
                  )
                else
                  Flexible(
                    child: Text(
                      _locationMessage,
                      style: const TextStyle(color: AppTheme.yellow, fontSize: 9),
                      textAlign: TextAlign.end,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.gpsMode)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _destination == null
                          ? 'Tap the map to choose a destination'
                          : 'Destination: ${_destination!.latitude.toStringAsFixed(5)}, ${_destination!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _destination == null || !widget.link.connected
                        ? null
                        : () {
                            final point = _destination!;
                            widget.gps.goToPlace(
                              Place('Map destination', point.latitude, point.longitude),
                            );
                          },
                    icon: const Icon(Icons.navigation, size: 15),
                    label: const Text('TRAVEL'),
                  ),
                  IconButton(
                    tooltip: 'Return to phone',
                    onPressed: widget.link.connected ? widget.gps.goHome : null,
                    icon: const Icon(Icons.home_filled, color: AppTheme.blueLight),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MapCenterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  const _MapCenterButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.bgPrimary.withOpacity(.94),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(9),
          child: Opacity(
            opacity: enabled ? 1 : .45,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppTheme.blueLight, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
