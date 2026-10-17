import 'package:flutter/material.dart';
import 'app_theme.dart';

// Two ways to drive: by hand (D-pad) or automatically by GPS (Home / saved places).
enum CarMode { manual, gps }

class ModeCard extends StatelessWidget {
  final CarMode current;
  final ValueChanged<CarMode> onChanged;

  const ModeCard({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
          const Text('OPERATING MODE',
              style: TextStyle(fontSize: 10, color: AppTheme.textDim,
                  letterSpacing: 1.2, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(children: [
            _ModeBtn(
              label: 'Manual',
              icon: Icons.sports_esports_outlined,
              selected: current == CarMode.manual,
              active: false,
              onTap: () => onChanged(CarMode.manual),
            ),
            const SizedBox(width: 6),
            _ModeBtn(
              label: 'GPS',
              icon: Icons.my_location,
              selected: current == CarMode.gps,
              active: false,
              onTap: () => onChanged(CarMode.gps),
            ),
          ]),
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
    required this.label, required this.icon,
    required this.selected, required this.active, required this.onTap,
  });

  @override
  State<_ModeBtn> createState() => _ModeBtnState();
}

class _ModeBtnState extends State<_ModeBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown:   (_) => _ctrl.forward(),
        onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
        onTapCancel: ()  => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: widget.active ? AppTheme.greenBg
                  : widget.selected ? AppTheme.bgBlueDark
                  : AppTheme.bgDeep,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.active ? AppTheme.greenBorder
                    : widget.selected ? AppTheme.blueDark
                    : AppTheme.borderColor,
                width: widget.active ? 1.5 : 0.5,
              ),
              boxShadow: widget.active
                  ? [BoxShadow(color: AppTheme.green.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)]
                  : widget.selected
                      ? [BoxShadow(color: AppTheme.blueLight.withOpacity(0.2), blurRadius: 6, spreadRadius: 1)]
                      : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(clipBehavior: Clip.none, children: [
                  Icon(widget.icon, size: 20,
                      color: widget.active ? AppTheme.green
                          : widget.selected ? AppTheme.blueLight
                          : AppTheme.textMuted),
                  if (widget.active)
                    Positioned(
                      right: -4, top: -4,
                      child: Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                            color: AppTheme.green, shape: BoxShape.circle),
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(widget.label,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w500,
                        color: widget.active ? AppTheme.green
                            : widget.selected ? AppTheme.blueLight
                            : AppTheme.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
