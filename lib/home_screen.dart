import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'app_theme.dart';
import 'car_link.dart';
import 'usb_picker_dialog.dart';
import 'places_store.dart';
import 'gps_controller.dart';
import 'mode_card.dart';
import 'manual_control_card.dart';
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
    _message('Tap the map preview to open the interactive map and choose your destination.');
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

  void _onBottomNav(int index) {
    if (index == 4) {
      _openSettings();
      return;
    }

    if (index == 0 || index == 1) {
      final nextMode = index == 0 ? CarMode.manual : CarMode.gps;
      if (nextMode != _selected) _onModeChanged(nextMode);
      setState(() => _selectedNav = index);
      return;
    }

    setState(() => _selectedNav = index);
  }

  void _openSettings() {
    final previousNavIndex = _selectedNav;
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
      if (mounted && _selectedNav == 4) {
        setState(() => _selectedNav = previousNavIndex);
      }
    });
  }

  Future<void> _openInteractiveMap() async {
    final gpsModeActive = _selected == CarMode.gps && _activeMode == CarMode.gps;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (mapContext) => Scaffold(
          backgroundColor: AppTheme.bgPrimary,
          appBar: AppBar(
            backgroundColor: AppTheme.bgDeep,
            foregroundColor: AppTheme.textPrimary,
            title: Text(gpsModeActive ? 'GPS Interactive Map' : 'Live Map'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: gpsModeActive ? AppTheme.greenBg : AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: gpsModeActive ? AppTheme.greenBorder : AppTheme.borderBlue,
                      ),
                    ),
                    child: Text(
                      gpsModeActive
                          ? 'GPS ACTIVE'
                          : (_activeMode == CarMode.manual ? 'MANUAL ACTIVE' : 'VIEW ONLY'),
                      style: TextStyle(
                        color: gpsModeActive ? AppTheme.green : AppTheme.blueLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: LayoutBuilder(
                builder: (context, constraints) => LiveMapCard(
                  key: const ValueKey('fullscreen-interactive-map'),
                  link: _link,
                  gps: _gps,
                  gpsMode: gpsModeActive,
                  height: constraints.maxHeight,
                  showNavigationActions: gpsModeActive,
                  previewOnly: false,
                  selectedDestination: _selectedDestination,
                  onDestinationSelected: _onMapDestinationSelected,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _link.connected;
    final connecting = _link.state == LinkState.connecting;

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
            Expanded(child: _buildCurrentPage(connected)),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedNav,
        onTap: _onBottomNav,
      ),
    );
  }

  Widget _buildCurrentPage(bool connected) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final compactMapHeight = (screenHeight * .30).clamp(230.0, 330.0).toDouble();
    final gpsMapHeight = (screenHeight * .42).clamp(300.0, 460.0).toDouble();
    final contentPadding = const EdgeInsets.fromLTRB(12, 8, 12, 18);

    if (_selectedNav == 2) {
      return ListView(
        padding: contentPadding,
        children: [
          _PageHeading(
            title: 'Ultrasonic Sensors',
            subtitle: 'Live distance readings from all four sides',
            icon: Icons.sensors_rounded,
          ),
          const SizedBox(height: 12),
          SensorCard(
            front: _link.distFront,
            right: _link.distRight,
            back: _link.distBack,
            left: _link.distLeft,
            arc: _link.arc,
            connected: connected && _link.carOnline,
          ),
          const SizedBox(height: 12),
          _EmergencyStopButton(enabled: connected, onTap: _gps.stopAll),
        ],
      );
    }

    if (_selectedNav == 3) {
      return ListView(
        padding: contentPadding,
        children: [
          _PageHeading(
            title: 'Activity Logs',
            subtitle: 'Connection, mode and navigation events',
            icon: Icons.receipt_long_rounded,
          ),
          const SizedBox(height: 12),
          LogCard(logs: _link.logs),
        ],
      );
    }

    if (_selectedNav == 1) {
      return ListView(
        padding: contentPadding,
        children: [
          _ModePageBanner(
            mode: CarMode.gps,
            activeMode: _activeMode,
            connected: connected,
            onActivate: _activateSelectedMode,
          ),
          const SizedBox(height: 10),
          LiveMapCard(
            key: const ValueKey('gps-live-map'),
            link: _link,
            gps: _gps,
            gpsMode: _activeMode == CarMode.gps,
            height: gpsMapHeight,
            showNavigationActions: false,
            previewOnly: true,
            onPreviewTap: () => _openInteractiveMap(),
            selectedDestination: _selectedDestination,
            onDestinationSelected: _onMapDestinationSelected,
          ),
          const SizedBox(height: 10),
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
          SensorCard(
            front: _link.distFront,
            right: _link.distRight,
            back: _link.distBack,
            left: _link.distLeft,
            arc: _link.arc,
            connected: connected && _link.carOnline,
          ),
        ],
      );
    }

    // Manual page (default): map remains visible while the operator drives.
    return ListView(
      padding: contentPadding,
      children: [
        _ModePageBanner(
          mode: CarMode.manual,
          activeMode: _activeMode,
          connected: connected,
          onActivate: _activateSelectedMode,
        ),
        const SizedBox(height: 10),
        LiveMapCard(
          key: const ValueKey('manual-live-map'),
          link: _link,
          gps: _gps,
          gpsMode: false,
          height: compactMapHeight,
          showNavigationActions: false,
          previewOnly: true,
          onPreviewTap: () => _openInteractiveMap(),
        ),
        const SizedBox(height: 10),
        ManualControlCard(
          connected: connected && _activeMode == CarMode.manual,
          onDrive: _link.drive,
          onStop: _gps.stopAll,
        ),
        const SizedBox(height: 10),
        _EmergencyStopButton(enabled: connected, onTap: _gps.stopAll),
        const SizedBox(height: 10),
        SensorCard(
          front: _link.distFront,
          right: _link.distRight,
          back: _link.distBack,
          left: _link.distLeft,
          arc: _link.arc,
          connected: connected && _link.carOnline,
        ),
      ],
    );
  }

}

class _PageHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PageHeading({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF092846), Color(0xFF04162B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.borderBlue, width: .8),
      ),
      child: Row(children: [
        Icon(icon, size: 27, color: AppTheme.skyBlue),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: AppTheme.blueLight, fontSize: 11)),
        ])),
      ]),
    );
  }
}

