import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The D-pad now drives the GPS robot car with  DRIVE speed,turn
//   speed: -1..1 (negative = reverse)    turn: -1..1 (positive = right)
// The firmware stops the car if no DRIVE arrives for 1 s, so while a button
// is held the command is repeated every 100 ms. Releasing sends STOP.
// ─────────────────────────────────────────────────────────────────────────────

class ManualControlCard extends StatefulWidget {
  final bool connected;
  final void Function(double speed, double turn) onDrive;
  final VoidCallback onStop;

  const ManualControlCard({
    super.key,
    required this.connected,
    required this.onDrive,
    required this.onStop,
  });

  @override
  State<ManualControlCard> createState() => _ManualControlCardState();
}

class _ManualControlCardState extends State<ManualControlCard> {
  int    _speed  = 5;          // level 1..9
  String _active = '';
  Timer? _repeatTimer;

  // Direction labels for the center indicator
  static const Map<String, String> _dirLabel = {
    'F': '↑',  'B': '↓',  'L': '←',  'R': '→',
    'G': '↖',  'I': '↗',  'H': '↙',  'J': '↘',
  };

  // Direction → (speed multiplier, turn multiplier). Turn > 0 = right.
  // Reverse diagonals use the opposite turn sign so the rear swings to the
  // side the button points to.
  static const Map<String, List<double>> _dirVec = {
    'F': [ 1.0,  0.0],
    'B': [-1.0,  0.0],
    'L': [ 0.0, -1.0],
    'R': [ 0.0,  1.0],
    'G': [ 1.0, -0.5],
    'I': [ 1.0,  0.5],
    'H': [-1.0,  0.5],
    'J': [-1.0, -0.5],
  };

  double get _level => _speed / 9.0;   // 1/9 .. 1.0

  void _sendActive() {
    final v = _dirVec[_active];
    if (v == null || !widget.connected) return;
    widget.onDrive(v[0] * _level, v[1] * _level);
  }

