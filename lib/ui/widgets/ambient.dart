import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';

/// A category gradient that slowly drifts, so a hero panel is never quite
/// static without ever pulling attention.
///
/// The motion is a long, low-amplitude wander of the gradient's start and end
/// points — no colour cycling, which reads as a bug rather than as depth. Falls
/// back to a plain gradient when reduced motion is on.
class DriftingGradient extends StatefulWidget {
  const DriftingGradient({
    super.key,
    required this.colors,
    this.child,
    this.borderRadius,
    this.amplitude = 0.35,
  });

  final List<Color> colors;
  final Widget? child;
  final BorderRadius? borderRadius;

  /// How far the gradient anchors travel, in fractions of the box.
  final double amplitude;

  @override
  State<DriftingGradient> createState() => _DriftingGradientState();
}

class _DriftingGradientState extends State<DriftingGradient>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.ambient);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.of(context).enabled) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Motion.of(context).enabled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.colors,
          ),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        // Two circles walked at different rates, so the pair never repeats a
        // configuration until the full cycle comes round.
        final a = _c.value * 2 * math.pi;
        final begin = Alignment(
          -1 + widget.amplitude * math.cos(a),
          -1 + widget.amplitude * math.sin(a),
        );
        final end = Alignment(
          1 + widget.amplitude * math.cos(a * 0.7 + 1.3),
          1 + widget.amplitude * math.sin(a * 0.7 + 1.3),
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(begin: begin, end: end, colors: widget.colors),
          ),
          child: child,
        );
      },
    );
  }
}

/// Moves its child at a fraction of the scroll speed.
///
/// Wraps a [ScrollController] rather than a notification listener so the header
/// tracks overscroll too, which is where parallax is most visible.
class ParallaxBox extends StatelessWidget {
  const ParallaxBox({
    super.key,
    required this.scroll,
    required this.child,
    this.rate = 0.35,
    this.maxShift = 90,
  });

  final ScrollController scroll;
  final Widget child;

  /// 0 pins the child to the viewport, 1 moves it with the content.
  final double rate;
  final double maxShift;

  @override
  Widget build(BuildContext context) {
    if (!Motion.of(context).enabled) return child;
    return AnimatedBuilder(
      animation: scroll,
      child: child,
      builder: (context, child) {
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        final shift = (offset * rate).clamp(-maxShift, maxShift);
        // Scale up a touch on overscroll so pulling down stretches the image
        // rather than exposing the background behind it.
        final stretch = offset < 0 ? 1 + (-offset / 600).clamp(0.0, 0.25) : 1.0;
        return Transform.scale(
          scale: stretch,
          child: Transform.translate(offset: Offset(0, shift), child: child),
        );
      },
    );
  }
}

/// Sweeping highlight for content that has not arrived yet.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.width, required this.height, this.radius});

  final double width;
  final double height;
  final BorderRadius? radius;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.of(context).enabled) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = widget.radius ?? AppRadius.sm;

    if (!Motion.of(context).enabled) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: radius),
      );
    }

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment(-1 + 3 * _c.value, 0),
            end: Alignment(1 + 3 * _c.value, 0),
            colors: [p.surfaceAlt, p.line, p.surfaceAlt],
            stops: const [0.35, 0.5, 0.65],
          ),
        ),
      ),
    );
  }
}

/// Crossfades and slides between two children keyed by value — used wherever a
/// figure or label is replaced in place.
class SwapIn extends StatelessWidget {
  const SwapIn({super.key, required this.child, this.alignment = Alignment.centerLeft});

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return AnimatedSwitcher(
      duration: motion.d(Motion.base),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
