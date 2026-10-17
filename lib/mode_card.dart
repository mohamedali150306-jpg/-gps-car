import 'package:flutter/material.dart';
import 'app_theme.dart';

// The selector chooses a requested mode. The separate activation button makes
// the selection explicit before manual controls or GPS navigation are enabled.
enum CarMode { manual, gps }

class ModeCard extends StatelessWidget {
  final CarMode current;
  final CarMode? activeMode;
  final bool connected;
  final ValueChanged<CarMode> onChanged;
  final VoidCallback onActivate;

  const ModeCard({
    super.key,
    required this.current,
    required this.activeMode,
    required this.connected,
    required this.onChanged,
    required this.onActivate,
  });

  String get _modeName => current == CarMode.manual ? 'Manual' : 'Auto (GPS)';
  bool get _isActive => activeMode == current;

  @override
  Widget build(BuildContext context) {
    final buttonLabel = _isActive
        ? (current == CarMode.manual ? 'MANUAL MODE ACTIVE' : 'AUTO MODE ARMED')
        : 'ACTIVATE ${current == CarMode.manual ? 'MANUAL' : 'AUTO'} MODE';

    final helperText = !connected
        ? 'Connect the car before activating a mode.'
        : _isActive
            ? current == CarMode.manual
                ? 'Manual mode is active. Hold a direction control to drive.'
                : 'Auto mode is armed. Choose a destination and press Travel, or use Return to Phone.'
            : 'Selected: $_modeName. Press Activate Mode to apply your selection.';

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
          const Text(
            'OPERATING MODE',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textDim,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ModeBtn(
                label: 'Manual',
                icon: Icons.sports_esports_outlined,
                selected: current == CarMode.manual,
                active: activeMode == CarMode.manual,
                onTap: () => onChanged(CarMode.manual),
              ),
              const SizedBox(width: 8),
              _ModeBtn(
                label: 'Auto (GPS)',
                icon: Icons.my_location,
                selected: current == CarMode.gps,
                active: activeMode == CarMode.gps,
                onTap: () => onChanged(CarMode.gps),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: connected && !_isActive ? onActivate : null,
              icon: Icon(_isActive ? Icons.check_circle : Icons.power_settings_new),
              label: Text(buttonLabel, textAlign: TextAlign.center),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isActive ? AppTheme.greenBg : AppTheme.blueDark,
                foregroundColor: _isActive ? AppTheme.green : Colors.white,
                disabledBackgroundColor: _isActive ? AppTheme.greenBg : AppTheme.bgDeep,
                disabledForegroundColor: _isActive ? AppTheme.green : AppTheme.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: _isActive ? AppTheme.greenBorder : AppTheme.blueDark,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 10,
              height: 1.35,
              color: _isActive ? AppTheme.green : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  @override
  State<_ModeBtn> createState() => _ModeBtnState();
}

class _ModeBtnState extends State<_ModeBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            decoration: BoxDecoration(
              color: widget.active
                  ? AppTheme.greenBg
                  : widget.selected
                      ? AppTheme.bgBlueDark
                      : AppTheme.bgDeep,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.active
                    ? AppTheme.greenBorder
                    : widget.selected
                        ? AppTheme.blueDark
                        : AppTheme.borderColor,
                width: widget.active ? 1.5 : 0.5,
              ),
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: AppTheme.green.withOpacity(0.22),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : widget.selected
                      ? [
                          BoxShadow(
                            color: AppTheme.blueLight.withOpacity(0.16),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: widget.active
                      ? AppTheme.green
                      : widget.selected
                          ? AppTheme.blueLight
                          : AppTheme.textMuted,
                ),
                const SizedBox(height: 5),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.active
                        ? AppTheme.green
                        : widget.selected
                            ? AppTheme.blueLight
                            : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