  void _press(String dir) {
    if (!widget.connected) return;
    if (_active == dir) return;
    setState(() => _active = dir);
    _sendActive();
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_active.isNotEmpty && widget.connected) {
        _sendActive();
      } else {
        _repeatTimer?.cancel();
      }
    });
  }

  void _release() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    if (_active.isEmpty) return;
    setState(() => _active = '');
    widget.onStop();
  }

  void _changeSpeed(int delta) {
    // The repeat timer picks up the new level on its next tick.
    setState(() => _speed = (_speed + delta).clamp(1, 9));
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

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
          // ── Header ─────────────────────────────────────────────────────
          Row(
            children: [
              const Text('DRIVE CONTROL',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textDim,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              // Diagonal mode badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.bgBlue,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderBlue, width: 0.5),
                ),
                child: const Text('DRIVE',
                    style: TextStyle(
                        fontSize: 9,
                        color: AppTheme.blueLight,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── D-pad + Knob row ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── 8-direction D-pad (3×3 grid) ──────────────────────────
              SizedBox(
                width: 174,
                height: 174,
                child: GridView.count(
                  crossAxisCount: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  children: [
                    // Row 1: FwdLeft  |  Forward  |  FwdRight
                    _DpadBtn(
                      label: '↖', dir: 'G',
                      isDiagonal: true,
                      active: _active,
                      onPress: _press, onRelease: _release,
                    ),
                    _DpadBtn(
                      icon: Icons.keyboard_arrow_up, dir: 'F',
                      active: _active,
                      onPress: _press, onRelease: _release,
                    ),
                    _DpadBtn(
                      label: '↗', dir: 'I',
                      isDiagonal: true,
                      active: _active,
                      onPress: _press, onRelease: _release,
                    ),

                    // Row 2: Left  |  Stop (center)  |  Right
                    _DpadBtn(
                      icon: Icons.keyboard_arrow_left, dir: 'L',
                      active: _active,
                      onPress: _press, onRelease: _release,
                    ),
                    // ── Centre stop / direction indicator ──────────────
                    _StopCenter(
                      label: _active.isEmpty ? '■' : (_dirLabel[_active] ?? '■'),
                      isMoving: _active.isNotEmpty,
                      onTap: _release,
                    ),
                    _DpadBtn(
                      icon: Icons.keyboard_arrow_right, dir: 'R',
                      active: _active,
                      onPress: _press, onRelease: _release,
                    ),

                    // Row 3: BwdLeft  |  Backward  |  BwdRight
                    _DpadBtn(
                      label: '↙', dir: 'H',
                      isDiagonal: true,
                      active: _active,
                      onPress: _press, onRelease: _release,
                    ),
                    _DpadBtn(
                      icon: Icons.keyboard_arrow_down, dir: 'B',
                      active: _active,
                      onPress: _press, onRelease: _release,
                    ),
                    _DpadBtn(
                      label: '↘', dir: 'J',
                      isDiagonal: true,
                      active: _active,
                      onPress: _press, onRelease: _release,
                    ),
                  ],
                ),
              ),

              // ── Speed knob ─────────────────────────────────────────────
              _CircularKnob(
                speed: _speed,
                onUp:   () => _changeSpeed(1),
                onDown: () => _changeSpeed(-1),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Legend row ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(AppTheme.blueLight, 'Straight / spin'),
              const SizedBox(width: 16),
              _legendDot(AppTheme.skyBlue.withOpacity(0.7), 'Curve'),
            ],
          ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(
          width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(fontSize: 9, color: AppTheme.textDim)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  D-PAD BUTTON  (cardinal and diagonal, visually distinct)
// ══════════════════════════════════════════════════════════════════════════════
class _DpadBtn extends StatefulWidget {
  final String   dir;
  final String   active;
  final bool     isDiagonal;
  final IconData? icon;
  final String?  label;       // arrow glyph for diagonal buttons
  final ValueChanged<String> onPress;
  final VoidCallback onRelease;

  const _DpadBtn({
    required this.dir,
    required this.active,
    required this.onPress,
    required this.onRelease,
    this.isDiagonal = false,
    this.icon,
    this.label,
  }) : assert(icon != null || label != null,
            '_DpadBtn needs either icon or label');

  @override
  State<_DpadBtn> createState() => _DpadBtnState();
}

class _DpadBtnState extends State<_DpadBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 60));
    _scale = Tween<double>(begin: 1.0, end: 0.82).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.active == widget.dir;

    // Diagonal buttons get a slightly different tint so they're visually
    // distinguishable from cardinal buttons at a glance
    final Color idleColor = widget.isDiagonal
        ? const Color(0xFF151F30)   // slightly cooler than bgBlue
        : AppTheme.bgBlue;
    final Color activeBg  = widget.isDiagonal
        ? const Color(0xFF1A2E4A)
        : AppTheme.blueDark;
    final Color activeBdr = widget.isDiagonal
        ? AppTheme.skyBlue
        : AppTheme.blueLight;
    final Color idleBdr   = widget.isDiagonal
        ? const Color(0xFF1A3050)
        : AppTheme.borderBlue;
    final Color iconColor = widget.isDiagonal
        ? AppTheme.skyBlue
        : AppTheme.blueLight;

    return GestureDetector(
      onTapDown:        (_) { _ctrl.forward(); widget.onPress(widget.dir); },
      onTapUp:          (_) { _ctrl.reverse(); widget.onRelease(); },
      onTapCancel:          () { _ctrl.reverse(); widget.onRelease(); },
      onLongPressStart: (_) { _ctrl.forward(); widget.onPress(widget.dir); },
      onLongPressEnd:   (_) { _ctrl.reverse(); widget.onRelease(); },
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          decoration: BoxDecoration(
            color: isActive ? activeBg : idleColor,
            // Diagonal buttons get rounded corners; cardinal gets sharper
            borderRadius: BorderRadius.circular(widget.isDiagonal ? 12 : 9),
            border: Border.all(
              color: isActive ? activeBdr : idleBdr,
              width: isActive ? 1.0 : 0.5,
            ),
            boxShadow: isActive
                ? [BoxShadow(
                    color: (widget.isDiagonal
                            ? AppTheme.skyBlue
                            : AppTheme.blue)
                        .withOpacity(0.35),
                    blurRadius: 8,
                    spreadRadius: 1)]
                : [],
          ),
          child: Center(
            child: widget.icon != null
                ? Icon(widget.icon, color: iconColor, size: 22)
                : Text(
                    widget.label!,
                    style: TextStyle(
                        fontSize: 18,
                        color: iconColor,
                        fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CENTRE STOP BUTTON
// ══════════════════════════════════════════════════════════════════════════════
class _StopCenter extends StatelessWidget {
  final String    label;
  final bool      isMoving;
  final VoidCallback onTap;

  const _StopCenter({
    required this.label,
    required this.isMoving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: isMoving
              ? AppTheme.redBg
              : AppTheme.bgDeep,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMoving ? AppTheme.redBorder : AppTheme.borderColor,
            width: isMoving ? 1.0 : 0.5,
          ),
          boxShadow: isMoving
              ? [BoxShadow(
                  color: AppTheme.red.withOpacity(0.25),
                  blurRadius: 8)]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                fontSize: 18,
                color: isMoving ? AppTheme.red : AppTheme.textDim,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SPEED KNOB  (unchanged from original)
// ══════════════════════════════════════════════════════════════════════════════
class _CircularKnob extends StatelessWidget {
  final int speed;
  final VoidCallback onUp;
  final VoidCallback onDown;
  const _CircularKnob(
      {required this.speed, required this.onUp, required this.onDown});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Speed',
            style: TextStyle(fontSize: 11, color: AppTheme.textDim)),
        const SizedBox(height: 8),
        _AnimatedBtn(icon: Icons.add, onTap: onUp),
        const SizedBox(height: 8),
        CustomPaint(
          size: const Size(80, 80),
          painter: _KnobPainter(speed: speed),
          child: SizedBox(
            width: 80,
            height: 80,
            child: Center(
              child: Text('$speed',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _AnimatedBtn(icon: Icons.remove, onTap: onDown),
      ],
    );
  }
}

class _KnobPainter extends CustomPainter {
  final int speed;
  const _KnobPainter({required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final center    = Offset(size.width / 2, size.height / 2);
    final radius    = size.width / 2 - 6;
    const start     = 135 * math.pi / 180;
    const sweepAll  = 270 * math.pi / 180;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        start, sweepAll, false,
        Paint()
          ..color      = AppTheme.borderColor
          ..strokeWidth = 6
          ..style      = PaintingStyle.stroke
          ..strokeCap  = StrokeCap.round);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        start, sweepAll * (speed / 9), false,
        Paint()
          ..color      = AppTheme.blue
          ..strokeWidth = 6
          ..style      = PaintingStyle.stroke
          ..strokeCap  = StrokeCap.round);

    canvas.drawCircle(center, radius - 8,
        Paint()..color = AppTheme.bgDeep..style = PaintingStyle.fill);
    canvas.drawCircle(center, radius - 8,
        Paint()
          ..color      = AppTheme.borderBlue
          ..strokeWidth = 0.5
          ..style      = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.speed != speed;
}

class _AnimatedBtn extends StatefulWidget {
  final IconData    icon;
  final VoidCallback onTap;
  const _AnimatedBtn({required this.icon, required this.onTap});

  @override
  State<_AnimatedBtn> createState() => _AnimatedBtnState();
}

class _AnimatedBtnState extends State<_AnimatedBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 60));
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) { _ctrl.forward(); widget.onTap(); },
      onTapUp:     (_) => _ctrl.reverse(),
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.bgBlue,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderBlue, width: 0.5),
          ),
          child: Icon(widget.icon, color: AppTheme.blueLight, size: 18),
        ),
      ),
    );
  }
}
