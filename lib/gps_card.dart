import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'car_link.dart';
import 'gps_controller.dart';
import 'places_store.dart';

/// Automatic GPS mode: Home button, saved places, type a name and go.
class GpsCard extends StatefulWidget {
  final CarLink link;
  final PlacesStore places;
  final GpsController gps;

  const GpsCard({
    super.key,
    required this.link,
    required this.places,
    required this.gps,
  });

  @override
  State<GpsCard> createState() => _GpsCardState();
}

class _GpsCardState extends State<GpsCard> {
  final _name = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  CarLink get _l => widget.link;
  GpsController get _g => widget.gps;

  // ── actions ───────────────────────────────────────────────────────────────
  void _goTyped() {
    final p = widget.places.find(_name.text);
    if (p == null) {
      setState(() => _error = _name.text.trim().isEmpty
          ? 'Type a place name'
          : 'No saved place called "${_name.text.trim()}"');
      return;
    }
    setState(() => _error = '');
    _g.goToPlace(p);
  }

  Future<void> _savePhone() async {
    final n = _name.text.trim();
    if (n.isEmpty) { setState(() => _error = 'Type a name first'); return; }
    final pos = await _g.phonePosition();
    if (pos == null) return;
    await widget.places.add(Place(n, pos.latitude, pos.longitude));
    _l.addExternalLog('ok', 'Saved "$n" (phone position)');
    setState(() => _error = '');
  }

  Future<void> _saveCar() async {
    final n = _name.text.trim();
    if (n.isEmpty) { setState(() => _error = 'Type a name first'); return; }
    if (!_l.hasFix) { setState(() => _error = 'The car has no GPS fix yet'); return; }
    await widget.places.add(Place(n, _l.carLat, _l.carLon));
    _l.addExternalLog('ok', 'Saved "$n" (car position)');
    setState(() => _error = '');
  }

  // ── status text ───────────────────────────────────────────────────────────
  String get _status {
    if (!_l.connected) return 'Not connected';
    final d = _g.distanceToTarget;
    final dist = d == null ? '' : ' — ${d.round()} m';
    switch (_l.mode) {
      case 'GOTO': return 'Driving to ${_g.targetName}$dist';
      case 'HOME': return 'Coming to you$dist';
      case 'DRIVE': return 'Manual driving';
      default:
        return _g.hasTarget ? 'Stopped — ${_g.targetName}$dist' : 'Idle';
    }
  }

  Color get _statusColor {
    if (!_l.connected) return AppTheme.textMuted;
    if (_l.mode == 'GOTO' || _l.mode == 'HOME') return AppTheme.green;
    return AppTheme.textPrimary;
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_l, widget.places, _g]),
      builder: (context, _) {
        final err = _error.isNotEmpty ? _error : _g.message;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GPS NAVIGATION',
                  style: TextStyle(fontSize: 10, color: AppTheme.textDim,
                      letterSpacing: 1.2, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),

              // car GPS status
              _infoRow(),
              const SizedBox(height: 8),
              Text(_status,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                      color: _statusColor)),
              const SizedBox(height: 12),

              // Home
              _bigBtn(
                label: _g.homing ? 'Coming home… (tap Stop to cancel)' : 'Home — come to my phone',
                icon: Icons.home_rounded,
                color: AppTheme.blueLight,
                bg: AppTheme.bgBlue,
                border: AppTheme.borderBlue,
                onTap: _l.connected ? _g.goHome : null,
              ),
              const SizedBox(height: 14),

              // Go to / save
              const Text('PLACE NAME',
                  style: TextStyle(fontSize: 10, color: AppTheme.textDim,
                      letterSpacing: 1.2, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _goTyped(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'e.g. Library',
                  hintStyle: const TextStyle(color: AppTheme.textDim, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.bgDeep,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppTheme.borderColor, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppTheme.borderColor, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.blue, width: 1),
                  ),
                ),
              ),
              if (err.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(err,
                    style: const TextStyle(fontSize: 11, color: AppTheme.red)),
              ],
              const SizedBox(height: 8),
              _bigBtn(
                label: 'Go to this place',
                icon: Icons.navigation_rounded,
                color: AppTheme.green,
                bg: AppTheme.greenBg,
                border: AppTheme.greenBorder,
                onTap: _l.connected ? _goTyped : null,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _smallBtn('Save phone position',
                    Icons.smartphone, _savePhone)),
                const SizedBox(width: 8),
                Expanded(child: _smallBtn('Save car position',
                    Icons.directions_car_outlined, _saveCar)),
              ]),

              // saved list
              const SizedBox(height: 14),
              const Text('SAVED PLACES',
                  style: TextStyle(fontSize: 10, color: AppTheme.textDim,
                      letterSpacing: 1.2, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              if (widget.places.places.isEmpty)
                const Text('No saved places yet.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
              else
                ...widget.places.places.map(_placeTile),

              // compass
              const SizedBox(height: 12),
              _smallBtn('Calibrate compass (rotate the car slowly for 15 s)',
                  Icons.explore_outlined,
                  _l.connected ? _l.calibrate : null),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow() {
    String v(String s) => _l.connected ? s : '—';
    return Row(children: [
      _chip(Icons.satellite_alt, v(_l.hasFix ? 'Fix • ${_l.sats} sat' : 'No fix'),
          _l.connected && _l.hasFix ? AppTheme.green : AppTheme.yellow),
      const SizedBox(width: 6),
      _chip(Icons.explore, v('${_l.heading.round()}°'), AppTheme.skyBlue),
    ]);
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: color)),
      ]),
    );
  }

  Widget _placeTile(Place p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppTheme.bgDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.place_outlined, size: 16, color: AppTheme.blueLight),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500)),
            Text('${p.lat.toStringAsFixed(5)}, ${p.lon.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ]),
        ),
        IconButton(
          tooltip: 'Go',
          onPressed: _l.connected ? () => _g.goToPlace(p) : null,
          icon: const Icon(Icons.navigation_rounded, size: 18),
          color: AppTheme.green,
          disabledColor: AppTheme.textDim,
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: () => widget.places.remove(p.name),
          icon: const Icon(Icons.delete_outline, size: 18),
          color: AppTheme.textMuted,
        ),
      ]),
    );
  }

  Widget _bigBtn({
    required String label, required IconData icon,
    required Color color, required Color bg, required Color border,
    required VoidCallback? onTap,
  }) {
    final on = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: on ? 1 : 0.4,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 0.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: color,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _smallBtn(String label, IconData icon, VoidCallback? onTap) {
    final on = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: on ? 1 : 0.4,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: AppTheme.bgDeep,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppTheme.borderColor, width: 0.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: AppTheme.blueLight),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.blueLight,
                      fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
      ),
    );
  }
}
