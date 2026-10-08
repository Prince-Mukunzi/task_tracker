import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sprung/sprung.dart';

abstract class Anim {
  static const Duration micro = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration dramatic = Duration(milliseconds: 900);

  static final Curve spring = Sprung(20);
  static final Curve snapBack = Sprung(28);
  static const Curve fade = Curves.easeOut;
  static const Curve settle = Curves.decelerate;
}


// ============================================================
// TILT CARD — 3D perspective transform driven by pointer
// Apple-style depth on press. Uses Matrix4 perspective.
// ============================================================
class TiltCard extends StatefulWidget {
  final Widget child;
  final double maxAngle;
  final double liftScale;

  const TiltCard({
    super.key,
    required this.child,
    this.maxAngle = 0.025,
    this.liftScale = 1.015,
  });

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard>
    with SingleTickerProviderStateMixin {
  double _rotX = 0;
  double _rotY = 0;
  double _lift = 1.0;
  late AnimationController _resetCtrl;
  double _fromX = 0, _fromY = 0, _fromLift = 1.0;

  @override
  void initState() {
    super.initState();
    _resetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        final t = Sprung(16).transform(_resetCtrl.value);
        setState(() {
          _rotX = lerpDouble(_fromX, 0, t)!;
          _rotY = lerpDouble(_fromY, 0, t)!;
          _lift = lerpDouble(_fromLift, 1.0, t)!;
        });
      });
  }

  @override
  void dispose() {
    _resetCtrl.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) {
    _resetCtrl.stop();
    final box = context.findRenderObject() as RenderBox;
    _updateTilt(box, e.localPosition);
  }

  void _onPointerMove(PointerMoveEvent e) {
    final box = context.findRenderObject() as RenderBox;
    _updateTilt(box, e.localPosition);
  }

  void _updateTilt(RenderBox box, Offset local) {
    final w = box.size.width;
    final h = box.size.height;
    final nx = (local.dx / w - 0.5) * 2;
    final ny = (local.dy / h - 0.5) * 2;
    setState(() {
      _rotY = nx * widget.maxAngle;
      _rotX = -ny * widget.maxAngle;
      _lift = widget.liftScale;
    });
  }

  void _onPointerUp(PointerUpEvent e) => _springBack();
  void _onPointerCancel(PointerCancelEvent e) => _springBack();

  void _springBack() {
    _fromX = _rotX;
    _fromY = _rotY;
    _fromLift = _lift;
    _resetCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: RepaintBoundary(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(_rotX)
            ..rotateY(_rotY)
            ..scale(_lift, _lift, 1.0),
          child: widget.child,
        ),
      ),
    );
  }
}


// ============================================================
// DIGIT ROLLER — slot-machine style per-digit counter
// Like Linear's animated numbers. Each digit column scrolls
// independently with spring physics.
// ============================================================
class DigitRoller extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  const DigitRoller({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    final digits = value.toString().split('');
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final digitHeight = effectiveStyle.fontSize! * (effectiveStyle.height ?? 1.2);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (prefix.isNotEmpty)
          Text(prefix, style: effectiveStyle),
        ...List.generate(digits.length, (i) {
          final digit = int.parse(digits[i]);
          return SizedBox(
            height: digitHeight,
            child: ClipRect(
              child: _SingleDigitRoll(
                digit: digit,
                style: effectiveStyle,
                height: digitHeight,
                duration: duration,
                delay: Duration(milliseconds: 40 * i),
              ),
            ),
          );
        }),
        if (suffix.isNotEmpty)
          Text(suffix, style: effectiveStyle),
      ],
    );
  }
}

class _SingleDigitRoll extends StatefulWidget {
  final int digit;
  final TextStyle style;
  final double height;
  final Duration duration;
  final Duration delay;

  const _SingleDigitRoll({
    required this.digit,
    required this.style,
    required this.height,
    required this.duration,
    required this.delay,
  });

  @override
  State<_SingleDigitRoll> createState() => _SingleDigitRollState();
}

