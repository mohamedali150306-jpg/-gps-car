import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'app_theme.dart';
import 'car_link.dart';
import 'usb_picker_dialog.dart';
import 'places_store.dart';
import 'gps_controller.dart';
import 'mode_card.dart';
import 'gps_card.dart';
import 'sensor_card.dart';
import 'log_card.dart';
import 'live_map_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _link = CarLink();
  final _places = PlacesStore();
  late final GpsController _gps = GpsController(_link, _places);

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _mapKey = GlobalKey();
  final GlobalKey _sensorKey = GlobalKey();
  final GlobalKey _logKey = GlobalKey();

  CarMode _selected = CarMode.manual;
  CarMode? _activeMode;
  LatLng? _selectedDestination;
  int _selectedNav = 0;

  @override
  void initState() {
    super.initState();
    _link.addListener(_rebuild);
    _places.load();
  }

  void _rebuild() {
    if (!_link.connected) _activeMode = null;
    if (mounted) setState(() {});
  }

  void _onModeChanged(CarMode mode) {
    if (mode == _selected) return;
    if (_link.connected) _gps.stopAll();
    setState(() {
      _selected = mode;
      _activeMode = null;
    });
  }

  void _activateSelectedMode() {
    if (!_link.connected) {
      _message('Connect the car before activating a mode.');
      return;
    }

    _gps.stopAll();
    if (_selected == CarMode.manual) {
      // A zero-speed command switches the firmware back to DRIVE/manual mode.
      _link.drive(0, 0);
    }

    final message = _selected == CarMode.manual
        ? 'Manual mode activated.'
        : 'GPS mode activated. Select a point on the map, then tap Travel.';
    setState(() => _activeMode = _selected);
    _link.addExternalLog('ok', message);
    _message(message);
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _onMapDestinationSelected(LatLng point) {
    setState(() => _selectedDestination = point);
  }

  Future<void> _selectDestination() async {
    if (_activeMode != CarMode.gps) {
      _message('Select GPS Mode and press Activate GPS Mode first.');
      return;
    }
    await _scrollTo(_mapKey, navIndex: 1);
    _message('Tap anywhere on the map to choose your destination.');
  }

  void _travelToDestination() {
    final point = _selectedDestination;
    if (!_link.connected) {
      _message('Connect the car before starting navigation.');
      return;
    }
    if (_activeMode != CarMode.gps) {
      _message('Activate GPS Mode first.');
      return;
    }
    if (point == null) {
      _message('Select a destination on the map first.');
      return;
    }
    _gps.goToPlace(Place('Map destination', point.latitude, point.longitude));
    _link.addExternalLog('ok', 'Travel requested to map destination');
  }

  void _returnToPhone() {
    if (!_link.connected) {
      _message('Connect the car before requesting Return to Phone.');
      return;
    }
    if (_activeMode != CarMode.gps) {
      _message('Activate GPS Mode first.');
      return;
    }
    _gps.goHome();
  }

  Future<void> _toggleLink() async {
    if (_link.connected) {
      _gps.stopAll();
      await _link.disconnect();
      return;
    }
    final device = await showDialog(
      context: context,
      builder: (_) => UsbPickerDialog(link: _link),
    );
    if (device != null) await _link.connect(device);
  }

  Future<void> _scrollTo(GlobalKey key, {required int navIndex}) async {
    setState(() => _selectedNav = navIndex);
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  void _onBottomNav(int index) {
    switch (index) {
      case 0:
        setState(() => _selectedNav = 0);
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
        break;
      case 1:
        _scrollTo(_mapKey, navIndex: 1);
        break;
      case 2:
        _scrollTo(_sensorKey, navIndex: 2);
        break;
      case 3:
        _scrollTo(_logKey, navIndex: 3);
        break;
      case 4:
        _openSettings();
        break;
    }
  }

  void _openSettings() {
    setState(() => _selectedNav = 4);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 5),
              const Text('Connection and live car status', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 18),
              _SettingsLine(icon: Icons.usb_rounded, title: 'USB bridge', value: _link.connected ? 'Connected' : 'Disconnected', valueColor: _link.connected ? AppTheme.green : AppTheme.red),
              _SettingsLine(icon: Icons.directions_car_filled_rounded, title: 'Car telemetry', value: _link.carOnline ? 'Online' : 'Waiting for car', valueColor: _link.carOnline ? AppTheme.green : AppTheme.yellow),
              _SettingsLine(icon: Icons.battery_full_rounded, title: 'Car battery', value: _link.connected ? '${_link.batteryPct}%  ·  ${_link.batteryVolts.toStringAsFixed(1)} V' : 'Unavailable', valueColor: AppTheme.blueLight),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _toggleLink();
                    if (mounted) setState(() => _selectedNav = 0);
                  },
                  icon: Icon(_link.connected ? Icons.link_off_rounded : Icons.usb_rounded),
                  label: Text(_link.connected ? 'Disconnect car' : 'Connect car'),
                  style: ElevatedButton.styleFrom(backgroundColor: _link.connected ? AppTheme.redBg : AppTheme.blue, foregroundColor: AppTheme.textPrimary, padding: const EdgeInsets.symmetric(vertical: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted && _selectedNav == 4) setState(() => _selectedNav = 0);
    });
  }

  void _openAdvancedGps() {
    if (_activeMode != CarMode.gps) {
      _message('Activate GPS Mode first to open navigation tools.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .86,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 30),
            child: GpsCard(link: _link, places: _places, gps: _gps),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _link.removeListener(_rebuild);
    _gps.dispose();
    _link.dispose();
    _places.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _link.connected;
    final connecting = _link.state == LinkState.connecting;
    final mapHeight = (MediaQuery.sizeOf(context).height * .31).clamp(250.0, 340.0).toDouble();

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              connected: connected,
              connecting: connecting,
              carOnline: _link.carOnline,
              deviceName: _link.deviceName,
              batteryPct: _link.batteryPct,
              batteryVolts: _link.batteryVolts,
              lowBattAlert: _link.lowBattAlert,
              onUsbTap: _toggleLink,
            ),
            Expanded(
              child: ListView(
                key: _homeKey,
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                children: [
                  ModeCard(
                    current: _selected,
                    activeMode: _activeMode,
                    connected: connected,
                    onChanged: _onModeChanged,
                    onActivate: _activateSelectedMode,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    key: _mapKey,
                    child: LiveMapCard(
                      link: _link,
                      gps: _gps,
                      gpsMode: _activeMode == CarMode.gps,
                      height: mapHeight,
                      showNavigationActions: false,
                      onDestinationSelected: _onMapDestinationSelected,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_selected == CarMode.manual)
                    _CompactManualCard(
                      enabled: connected && _activeMode == CarMode.manual,
                      onDrive: _link.drive,
                      onStop: _gps.stopAll,
                    )
                  else
                    _QuickGpsCard(
                      connected: connected,
                      active: _activeMode == CarMode.gps,
                      destination: _selectedDestination,
                      onSelectDestination: _selectDestination,
                      onTravel: _travelToDestination,
                      onReturn: _returnToPhone,
                      onAdvanced: _openAdvancedGps,
                    ),
                  const SizedBox(height: 10),
                  _EmergencyStopButton(enabled: connected, onTap: _gps.stopAll),
                  const SizedBox(height: 10),
                  Container(
                    key: _sensorKey,
                    child: SensorCard(
                      front: _link.distFront,
                      right: _link.distRight,
                      back: _link.distBack,
                      left: _link.distLeft,
                      arc: _link.arc,
                      connected: connected && _link.carOnline,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(key: _logKey, child: LogCard(logs: _link.logs)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(selectedIndex: _selectedNav, onTap: _onBottomNav),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool connected;
  final bool connecting;
  final bool carOnline;
  final String deviceName;
  final int batteryPct;
  final double batteryVolts;
  final bool lowBattAlert;
  final VoidCallback onUsbTap;

  const _TopBar({
    required this.connected,
    required this.connecting,
    required this.carOnline,
    required this.deviceName,
    required this.batteryPct,
    required this.batteryVolts,
    required this.lowBattAlert,
    required this.onUsbTap,
  });

  @override
  Widget build(BuildContext context) {
    final linkColor = connected ? (carOnline ? AppTheme.green : AppTheme.yellow) : AppTheme.red;
    final batteryAvailable = connected && carOnline;
    final battColor = !batteryAvailable ? AppTheme.textMuted : batteryPct < 17 ? AppTheme.red : batteryPct < 40 ? AppTheme.yellow : AppTheme.green;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF092846), Color(0xFF04162B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderBlue, width: .8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                'assets/robocar.png',
                width: 62,
                height: 42,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: AppTheme.bgDeep, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppTheme.borderBlue)),
                  child: const Icon(Icons.smart_toy_rounded, color: AppTheme.blueLight, size: 29),
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('RoboCar', style: TextStyle(fontSize: 19, height: 1, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    SizedBox(height: 4),
                    Text('GPS Robotic Car', style: TextStyle(fontSize: 10, color: AppTheme.blueLight)),
                  ],
                ),
              ),
              Container(width: 1, height: 42, color: AppTheme.borderBlue),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Tooltip(
                  message: deviceName.isEmpty ? 'USB serial connection' : deviceName,
                  child: InkWell(
                  onTap: onUsbTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(connected ? Icons.link_rounded : Icons.link_off_rounded, color: linkColor, size: 17),
                          const SizedBox(width: 4),
                          Flexible(child: Text(connecting ? 'Connecting' : connected ? 'Connected' : 'Connect', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: linkColor))),
                        ]),
                        const SizedBox(height: 4),
                        Text(connected ? 'Phone ↔ Car' : 'Tap to connect', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
                ),
              ),
              const SizedBox(width: 7),
              Container(width: 1, height: 42, color: AppTheme.borderBlue),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Tooltip(
                  message: batteryAvailable ? 'Car battery: ${batteryVolts.toStringAsFixed(1)} V' : 'Car battery telemetry unavailable',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(_batteryIcon(batteryPct, batteryAvailable), size: 22, color: battColor),
                        const SizedBox(width: 3),
                        Flexible(child: Text(batteryAvailable ? '$batteryPct%' : '—', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: battColor))),
                      ]),
                      const SizedBox(height: 4),
                      const Text('Car Battery', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 8, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (lowBattAlert) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.redBg, border: Border.all(color: AppTheme.redBorder), borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [Icon(Icons.warning_amber_rounded, color: AppTheme.red, size: 15), SizedBox(width: 6), Expanded(child: Text('Low battery — charge the car soon', style: TextStyle(color: AppTheme.red, fontSize: 10, fontWeight: FontWeight.w600)))]),
            ),
          ],
        ],
      ),
    );
  }

  IconData _batteryIcon(int pct, bool linked) {
    if (!linked) return Icons.battery_unknown_rounded;
    if (pct < 15) return Icons.battery_alert_rounded;
    if (pct >= 50) return Icons.battery_full_rounded;
    return Icons.battery_std_rounded;
  }
}

