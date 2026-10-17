import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'car_link.dart';
import 'usb_picker_dialog.dart';
import 'places_store.dart';
import 'gps_controller.dart';
import 'battery_card.dart';
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
  final _link   = CarLink();
  final _places = PlacesStore();
  late final GpsController _gps = GpsController(_link, _places);

  CarMode _selected = CarMode.manual;
  CarMode? _activeMode;

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

    // Stop any previous navigation/drive command before requiring an explicit
    // activation of the newly selected mode.
    if (_link.connected) _gps.stopAll();
    setState(() {
      _selected = mode;
      _activeMode = null;
    });
  }

  void _activateSelectedMode() {
    if (!_link.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect the car before activating a mode.')),
      );
      return;
    }

    // Always cancel any previous route first. Manual activation then sends a
    // zero-speed DRIVE command, which places the firmware in manual/DRIVE mode
    // without moving the motors. The GPS mode is armed here; GOTO/HOME starts
    // actual autonomous movement only after a destination is requested.
    _gps.stopAll();
    if (_selected == CarMode.manual) {
      _link.drive(0, 0);
    }

    final message = _selected == CarMode.manual
        ? 'Manual mode activated.'
        : 'Auto GPS mode armed. Choose a destination or return to the phone.';
    setState(() => _activeMode = _selected);
    _link.addExternalLog('ok', message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

  @override
  Widget build(BuildContext context) {
    final connected  = _link.connected;
    final connecting = _link.state == LinkState.connecting;

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              connected:  connected,
              connecting: connecting,
              carOnline:  _link.carOnline,
              deviceName: _link.deviceName,
              onUsbTap:   _toggleLink,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  BatteryCard(
                    pct:          _link.batteryPct,
                    volts:        _link.batteryVolts,
                    connected:    connected && _link.carOnline,
                    lowBattAlert: _link.lowBattAlert,
                  ),
                  const SizedBox(height: 10),
                  ModeCard(
                    current: _selected,
                    activeMode: _activeMode,
                    connected: connected,
                    onChanged: _onModeChanged,
                    onActivate: _activateSelectedMode,
                  ),
                  const SizedBox(height: 10),
                  LiveMapCard(link: _link, gps: _gps, gpsMode: _activeMode == CarMode.gps),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _modePanel(connected),
                  ),
                  const SizedBox(height: 10),
                  _StopButton(enabled: connected, onTap: _gps.stopAll),
                  const SizedBox(height: 10),
                  SensorCard(
                    front:     _link.distFront,
                    right:     _link.distRight,
                    back:      _link.distBack,
                    left:      _link.distLeft,
                    arc:       _link.arc,
                    connected: connected && _link.carOnline,
                  ),
                  const SizedBox(height: 10),
                  LogCard(logs: _link.logs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modePanel(bool connected) {
    if (!connected) {
      return const _ModePrompt(
        key: ValueKey('disconnected'),
        icon: Icons.usb_off,
        title: 'Connect your car',
        message: 'Connect the bridge by USB, then select and activate Manual or Auto mode.',
      );
    }

    if (_activeMode == null) {
      return const _ModePrompt(
        key: ValueKey('not-active'),
        icon: Icons.power_settings_new,
        title: 'Mode not activated',
        message: 'Choose Manual or Auto above, then press the Activate Mode button.',
      );
    }

    switch (_activeMode!) {
      case CarMode.manual:
        return ManualControlCard(
          key: const ValueKey('manual'),
          connected: connected,
          onDrive: _link.drive,
          onStop: _gps.stopAll,
        );
      case CarMode.gps:
        return GpsCard(
          key: const ValueKey('gps'),
          link: _link,
          places: _places,
          gps: _gps,
        );
    }
  }

}

class _ModePrompt extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ModePrompt({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.blueLight, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 5),
                Text(message, style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  height: 1.4,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Always visible: STOP cancels any mode (driving, GOTO, HOME).
class _StopButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _StopButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.redBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.redBorder, width: 1),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.stop_circle_outlined, color: AppTheme.red, size: 18),
            SizedBox(width: 8),
            Text('STOP',
                style: TextStyle(fontSize: 14, color: AppTheme.red,
                    fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ]),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool connected;
  final bool connecting;
  final bool carOnline;
  final String deviceName;
  final VoidCallback onUsbTap;

  const _TopBar({
    required this.connected, required this.connecting, required this.carOnline,
    required this.deviceName, required this.onUsbTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.smart_toy_outlined, color: AppTheme.blueLight, size: 18),
        const SizedBox(width: 8),
        const Text('GPS Robot Car',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary, letterSpacing: 0.5)),
        const Spacer(),
        if (connected) ...[
          Icon(Icons.directions_car,
              size: 14, color: carOnline ? AppTheme.green : AppTheme.yellow),
          const SizedBox(width: 3),
          Text(carOnline ? 'Car' : 'No car',
              style: TextStyle(
                  fontSize: 10,
                  color: carOnline ? AppTheme.green : AppTheme.yellow)),
          const SizedBox(width: 10),
        ],
        GestureDetector(
          onTap: onUsbTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: connected ? AppTheme.greenBg
                  : connecting ? AppTheme.bgBlueDark : AppTheme.redBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: connected ? AppTheme.greenBorder
                    : connecting ? AppTheme.blueDark : AppTheme.redBorder,
                width: 0.5,
              ),
            ),
            child: Row(children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? AppTheme.green
                      : connecting ? AppTheme.blueLight : AppTheme.red,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                connecting ? 'Connecting...'
                    : connected
                        ? deviceName.isNotEmpty ? deviceName : 'Connected'
                        : 'Plug in USB',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: connected ? AppTheme.green
                        : connecting ? AppTheme.blueLight : AppTheme.red),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