class _SingleDigitRollState extends State<_SingleDigitRoll>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _position;
  int _prevDigit = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _position = Tween<double>(
      begin: 0,
      end: widget.digit.toDouble(),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Sprung(14)));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(_SingleDigitRoll old) {
    super.didUpdateWidget(old);
    if (old.digit != widget.digit) {
      _prevDigit = old.digit;
      _position = Tween<double>(
        begin: _prevDigit.toDouble(),
        end: widget.digit.toDouble(),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Sprung(14)));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: widget.height,
              child: Opacity(opacity: 0, child: Text('0', style: widget.style)),
            ),
            Positioned(
              top: -_position.value * widget.height,
              left: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(10, (i) => SizedBox(
                  height: widget.height,
                  child: Text('$i', style: widget.style),
                )),
              ),
            ),
          ],
        );
      },
    );
  }
}


// ============================================================
// STATUS ORB — animated gradient ring that rotates
// Replaces static status dots with living, breathing orbs.
// ============================================================
class StatusOrb extends StatefulWidget {
  final Color color;
  final double size;
  final bool breathing;

  const StatusOrb({
    super.key,
    required this.color,
    this.size = 8,
    this.breathing = true,
  });

  @override
  State<StatusOrb> createState() => _StatusOrbState();
}

class _StatusOrbState extends State<StatusOrb>
    with TickerProviderStateMixin {
  late AnimationController _spinCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_spinCtrl, _pulseCtrl]),
      builder: (context, _) {
        final pulse = widget.breathing
            ? 0.5 + 0.5 * math.sin(_pulseCtrl.value * math.pi)
            : 1.0;
        return SizedBox(
          width: widget.size * 2.5,
          height: widget.size * 2.5,
          child: CustomPaint(
            painter: _OrbPainter(
              color: widget.color,
              coreSize: widget.size,
              rotation: _spinCtrl.value * 2 * math.pi,
              glowIntensity: pulse,
            ),
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final Color color;
  final double coreSize;
  final double rotation;
  final double glowIntensity;

  _OrbPainter({
    required this.color,
    required this.coreSize,
    required this.rotation,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = coreSize / 2;

    canvas.drawCircle(
      center,
      r * 2.2,
      Paint()
        ..color = color.withValues(alpha: 0.08 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final ringR = r * 1.6;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 0; i < 3; i++) {
      final angle = rotation + (i * 2 * math.pi / 3);
      final arcStart = angle;
      final arcSweep = math.pi * 0.5;
      final alpha = (0.15 + 0.15 * glowIntensity).clamp(0.0, 1.0);

      ringPaint.color = color.withValues(alpha: alpha);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringR),
        arcStart,
        arcSweep,
        false,
        ringPaint,
      );
    }

    canvas.drawCircle(
      center,
      r,
      Paint()..color = color.withValues(alpha: 0.8 + 0.2 * glowIntensity),
    );

    canvas.drawCircle(
      Offset(center.dx - r * 0.25, center.dy - r * 0.25),
      r * 0.3,
      Paint()..color = Colors.white.withValues(alpha: 0.4 * glowIntensity),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.rotation != rotation || old.glowIntensity != glowIntensity || old.color != color;
}


// ============================================================
// ELASTIC PROGRESS BAR — overshoots then settles
// ============================================================
class ElasticProgressBar extends StatefulWidget {
  final double progress;
  final Color color;
  final Color trackColor;
  final double height;
  final Duration duration;

  const ElasticProgressBar({
    super.key,
    required this.progress,
    this.color = const Color(0xFF30D158),
    this.trackColor = const Color(0xFF2C2C2E),
    this.height = 3,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<ElasticProgressBar> createState() => _ElasticProgressBarState();
}

class _ElasticProgressBarState extends State<ElasticProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: 0, end: widget.progress)
        .animate(CurvedAnimation(parent: _ctrl, curve: Sprung(12)));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(ElasticProgressBar old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _anim = Tween<double>(begin: _anim.value, end: widget.progress)
          .animate(CurvedAnimation(parent: _ctrl, curve: Sprung(12)));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: SizedBox(
            height: widget.height,
            child: CustomPaint(
              painter: _ElasticBarPainter(
                progress: _anim.value.clamp(0.0, 1.0),
                color: widget.color,
                trackColor: widget.trackColor,
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }
}

class _ElasticBarPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _ElasticBarPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = trackColor,
    );

    final barWidth = size.width * progress;
    if (barWidth > 0) {
      final gradient = LinearGradient(
        colors: [
          color,
          Color.lerp(color, Colors.white, 0.2)!,
        ],
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, barWidth, size.height),
        Paint()..shader = gradient.createShader(
          Rect.fromLTWH(0, 0, barWidth, size.height),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_ElasticBarPainter old) => old.progress != progress;
}


// ============================================================
// SHIMMER SWEEP — continuous gradient sweep across child
// Like iOS loading skeletons, but usable on any widget.
// ============================================================
class ShimmerSweep extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration period;

  const ShimmerSweep({
    super.key,
    required this.child,
    this.baseColor = const Color(0x00FFFFFF),
    this.highlightColor = const Color(0x33FFFFFF),
    this.period = const Duration(milliseconds: 2500),
  });

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final t = _ctrl.value;
            return LinearGradient(
              begin: Alignment(-1.5 + 3.0 * t, -0.3),
              end: Alignment(-0.5 + 3.0 * t, 0.3),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}


// ============================================================
// SONAR RING — expanding ring animation from center
// Used on active status indicators for "broadcasting" effect.
// ============================================================
class SonarRing extends StatefulWidget {
  final Color color;
  final double size;
  final Duration period;

  const SonarRing({
    super.key,
    required this.color,
    this.size = 40,
    this.period = const Duration(milliseconds: 2000),
  });

  @override
  State<SonarRing> createState() => _SonarRingState();
}

class _SonarRingState extends State<SonarRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _SonarPainter(
              progress: _ctrl.value,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

class _SonarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SonarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final p = (progress + i / 3.0) % 1.0;
      final r = maxR * p;
      final alpha = (1.0 - p) * 0.3;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * (1.0 - p),
      );
    }
  }

  @override
  bool shouldRepaint(_SonarPainter old) => old.progress != progress;
}


// ============================================================
// CRYSTALLISE — particle shatter on task completion
// Fragments fly outward from center with rotation + fade.
// ============================================================
class Crystallise extends StatefulWidget {
  final bool trigger;
  final Color color;
  final double size;

  const Crystallise({
    super.key,
    required this.trigger,
    this.color = const Color(0xFFFFFFFF),
    this.size = 60,
  });

  @override
  State<Crystallise> createState() => _CrystalliseState();
}

class _CrystalliseState extends State<Crystallise>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Fragment> _fragments;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _generateFragments();
  }

  void _generateFragments() {
    _fragments = List.generate(14, (_) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = 0.5 + _rng.nextDouble() * 1.0;
      final rotSpeed = (_rng.nextDouble() - 0.5) * 4;
      final size = 2.0 + _rng.nextDouble() * 4.0;
      return _Fragment(angle, speed, rotSpeed, size);
    });
  }

  @override
  void didUpdateWidget(Crystallise old) {
    super.didUpdateWidget(old);
    if (widget.trigger && !old.trigger) {
      _generateFragments();
      _ctrl.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        if (!_ctrl.isAnimating && _ctrl.value == 0) {
          return SizedBox(width: widget.size, height: widget.size);
        }
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _CrystallisePainter(
              progress: _ctrl.value,
              color: widget.color,
              fragments: _fragments,
              maxRadius: widget.size / 2,
            ),
          ),
        );
      },
    );
  }
}