BoxDecoration _panelDecoration() => BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF061B30), Color(0xFF041326)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderBlue, width: .8),
    );

class _CompactManualCard extends StatefulWidget {
  final bool enabled;
  final void Function(double speed, double turn) onDrive;
  final VoidCallback onStop;

  const _CompactManualCard({required this.enabled, required this.onDrive, required this.onStop});

  @override
  State<_CompactManualCard> createState() => _CompactManualCardState();
}

class _CompactManualCardState extends State<_CompactManualCard> {
  Timer? _repeat;
  String _held = '';
  int _speedLevel = 1;

  double get _speed => switch (_speedLevel) { 1 => .30, 2 => .60, _ => .90 };

  void _press(String direction) {
    if (!widget.enabled) return;
    if (_held == direction) return;
    setState(() => _held = direction);
    _send();
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_held.isNotEmpty && widget.enabled) {
        _send();
      } else {
        _repeat?.cancel();
      }
    });
  }

  void _send() {
    switch (_held) {
      case 'F': widget.onDrive(_speed, 0); break;
      case 'B': widget.onDrive(-_speed, 0); break;
      case 'L': widget.onDrive(0, -_speed); break;
      case 'R': widget.onDrive(0, _speed); break;
    }
  }

  void _release() {
    _repeat?.cancel();
    _repeat = null;
    if (_held.isNotEmpty) setState(() => _held = '');
    widget.onStop();
  }

  @override
  void didUpdateWidget(covariant _CompactManualCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) _release();
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  // The round pad is split by an X: top / bottom / left / right wedges.
  // The centre circle is the stop button (handled on tap-up).
  String? _directionAt(Offset p, double side) {
    final c = Offset(side / 2, side / 2);
    final d = p - c;
    if (d.distance < side * .17) return null;
    if (d.dx.abs() > d.dy.abs()) return d.dx > 0 ? 'R' : 'L';
    return d.dy > 0 ? 'B' : 'F';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: _panelDecoration(),
      child: Opacity(
        opacity: widget.enabled ? 1 : .55,
        child: LayoutBuilder(builder: (context, constraints) {
          final side = (constraints.maxWidth * .44).clamp(120.0, 170.0).toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.gamepad_rounded, color: AppTheme.skyBlue, size: 22),
                      SizedBox(width: 8),
                      Expanded(child: Text('Manual Control', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                    ]),
                    const SizedBox(height: 8),
                    Center(
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) {
                            final dir = _directionAt(d.localPosition, side);
                            if (dir != null) _press(dir);
                          },
                          onTapUp: (_) => _release(),
                          onTapCancel: _release,
                          child: CustomPaint(painter: _DpadPainter(held: _held)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    decoration: BoxDecoration(
                      color: AppTheme.bgDeep,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderBlue, width: .8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(children: [
                          Icon(Icons.speed_rounded, color: AppTheme.blueLight, size: 20),
                          SizedBox(width: 7),
                          Text('Speed', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                        ]),
                        const SizedBox(height: 8),
                        _speedRow(1, 'Slow'),
                        _speedRow(2, 'Medium'),
                        _speedRow(3, 'Fast'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _speedRow(int level, String name) {
    final selected = _speedLevel == level;
    return GestureDetector(
      onTap: widget.enabled ? () => setState(() => _speedLevel = level) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 34,
        margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          color: selected ? AppTheme.blue : AppTheme.bgBlue,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? AppTheme.cyan : AppTheme.borderBlue, width: selected ? 1.2 : .8),
        ),
        child: Row(children: [
          SizedBox(width: 30, child: Text('$level', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
          Container(width: 1, height: 16, color: AppTheme.textPrimary.withOpacity(.25)),
          const SizedBox(width: 8),
          Expanded(child: Text('($name)', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppTheme.textMuted))),
        ]),
      ),
    );
  }
}

class _DpadPainter extends CustomPainter {
  final String held;
  const _DpadPainter({required this.held});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;

    // Pressed wedge highlight.
    final wedgeStart = switch (held) { 'F' => -135.0, 'R' => -45.0, 'B' => 45.0, 'L' => 135.0, _ => null };

    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF05182C));
    if (wedgeStart != null) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        wedgeStart * 3.1415926535 / 180,
        3.1415926535 / 2,
        true,
        Paint()..color = AppTheme.blue.withOpacity(.55),
      );
    }
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..color = AppTheme.blue);

    // X dividers.
    final line = Paint()..color = const Color(0xFF020B18)..strokeWidth = 3..strokeCap = StrokeCap.round;
    final k = r * .7071;
    final inner = r * .24;
    final ik = inner * .7071;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        canvas.drawLine(c + Offset(sx * ik, sy * ik), c + Offset(sx * k, sy * k), line);
      }
    }

    // Arrows.
    final arrow = Paint()..color = AppTheme.blueLight;
    final d = r * .66;
    final t = r * .15;
    Path tri(Offset tip, Offset a, Offset b) => Path()..moveTo(tip.dx, tip.dy)..lineTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..close();
    canvas.drawPath(tri(c + Offset(0, -d - t), c + Offset(-t * 1.1, -d + t), c + Offset(t * 1.1, -d + t)), arrow);
    canvas.drawPath(tri(c + Offset(0, d + t), c + Offset(-t * 1.1, d - t), c + Offset(t * 1.1, d - t)), arrow);
    canvas.drawPath(tri(c + Offset(-d - t, 0), c + Offset(-d + t, -t * 1.1), c + Offset(-d + t, t * 1.1)), arrow);
    canvas.drawPath(tri(c + Offset(d + t, 0), c + Offset(d - t, -t * 1.1), c + Offset(d - t, t * 1.1)), arrow);

    // Centre stop button.
    canvas.drawCircle(c, inner + 6, Paint()..color = AppTheme.blue.withOpacity(.28)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(c, inner, Paint()..color = AppTheme.blue);
    canvas.drawCircle(c, inner, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..color = AppTheme.cyan);
  }

  @override
  bool shouldRepaint(covariant _DpadPainter old) => old.held != held;
}

