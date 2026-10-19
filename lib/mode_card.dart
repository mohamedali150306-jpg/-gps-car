import 'package:flutter/material.dart';
import 'app_theme.dart';

enum CarMode { manual, gps }

/// Mode selector styled like the two large mode tiles in the RoboCar concept.
/// Selecting a mode does not activate it; activation stays explicit and separate.
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

  bool get _isActive => activeMode == current;

  @override
  Widget build(BuildContext context) {
    final activationLabel = _isActive ? 'Mode Active' : 'Activate Mode';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ModeTile(
                title: 'Manual Mode',
                subtitle: 'Control the car directly',
                icon: Icons.gamepad_rounded,
                selected: current == CarMode.manual,
                active: activeMode == CarMode.manual,
                onTap: () => onChanged(CarMode.manual),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeTile(
                title: 'GPS Mode',
                subtitle: 'Navigate to a destination',
                icon: Icons.location_on_rounded,
                selected: current == CarMode.gps,
                active: activeMode == CarMode.gps,
                onTap: () => onChanged(CarMode.gps),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 46,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: connected && !_isActive
                  ? [BoxShadow(color: AppTheme.blue.withOpacity(.18), blurRadius: 12)]
                  : const [],
            ),
            child: ElevatedButton.icon(
              onPressed: connected && !_isActive ? onActivate : null,
              icon: Icon(_isActive ? Icons.check_circle_rounded : Icons.power_settings_new_rounded, size: 24),
              label: Text(activationLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isActive ? AppTheme.greenBg : AppTheme.blue,
                foregroundColor: _isActive ? AppTheme.green : Colors.white,
                disabledBackgroundColor: _isActive ? AppTheme.greenBg : AppTheme.bgDeep,
                disabledForegroundColor: _isActive ? AppTheme.green : AppTheme.textMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _isActive ? AppTheme.greenBorder : AppTheme.borderBlue),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppTheme.cyan : AppTheme.borderBlue;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 83),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [Color(0xFF0646AC), Color(0xFF087FF2)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : const LinearGradient(colors: [Color(0xFF071A2E), Color(0xFF061629)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: border, width: selected ? 1.6 : .8),
            boxShadow: selected
                ? [BoxShadow(color: AppTheme.blue.withOpacity(.20), blurRadius: 14, spreadRadius: 1)]
                : const [],
          ),
          child: Row(
            children: [
              Icon(icon, size: 28, color: selected ? Colors.white : AppTheme.blueLight),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, height: 1.15, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