class _ModePageBanner extends StatelessWidget {
  final CarMode mode;
  final CarMode? activeMode;
  final bool connected;
  final VoidCallback onActivate;

  const _ModePageBanner({
    required this.mode,
    required this.activeMode,
    required this.connected,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final isManual = mode == CarMode.manual;
    final active = activeMode == mode;
    final title = isManual ? 'Manual Mode' : 'GPS Autonomous Mode';
    final subtitle = isManual
        ? 'Drive the car directly using the directional controls.'
        : 'Choose a point on the map, then send the car to that destination.';
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isManual
              ? const [Color(0xFF073E93), Color(0xFF06223F)]
              : const [Color(0xFF07304A), Color(0xFF06192D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? AppTheme.green : AppTheme.cyan, width: active ? 1.3 : .9),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(color: AppTheme.bgDeep, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppTheme.borderBlue)),
            child: Icon(isManual ? Icons.gamepad_rounded : Icons.location_on_rounded, color: AppTheme.skyBlue, size: 28),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: AppTheme.blueLight, fontSize: 10, height: 1.2)),
          ])),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: active ? AppTheme.greenBg : AppTheme.bgDeep, borderRadius: BorderRadius.circular(9), border: Border.all(color: active ? AppTheme.greenBorder : AppTheme.borderColor)),
            child: Text(active ? 'ACTIVE' : 'READY', style: TextStyle(color: active ? AppTheme.green : AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 11),
        SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            onPressed: connected && !active ? onActivate : null,
            icon: Icon(active ? Icons.check_circle_rounded : Icons.power_settings_new_rounded, size: 18),
            label: Text(active ? '${isManual ? 'MANUAL' : 'GPS'} MODE ACTIVE' : 'ACTIVATE ${isManual ? 'MANUAL' : 'GPS'} MODE', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: .4)),
            style: ElevatedButton.styleFrom(
              backgroundColor: active ? AppTheme.greenBg : AppTheme.blue,
              disabledBackgroundColor: active ? AppTheme.greenBg : AppTheme.bgDeep,
              foregroundColor: active ? AppTheme.green : Colors.white,
              disabledForegroundColor: active ? AppTheme.green : AppTheme.textMuted,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11), side: BorderSide(color: active ? AppTheme.greenBorder : AppTheme.borderBlue)),
            ),
          ),
        ),
      ]),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppTheme.bgDeep, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppTheme.borderBlue)),
                child: const Icon(Icons.smart_toy_rounded, color: AppTheme.blueLight, size: 29),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF061B30), Color(0xFF041326)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderBlue, width: .8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.gamepad_rounded, color: AppTheme.skyBlue, size: 19),
            const SizedBox(width: 5),
            const Expanded(child: Text('Manual Control', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
          ]),
          const SizedBox(height: 9),
          Opacity(
            opacity: widget.enabled ? 1 : .42,
            child: LayoutBuilder(builder: (context, constraints) {
              final dpadSide = (constraints.maxWidth * .62).clamp(88.0, 150.0).toDouble();
              final speedWidth = (constraints.maxWidth - dpadSide - 6).clamp(40.0, 82.0).toDouble();
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: dpadSide,
                    height: dpadSide,
                    child: GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      crossAxisCount: 3,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                      children: [
                        const SizedBox.shrink(),
                        _directionButton('F', Icons.keyboard_arrow_up_rounded),
                        const SizedBox.shrink(),
                        _directionButton('L', Icons.keyboard_arrow_left_rounded),
                        GestureDetector(
                          onTap: _release,
                          child: Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.blue, border: Border.all(color: AppTheme.cyan, width: 2), boxShadow: [BoxShadow(color: AppTheme.blue.withOpacity(.30), blurRadius: 8)]),
                            child: const Icon(Icons.stop_rounded, color: Colors.white, size: 17),
                          ),
                        ),
                        _directionButton('R', Icons.keyboard_arrow_right_rounded),
                        const SizedBox.shrink(),
                        _directionButton('B', Icons.keyboard_arrow_down_rounded),
                        const SizedBox.shrink(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: speedWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.speed_rounded, color: AppTheme.blueLight, size: 17),
                        const SizedBox(height: 3),
                        const Text('SPEED', style: TextStyle(fontSize: 8, letterSpacing: .5, color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        for (final level in [1, 2, 3])
                          GestureDetector(
                            onTap: widget.enabled ? () => setState(() => _speedLevel = level) : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 3),
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(
                                color: _speedLevel == level ? AppTheme.blue : AppTheme.bgDeep,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: _speedLevel == level ? AppTheme.cyan : AppTheme.borderColor, width: .7),
                              ),
                              child: Text('$level', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _speedLevel == level ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.w800)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 7),
          _StatePill(text: widget.enabled ? 'Manual mode active' : 'Activate Manual mode above', active: widget.enabled),
        ],
      ),
    );
  }

  Widget _directionButton(String dir, IconData icon) {
    final down = _held == dir;
    return GestureDetector(
      onTapDown: (_) => _press(dir),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: down ? AppTheme.blue : const Color(0xFF092744),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: down ? AppTheme.cyan : AppTheme.borderBlue, width: down ? 1.6 : .8),
        ),
        child: Icon(icon, color: widget.enabled ? AppTheme.blueLight : AppTheme.textDim, size: 24),
      ),
    );
  }
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
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF061B30), Color(0xFF041326)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderBlue, width: .8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            Icon(Icons.location_on_rounded, color: AppTheme.blueLight, size: 19),
            SizedBox(width: 5),
            Expanded(child: Text('GPS Navigation', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
          ]),
          const SizedBox(height: 9),
          OutlinedButton(
            onPressed: onSelectDestination,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 39),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              foregroundColor: AppTheme.blueLight,
              side: const BorderSide(color: AppTheme.borderBlue),
              backgroundColor: AppTheme.bgDeep,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Row(children: [
              const Icon(Icons.place_rounded, size: 18),
              const SizedBox(width: 5),
              Expanded(child: Text(destination == null ? 'Select Destination' : 'Destination set ✓', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right_rounded, size: 17),
            ]),
          ),
          if (destination != null) ...[
            const SizedBox(height: 4),
            Text('${destination!.latitude.toStringAsFixed(4)}, ${destination!.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 8, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 7),
          SizedBox(
            height: 39,
            child: ElevatedButton.icon(
              onPressed: enabled && destination != null ? onTravel : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Travel to Destination', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.blue,
                disabledBackgroundColor: AppTheme.bgDeep,
                foregroundColor: Colors.white,
                disabledForegroundColor: AppTheme.textDim,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppTheme.borderBlue)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 37,
            child: OutlinedButton.icon(
              onPressed: enabled ? onReturn : null,
              icon: const Icon(Icons.home_rounded, size: 17),
              label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Return to Phone', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.blueLight,
                disabledForegroundColor: AppTheme.textDim,
                side: const BorderSide(color: AppTheme.borderBlue),
                backgroundColor: AppTheme.bgDeep,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: onAdvanced,
              style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), minimumSize: const Size(0, 22), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Advanced GPS tools', style: TextStyle(fontSize: 9, decoration: TextDecoration.underline)),
            ),
          ),
          const SizedBox(height: 3),
          _StatePill(text: active ? 'GPS mode active' : 'Activate GPS mode above', active: active),
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  final String text;
  final bool active;
  const _StatePill({required this.text, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppTheme.greenBg : AppTheme.bgDeep,
        border: Border.all(color: active ? AppTheme.greenBorder : AppTheme.borderColor, width: .7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(active ? Icons.check_circle_rounded : Icons.lock_outline_rounded, size: 11, color: active ? AppTheme.green : AppTheme.textDim),
        const SizedBox(width: 4),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, color: active ? AppTheme.green : AppTheme.textMuted, fontWeight: FontWeight.w600))),
      ]),
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
      opacity: enabled ? 1 : .45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4A1122), Color(0xFF2B0D1A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.red, width: 1.5),
              boxShadow: [BoxShadow(color: AppTheme.red.withOpacity(.12), blurRadius: 12)],
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.stop_circle_rounded, color: AppTheme.red, size: 25),
              SizedBox(width: 10),
              Text('EMERGENCY STOP', style: TextStyle(color: Color(0xFFFFB3C0), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: .6)),
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
          selectedFontSize: 10,
          unselectedFontSize: 10,
          iconSize: 22,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.gamepad_rounded), label: 'Manual'),
            BottomNavigationBarItem(icon: Icon(Icons.navigation_rounded), label: 'GPS'),
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