class _QuickGpsCard extends StatelessWidget {
  final bool connected;
  final bool active;
  final LatLng? destination;
  final VoidCallback onSelectDestination;
  final VoidCallback onTravel;
  final VoidCallback onReturn;
  final VoidCallback onAdvanced;

  const _QuickGpsCard({
    required this.connected,
    required this.active,
    required this.destination,
    required this.onSelectDestination,
    required this.onTravel,
    required this.onReturn,
    required this.onAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = connected && active;
    final destText = destination == null
        ? 'Select Destination'
        : 'Destination set  ·  ${destination!.latitude.toStringAsFixed(4)}, ${destination!.longitude.toStringAsFixed(4)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            Icon(Icons.location_on_rounded, color: AppTheme.blueLight, size: 24),
            SizedBox(width: 8),
            Expanded(child: Text('GPS Navigation', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
          ]),
          const SizedBox(height: 8),
          InkWell(
            onTap: onSelectDestination,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgDeep,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderBlue, width: .8),
              ),
              child: Row(children: [
                const Icon(Icons.place_rounded, size: 20, color: AppTheme.blueLight),
                const SizedBox(width: 12),
                Expanded(child: Text(destText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textPrimary),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: enabled && destination != null ? onTravel : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.blue,
                disabledBackgroundColor: AppTheme.bgBlue,
                foregroundColor: Colors.white,
                disabledForegroundColor: AppTheme.textDim,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppTheme.cyan, width: .8)),
              ),
              child: const Row(children: [
                Icon(Icons.play_arrow_rounded, size: 26),
                Expanded(child: Center(child: Text('Travel to Destination', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)))),
                SizedBox(width: 26),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: enabled ? onReturn : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                disabledForegroundColor: AppTheme.textDim,
                side: const BorderSide(color: AppTheme.blue, width: 1.2),
                backgroundColor: AppTheme.bgDeep,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Row(children: [
                Icon(Icons.home_rounded, size: 22, color: AppTheme.blueLight),
                Expanded(child: Center(child: Text('Return to Phone', style: TextStyle(fontSize: 13)))),
                SizedBox(width: 22),
              ]),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: onAdvanced,
              style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted, padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 24), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Advanced GPS tools', style: TextStyle(fontSize: 10, decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyStopButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _EmergencyStopButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF5A1426), Color(0xFF3A0F1C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.red, width: 1.4),
              boxShadow: [BoxShadow(color: AppTheme.red.withOpacity(.12), blurRadius: 12)],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: ShapeDecoration(color: AppTheme.red, shape: StarBorder.polygon(sides: 8, pointRounding: .15)),
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
              const SizedBox(width: 12),
              const Text('EMERGENCY STOP', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: .3)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _BottomNavBar({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF031225),
        border: Border(top: BorderSide(color: AppTheme.borderBlue, width: .8)),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: const Color(0xFF031225),
          selectedItemColor: AppTheme.skyBlue,
          unselectedItemColor: AppTheme.textMuted,
          selectedFontSize: 0,
          unselectedFontSize: 0,
          iconSize: 26,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), label: 'Map'),
            BottomNavigationBarItem(icon: Icon(Icons.sensors_rounded), label: 'Sensors'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Logs'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class _SettingsLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color valueColor;
  const _SettingsLine({required this.icon, required this.title, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: AppTheme.bgDeep, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.borderColor)), child: Icon(icon, color: AppTheme.blueLight, size: 19)),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
        Text(value, style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