class _Fragment {
  final double angle;
  final double speed;
  final double rotSpeed;
  final double size;
  _Fragment(this.angle, this.speed, this.rotSpeed, this.size);
}

class _CrystallisePainter extends CustomPainter {
  final double progress;
  final Color color;
  final List<_Fragment> fragments;
  final double maxRadius;

  _CrystallisePainter({
    required this.progress,
    required this.color,
    required this.fragments,
    required this.maxRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final easedP = Curves.easeOutCubic.transform(progress);
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    for (final f in fragments) {
      final dist = maxRadius * easedP * f.speed;
      final x = center.dx + math.cos(f.angle) * dist;
      final y = center.dy + math.sin(f.angle) * dist;
      final rot = f.rotSpeed * progress;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: f.size * (1.0 - progress * 0.5),
        height: f.size * 0.6 * (1.0 - progress * 0.3),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.8)
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CrystallisePainter old) => old.progress != progress;
}


// ============================================================
// FADE SLIDE IN
// ============================================================
class FadeSlideIn extends StatelessWidget {
  final Animation<double> parentAnimation;
  final Interval interval;
  final Offset slideFrom;
  final Widget child;

  const FadeSlideIn({
    super.key,
    required this.parentAnimation,
    required this.interval,
    this.slideFrom = const Offset(0, 24),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: parentAnimation,
      curve: interval,
    );

    final slide = Tween<Offset>(
      begin: slideFrom,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: parentAnimation,
      curve: Interval(interval.begin, interval.end, curve: Anim.spring),
    ));

