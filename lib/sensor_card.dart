import 'package:flutter/material.dart';
import 'app_theme.dart';

// The dashboard highlights the sensors in red when the measured distance
// is under 10 cm, matching the RoboCar visual specification.
const int _kDangerCm = 10;

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
          Row(
            children: [
              const Icon(Icons.sensors_rounded, color: AppTheme.blueLight, size: 19),
              const SizedBox(width: 7),
              const Expanded(child: Text('Ultrasonic Sensors', style: TextStyle(fontSize: 13, color: AppTheme.blueLight, fontWeight: FontWeight.w800))),
              Text('4 SENSORS', style: TextStyle(fontSize: 9, color: AppTheme.textMuted, letterSpacing: .7, fontWeight: FontWeight.w700)),
            ],
          ),
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
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              iconColor: AppTheme.blueLight,
              collapsedIconColor: AppTheme.textMuted,
              title: const Text('Front sweep details', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              children: [
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
                        child: Text(v == null ? '—' : '$v', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w500)),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _color(int? v) {
    if (v == null) return AppTheme.textDim;
    if (v < _kDangerCm) return AppTheme.red;
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
    final danger = value != null && value! < _kDangerCm;
    final color  = danger ? AppTheme.red : AppTheme.green;
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
