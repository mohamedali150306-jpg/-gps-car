import 'package:flutter/material.dart';
import 'app_theme.dart';

// The dashboard highlights the sensors in red when the measured distance
// is under 10 cm, matching the RoboCar visual specification.
const int _kDangerCm = 10;

class SensorCard extends StatefulWidget {
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
  State<SensorCard> createState() => _SensorCardState();
}

class _SensorCardState extends State<SensorCard> {
  bool _showSweep = false;

  @override
  Widget build(BuildContext context) {
    final connected = widget.connected;
    final arc = widget.arc;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF061B30), Color(0xFF041326)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderBlue, width: .8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tapping the header shows / hides the front sweep values.
          InkWell(
            onTap: () => setState(() => _showSweep = !_showSweep),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
              child: Row(
                children: [
                  const Icon(Icons.sensors_rounded, color: AppTheme.blueLight, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Ultrasonic Sensors', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
                  const Text('4 Sensors', style: TextStyle(fontSize: 11, color: AppTheme.cyan, fontWeight: FontWeight.w600)),
                  Icon(_showSweep ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: AppTheme.cyan),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(children: [
            Expanded(child: _SensorCell(label: 'Front', value: connected ? widget.front : null)),
            const SizedBox(width: 6),
            Expanded(child: _SensorCell(label: 'Right', value: connected ? widget.right : null)),
            const SizedBox(width: 6),
            Expanded(child: _SensorCell(label: 'Back', value: connected ? widget.back : null)),
            const SizedBox(width: 6),
            Expanded(child: _SensorCell(label: 'Left', value: connected ? widget.left : null)),
          ]),
          if (_showSweep) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 4),
              child: Text('Front sweep (-45° … +45°)', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ),
            Row(
              children: List.generate(arc.length, (i) {
                final v = connected ? arc[i] : null;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i == arc.length - 1 ? 0 : 4),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.bgDeep,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor, width: 0.5),
                    ),
                    child: Text(v == null ? '—' : '$v', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: _color(v), fontWeight: FontWeight.w500)),
                  ),
                );
              }),
            ),
          ],
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
  final String label;
  final int?   value;

  const _SensorCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final danger = value != null && value! < _kDangerCm;
    final color  = danger ? AppTheme.red : (value != null ? AppTheme.green : AppTheme.textDim);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: danger ? AppTheme.redBg : AppTheme.bgDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: danger ? AppTheme.red : (value != null ? AppTheme.greenBorder : AppTheme.borderColor),
          width: danger ? 1.2 : .8,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1.6)),
              child: Icon(Icons.sensors_rounded, color: color, size: 14),
            ),
            const SizedBox(width: 5),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
                const SizedBox(height: 1),
                Text(value != null ? '$value cm' : '— cm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
            if (danger) ...[
              const SizedBox(width: 3),
              const Icon(Icons.warning_rounded, color: AppTheme.red, size: 15),
            ],
          ],
        ),
      ),
    );
  }
}