    return AnimatedBuilder(
      animation: parentAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: fade.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: slide.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}


// ============================================================
// SLIVER STAGGER ITEM
// Auto-animates each list item on first build with a
// per-index stagger delay. Fade + slide, spring physics.
// ============================================================
class SliverStaggerItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration staggerDelay;
  final Duration duration;
  final Offset slideFrom;

  const SliverStaggerItem({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 450),
    this.slideFrom = const Offset(0, 16),
  });

  @override
  State<SliverStaggerItem> createState() => _SliverStaggerItemState();
}

class _SliverStaggerItemState extends State<SliverStaggerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: widget.slideFrom, end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Sprung(20)));

    final delay = widget.staggerDelay * widget.index;
    Future.delayed(delay, () {
      if (mounted && !_hasAnimated) {
        _hasAnimated = true;
        _ctrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return RepaintBoundary(
          child: Opacity(
            opacity: _opacity.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: _slide.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}


// ============================================================
// ANIMATED COUNTER
// Smoothly animates between integer values with an optional
// scale bounce when the value increases.
// ============================================================
class AnimatedCounter extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final String suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.prefix = '',
    this.suffix = '',
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with TickerProviderStateMixin {
  late AnimationController _countCtrl;
  late AnimationController _bounceCtrl;
  late Animation<double> _countAnim;
  late Animation<double> _scaleAnim;
  int _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _oldValue = 0;
    _countCtrl = AnimationController(vsync: this, duration: widget.duration);
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _countAnim = Tween<double>(begin: 0, end: widget.value.toDouble())
        .animate(CurvedAnimation(parent: _countCtrl, curve: Curves.easeOutCubic));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.0)
        .animate(CurvedAnimation(parent: _bounceCtrl, curve: Sprung(24)));
  }

  void _animateTo(int newValue) {
    final from = _countAnim.value;
    _countAnim = Tween<double>(begin: from, end: newValue.toDouble())
        .animate(CurvedAnimation(parent: _countCtrl, curve: Curves.easeOutCubic));
    _countCtrl.forward(from: 0);

    if (newValue > _oldValue) {
      _scaleAnim = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 60),
      ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOutCubic));
      _bounceCtrl.forward(from: 0);
    }
    _oldValue = newValue;
  }

  @override
  void didUpdateWidget(AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _animateTo(widget.value);
    }
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_countCtrl, _bounceCtrl]),
      builder: (context, _) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: Text(
            '${widget.prefix}${_countAnim.value.toInt()}${widget.suffix}',
            style: widget.style,
          ),
        );
      },
    );
  }
}


