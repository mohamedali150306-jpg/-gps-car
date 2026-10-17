import 'package:flutter/material.dart';
import 'app_theme.dart';

class LogCard extends StatelessWidget {
  final List<String> logs;
  const LogCard({super.key, required this.logs});

  Color _color(String line) {
    if (line.startsWith('✓')) return AppTheme.green;
    if (line.startsWith('⚠')) return AppTheme.yellow;
    return AppTheme.blueLight;
  }

  @override
  Widget build(BuildContext context) {
    final display = logs.isEmpty
        ? ['› Plug in the bridge ESP32 with the USB cable...']
        : logs.reversed.take(4).toList().reversed.toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: display.map((line) => Text(
          line,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: _color(line),
            height: 1.7,
          ),
        )).toList(),
      ),
    );
  }
}
