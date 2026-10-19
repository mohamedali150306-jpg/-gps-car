import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final double height;
  final bool showNavigationActions;
  final ValueChanged<LatLng>? onDestinationSelected;

  const LiveMapCard({
    super.key,
    required this.link,
    required this.gps,
    required this.gpsMode,
    this.height = 350,
    this.showNavigationActions = true,
    this.onDestinationSelected,
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
  int _style = 0; // index into _kMapStyles

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

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(3.0, 19.0).toDouble());
  }

  // Arrow button: show the car and the phone together (or whichever exists).
  void _fitAll() {
    if (!_mapReady) return;
    final pts = <LatLng>[if (_car != null) _car!, if (_phone != null) _phone!];
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _map.move(pts.first, 16);
    } else {
      _map.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.all(70),
        maxZoom: 18,
      ));
    }
  }

  Future<void> _openExternalMaps() async {
    final target = _car ?? _phone ?? (_mapReady ? _map.camera.center : _initialCenter);
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${target.latitude},${target.longitude}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _toast('Could not open a maps app.');
    } catch (_) {
      if (mounted) _toast('Could not open a maps app.');
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
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
    final style = _kMapStyles[_style];
    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderBlue, width: .9),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 16,
                    minZoom: 3,
                    maxZoom: 19,
                    onMapReady: () {
                      if (!mounted) return;
                      setState(() => _mapReady = true);
                      _maybeCenterOnFirstFix();
                    },
                    onTap: (_, point) {
                      if (!widget.gpsMode) return;
                      setState(() => _destination = point);
                      widget.onDestinationSelected?.call(point);
                    },
                  ),
                  children: [
                    for (final url in style.urls)
                      TileLayer(
                        key: ValueKey(url),
                        urlTemplate: url,
                        userAgentPackageName: 'com.example.robocar_controller',
                        maxNativeZoom: style.maxNativeZoom,
                      ),
                    if (car != null && _destination != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(points: [car, _destination!], strokeWidth: 4, color: AppTheme.blueLight),
                        ],
                      ),
                    MarkerLayer(markers: _markers()),
                    RichAttributionWidget(
                      alignment: AttributionAlignment.bottomRight,
                      attributions: [TextSourceAttribution('Map tiles: Esri', onTap: () {})],
                    ),
                  ],
                ),
                // Top-left: map style selector + GPS fix status.
                Positioned(
                  left: 8,
                  top: 8,
                  right: 62,
                  child: Row(children: [
                    _StyleDropdown(
                      value: _style,
                      onChanged: (i) => setState(() => _style = i),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.bgPrimary.withOpacity(.82),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.circle, size: 7, color: car != null ? AppTheme.green : AppTheme.yellow),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              car != null ? 'Car GPS' : 'No car fix',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
                // Top-right: fit-all arrow + zoom.
                Positioned(
                  right: 8,
                  top: 8,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _RoundMapButton(icon: Icons.navigation_rounded, tooltip: 'Show car and phone', onTap: _fitAll),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgPrimary.withOpacity(.88),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderBlue, width: .8),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _ZoomButton(icon: Icons.add_rounded, tooltip: 'Zoom in', onTap: () => _zoomBy(1)),
                        Container(width: 26, height: .8, color: AppTheme.borderBlue),
                        _ZoomButton(icon: Icons.remove_rounded, tooltip: 'Zoom out', onTap: () => _zoomBy(-1)),
                      ]),
                    ),
                  ]),
                ),
                // Bottom-left: center on phone / car.
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.bgPrimary.withOpacity(.88),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderBlue, width: .8),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _MapCenterButton(
                        icon: Icons.my_location_rounded,
                        label: 'Center\non Phone',
                        tooltip: 'Center map on phone',
                        enabled: _mapReady && _phone != null,
                        onPressed: _centerOnPhone,
                      ),
                      const SizedBox(height: 2),
                      _MapCenterButton(
                        icon: Icons.directions_car_filled_rounded,
                        label: 'Center\non Car',
                        tooltip: 'Center map on car',
                        enabled: _mapReady && car != null,
                        onPressed: _centerOnCar,
                      ),
                    ]),
                  ),
                ),
                // Bottom-center: open the location in the phone's maps app.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Center(
                    child: Material(
                      color: AppTheme.bgPrimary.withOpacity(.88),
                      shape: StadiumBorder(side: BorderSide(color: AppTheme.borderBlue, width: .8)),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: _openExternalMaps,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.touch_app_outlined, color: AppTheme.blueLight, size: 18),
                            SizedBox(width: 6),
                            Text('Tap to open maps', style: TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_phone == null)
            Container(
              width: double.infinity,
              color: AppTheme.bgDeep,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(_locationMessage, style: const TextStyle(color: AppTheme.yellow, fontSize: 9), textAlign: TextAlign.center),
            ),
          if (widget.gpsMode && widget.showNavigationActions)
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

class _MapStyle {
  final String name;
  final IconData icon;
  final List<String> urls;
  final int maxNativeZoom;
  const _MapStyle(this.name, this.icon, this.urls, this.maxNativeZoom);
}

const _esri = 'https://server.arcgisonline.com/ArcGIS/rest/services';
const List<_MapStyle> _kMapStyles = [
  _MapStyle('Dark Map', Icons.dark_mode_rounded, [
    '$_esri/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
    '$_esri/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
  ], 16),
  _MapStyle('Street Map', Icons.map_rounded, [
    '$_esri/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
  ], 19),
  _MapStyle('Satellite', Icons.satellite_alt_rounded, [
    '$_esri/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  ], 19),
];

class _StyleDropdown extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _StyleDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 9, right: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary.withOpacity(.88),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppTheme.borderBlue, width: .8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          dropdownColor: AppTheme.bgCard,
          iconEnabledColor: AppTheme.textPrimary,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          items: [
            for (var i = 0; i < _kMapStyles.length; i++)
              DropdownMenuItem(
                value: i,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_kMapStyles[i].icon, size: 17, color: AppTheme.blueLight),
                  const SizedBox(width: 7),
                  Text(_kMapStyles[i].name),
                ]),
              ),
          ],
          onChanged: (i) {
            if (i != null) onChanged(i);
          },
        ),
      ),
    );
  }
}

class _RoundMapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundMapButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.bgPrimary.withOpacity(.88),
        shape: CircleBorder(side: BorderSide(color: AppTheme.borderBlue, width: .8)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: AppTheme.textPrimary, size: 22)),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(width: 44, height: 40, child: Icon(icon, color: AppTheme.textPrimary, size: 24)),
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
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(9),
        child: Opacity(
          opacity: enabled ? 1 : .45,
          child: SizedBox(
            width: 62,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppTheme.textPrimary, size: 20),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 9, height: 1.15),
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