// ============================================================
// POP IN
// ============================================================
class PopIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
  });

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Sprung(16)),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}


// ============================================================
// BREATHING
// Subtle continuous scale oscillation that makes elements
// feel alive even when idle. Like a heartbeat.
// ============================================================
class Breathing extends StatefulWidget {
  final Widget child;
  final double intensity;
  final Duration period;

  const Breathing({
    super.key,
    required this.child,
    this.intensity = 0.03,
    this.period = const Duration(milliseconds: 3000),
  });

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = math.sin(_ctrl.value * math.pi);
        return Transform.scale(
          scale: 1.0 + widget.intensity * t,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}


// ============================================================
// FLOATING
// Gentle vertical drift. Each instance can have a phase
// offset so grouped items don't move in lockstep.
// ============================================================
class Floating extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;
  final double phase;

  const Floating({
    super.key,
    required this.child,
    this.amplitude = 6.0,
    this.period = const Duration(milliseconds: 4000),
    this.phase = 0.0,
  });

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final y = math.sin((_ctrl.value + widget.phase) * 2 * math.pi) *
            widget.amplitude;
        return Transform.translate(offset: Offset(0, y), child: child);
      },
      child: widget.child,
    );
  }
}


// ============================================================
// GLOW PULSE
// A radial glow that fades in and out continuously.
// Wraps behind a child widget via a Stack.
// ============================================================
class GlowPulse extends StatefulWidget {
  final Widget child;
  final Color color;
  final double radius;
  final Duration period;

  const GlowPulse({
    super.key,
    required this.child,
    this.color = const Color(0xFFFFFFFF),
    this.radius = 40,
    this.period = const Duration(milliseconds: 2500),
  });

  @override
  State<GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<GlowPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = math.sin(_ctrl.value * math.pi);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.radius * 2,
              height: widget.radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.12 * t),
                    blurRadius: widget.radius * (0.5 + 0.5 * t),
                    spreadRadius: widget.radius * 0.1 * t,
                  ),
                ],
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}


// ============================================================
// STAGGERED COLUMN
// Animates children in with a cascade delay.
// ============================================================
class StaggeredColumn extends StatefulWidget {
  final List<Widget> children;
  final Duration stagger;
  final Duration itemDuration;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  const StaggeredColumn({
    super.key,
    required this.children,
    this.stagger = const Duration(milliseconds: 80),
    this.itemDuration = const Duration(milliseconds: 500),
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  State<StaggeredColumn> createState() => _StaggeredColumnState();
}

class _StaggeredColumnState extends State<StaggeredColumn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    final totalMs = widget.stagger.inMilliseconds * widget.children.length +
        widget.itemDuration.inMilliseconds;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _ctrl.duration!.inMilliseconds;
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      mainAxisSize: widget.mainAxisSize,
      children: List.generate(widget.children.length, (i) {
        final startMs = i * widget.stagger.inMilliseconds;
        final endMs = startMs + widget.itemDuration.inMilliseconds;
        final start = (startMs / total).clamp(0.0, 1.0);
        final end = (endMs / total).clamp(0.0, 1.0);

        return FadeSlideIn(
          parentAnimation: _ctrl,
          interval: Interval(start, end),
          slideFrom: const Offset(0, 16),
          child: widget.children[i],
        );
      }),
    );
  }
}


// ============================================================
// iOS SHEET ROUTE
// ============================================================
class SheetRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SheetRoute({required this.page})
      : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (context, animation, secondaryAnimation) {
            return _DismissibleSheet(
              animation: animation,
              child: page,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final scaleOut = Tween<double>(begin: 1.0, end: 0.94).animate(
              CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut),
            );
            final radiusOut = Tween<double>(begin: 0.0, end: 12.0).animate(
              CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut),
            );
            return AnimatedBuilder(
              animation: secondaryAnimation,
              builder: (context, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(radiusOut.value),
                  child: ScaleTransition(scale: scaleOut, child: child),
                );
              },
            );
          },
        );
}

