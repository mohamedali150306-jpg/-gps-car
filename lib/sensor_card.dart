import 'package:flutter/material.dart';
import 'app_theme.dart';

// Distances come from the car in cm; null = no fresh reading.
// Firmware limits: stop at 30 cm (OBSTACLE_CM), phone warning at 60 cm (WARNING_CM).
const int _kStopCm = 30;
const int _kWarnCm = 60;

class SensorCard extends StatelessWidget {
  final int? front;          // nearest point of the swept front arc
  final int? right;
  final int? back;
  final int? left;
  final List<int?> arc;      // 7 values, -45° … +45°
  final bool connected;

  const SensorCard({
    super.key,
    required this.front,
    required this.right,
    required this.back,
    required this.left,
    required this.arc,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ULTRASONIC SENSORS (cm)',
              style: TextStyle(fontSize: 10, color: AppTheme.textDim,
                  letterSpacing: 1.2, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _SensorCell(
                icon: Icons.arrow_upward, label: 'Front',
                value: connected ? front : null)),
            const SizedBox(width: 6),
            Expanded(child: _SensorCell(
                icon: Icons.arrow_forward, label: 'Right',
                value: connected ? right : null)),
            const SizedBox(width: 6),
            Expanded(child: _SensorCell(
                icon: Icons.arrow_downward, label: 'Back',
                value: connected ? back : null)),
            const SizedBox(width: 6),
            Expanded(child: _SensorCell(
                icon: Icons.arrow_back, label: 'Left',
                value: connected ? left : null)),
          ]),
          const SizedBox(height: 10),
          const Text('FRONT SWEEP  (−45° … +45°)',
              style: TextStyle(fontSize: 9, color: AppTheme.textDim,
                  letterSpacing: 1.0, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            children: List.generate(arc.length, (i) {
              final v = connected ? arc[i] : null;
              final c = _color(v);
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == arc.length - 1 ? 0 : 4),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor, width: 0.5),
                  ),
                  child: Text(v == null ? '—' : '$v',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: c,
                          fontWeight: FontWeight.w500)),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  static Color _color(int? v) {
    if (v == null) return AppTheme.textDim;
    if (v < _kStopCm) return AppTheme.red;
    if (v < _kWarnCm) return AppTheme.yellow;
    return AppTheme.textPrimary;
  }
}

class _SensorCell extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int?     value;

  const _SensorCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final danger = value != null && value! < _kStopCm;
    final warn   = value != null && value! < _kWarnCm;
    final color  = danger ? AppTheme.red : warn ? AppTheme.yellow : AppTheme.skyBlue;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: danger ? AppTheme.redBorder : AppTheme.borderColor,
            width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          const SizedBox(height: 2),
          Text(
            value != null ? '$value' : '—',
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w500,
              color: value != null ? (danger ? AppTheme.red : AppTheme.textPrimary)
                                   : AppTheme.textDim,
            ),
          ),
          const Text('cm',
              style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
