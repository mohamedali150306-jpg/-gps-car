import 'package:flutter/material.dart';
import 'app_theme.dart';

// Car firmware: 2S pack, 6.0 V = 0 %, 8.4 V = 100 %, low-battery stop at 6.4 V (about 17 %)
const int _kBattCritical = 17;

class BatteryCard extends StatefulWidget {
  final int              pct;
  final double           volts;
  final bool             connected;
  final bool             lowBattAlert;

  const BatteryCard({
    super.key,
    required this.pct,
    required this.volts,
    required this.connected,
    required this.lowBattAlert,
  });

  @override
  State<BatteryCard> createState() => _BatteryCardState();
}

class _BatteryCardState extends State<BatteryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double>   _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ── Threshold mirrors config.h BATTERY_LOW_V (6.4 V) ─────────────────────
  bool get _isCritical =>
      widget.connected && widget.pct <= _kBattCritical;

  Color get _fillColor {
    if (!widget.connected) return AppTheme.borderColor;
    if (_isCritical)             return AppTheme.red;
    if (widget.pct > 50)         return AppTheme.green;
    return AppTheme.yellow;
  }

  String get _statusText {
    if (!widget.connected) return '—';
    if (_isCritical)       return 'Critical';
    if (widget.pct > 50)   return 'Normal';
    return 'Low';
  }

  Color get _statusColor {
    if (!widget.connected) return AppTheme.textMuted;
    if (_isCritical)       return AppTheme.red;
    if (widget.pct > 50)   return AppTheme.green;
    return AppTheme.yellow;
  }

  @override
  Widget build(BuildContext context) {
    final displayPct = widget.connected ? widget.pct   : 0;
    final displayV   = widget.connected ? widget.volts : 0.0;

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        // Border pulses red when critical, static otherwise
        final borderColor = _isCritical
            ? Color.lerp(
                AppTheme.red.withOpacity(0.3),
                AppTheme.red,
                _glow.value,
              )!
            : AppTheme.borderColor;

        final shadowColor = _isCritical
            ? AppTheme.red.withOpacity(_glow.value * 0.45)
            : Colors.transparent;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isCritical
                ? Color.lerp(AppTheme.bgCard,
                    AppTheme.red.withOpacity(0.08), _glow.value)
                : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: _isCritical ? 1.5 : 0.5),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: label + percentage
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                            _isCritical
                                ? Icons.battery_alert
                                : Icons.battery_charging_full,
                            size: 13,
                            color: _isCritical ? AppTheme.red : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text('Battery',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _isCritical
                                      ? AppTheme.red
                                      : AppTheme.textMuted)),
                        ]),
                        const SizedBox(height: 2),
                        Text('$displayPct%',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                            color: _isCritical
                                ? AppTheme.red
                                : AppTheme.textPrimary,
                          )),
                      ],
                    ),
                  ),
                  // Right: volts + status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${displayV.toStringAsFixed(1)} V',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(_statusText,
                          style:
                              TextStyle(fontSize: 11, color: _statusColor)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: widget.connected ? displayPct / 100 : 0,
                  minHeight: 8,
                  backgroundColor: AppTheme.borderColor,
                  valueColor: AlwaysStoppedAnimation(_fillColor),
                ),
              ),
              // Critical warning banner — shown when the car sends E,low_battery
              if (widget.lowBattAlert) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.redBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.redBorder, width: 0.5),
                  ),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14,
                        color: AppTheme.red
                            .withOpacity(0.4 + 0.6 * _glow.value)),
                    const SizedBox(width: 6),
                    const Text(
                      'Battery critical — charge immediately',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.red,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