class _DismissibleSheet extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;

  const _DismissibleSheet({required this.animation, required this.child});

  @override
  State<_DismissibleSheet> createState() => _DismissibleSheetState();
}

class _DismissibleSheetState extends State<_DismissibleSheet> {
  double _dragOffset = 0;
  bool _isDragging = false;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0 || _dragOffset > 0) {
      setState(() {
        _isDragging = true;
        _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, double.infinity);
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_dragOffset > 120 || velocity > 800) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isDragging = false;
        _dragOffset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    final slide = Tween<Offset>(
      begin: Offset(0, MediaQuery.of(context).size.height),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: widget.animation,
      curve: Sprung(18),
    ));

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        double translateY = slide.value.dy;
        if (_isDragging) {
          translateY = _dragOffset;
        }

        final dismissProgress = _isDragging
            ? (_dragOffset / 400).clamp(0.0, 1.0)
            : 0.0;

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: 1.0 - dismissProgress * 0.04,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Container(
          margin: EdgeInsets.only(top: topPadding + 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
              ),
              Expanded(child: Material(
                type: MaterialType.transparency,
                child: widget.child,
              )),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================
// iOS PUSH ROUTE
// ============================================================
class IOSPushRoute<T> extends CupertinoPageRoute<T> {
  IOSPushRoute({required Widget page})
      : super(builder: (context) => page);
}


// ============================================================
// PULSING DOT
// ============================================================
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({super.key, required this.color, this.size = 8});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = math.sin(_ctrl.value * math.pi);
        return Transform.scale(
          scale: 0.6 + 0.4 * t,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5 * t),
                  blurRadius: 8 * t,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


// ============================================================
// ANIMATED PROGRESS RING
// ============================================================
class AnimatedProgressRing extends StatefulWidget {
  final double progress;
  final Color color;
  final Color trackColor;
  final double size;
  final double strokeWidth;
  final Widget? child;

  const AnimatedProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.trackColor = const Color(0xFF2C2C2E),
    this.size = 40,
    this.strokeWidth = 3,
    this.child,
  });

  @override
  State<AnimatedProgressRing> createState() => _AnimatedProgressRingState();
}

class _AnimatedProgressRingState extends State<AnimatedProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _anim = Tween<double>(begin: _anim.value, end: widget.progress).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: _anim.value,
              color: widget.color,
              trackColor: widget.trackColor,
              strokeWidth: widget.strokeWidth,
            ),
            child: Center(child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect, -math.pi / 2, 2 * math.pi * progress, false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}


// ============================================================
// FROSTED GLASS CONTAINER
// ============================================================
class FrostedContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;

  const FrostedContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
    this.blur = 20,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}


// ============================================================
// TICK BURST
// Radiating lines from centre on completion events.
// ============================================================
class TickBurst extends StatefulWidget {
  final bool trigger;
  final Color color;
  final double size;

  const TickBurst({
    super.key,
    required this.trigger,
    this.color = const Color(0xFF30D158),
    this.size = 80,
  });

  @override
  State<TickBurst> createState() => _TickBurstState();
}

class _TickBurstState extends State<TickBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.trigger) _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(TickBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger && !old.trigger) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        if (_ctrl.value == 0) return SizedBox(width: widget.size, height: widget.size);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _BurstPainter(
              progress: _ctrl.value,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final lineCount = 12;

    for (int i = 0; i < lineCount; i++) {
      final angle = (i / lineCount) * 2 * math.pi;
      final innerR = maxRadius * 0.3 * progress;
      final outerR = maxRadius * (0.4 + 0.6 * progress);
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final start = Offset(
        center.dx + math.cos(angle) * innerR,
        center.dy + math.sin(angle) * innerR,
      );
      final end = Offset(
        center.dx + math.cos(angle) * outerR,
        center.dy + math.sin(angle) * outerR,
      );

      canvas.drawLine(
        start, end,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.6)
          ..strokeWidth = 2.0 * (1.0 - progress * 0.5)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
