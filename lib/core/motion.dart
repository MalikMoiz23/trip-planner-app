import 'package:flutter/material.dart';

/// One vocabulary for movement, so nothing in the app animates at a duration or
/// curve invented on the spot.
///
/// Everything here funnels through [Motion.of], which collapses every duration
/// to zero when the platform asks for reduced motion. Animation is decoration;
/// a person who has turned it off at the OS level has said so once and should
/// not have to say it again per screen.
class Motion {
  const Motion._(this.enabled);

  final bool enabled;

  factory Motion.of(BuildContext context) =>
      Motion._(!(MediaQuery.maybeDisableAnimationsOf(context) ?? false));

  // ---- Durations ---------------------------------------------------------
  static const Duration instant = Duration(milliseconds: 110);
  static const Duration quick = Duration(milliseconds: 190);
  static const Duration base = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration lazy = Duration(milliseconds: 650);

  /// Ambient loops — the drifting hero gradient, the shimmer sweep.
  static const Duration ambient = Duration(seconds: 14);

  // ---- Curves ------------------------------------------------------------

  /// The default. Fast out, settle in — the standard Material emphasis curve.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Entering content.
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1);

  /// Leaving content, which should get out of the way faster than it arrived.
  static const Curve exit = Cubic(0.3, 0, 0.8, 0.15);

  /// Overshoots slightly then settles. For a control confirming a tap.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);

  /// Zero when the platform asks for stillness.
  Duration d(Duration value) => enabled ? value : Duration.zero;

  /// Staggered delay for the nth item in a list, capped so a long list does not
  /// take a visible age to finish arriving.
  Duration stagger(int index, {Duration step = const Duration(milliseconds: 45), int cap = 10}) =>
      enabled ? step * (index > cap ? cap : index) : Duration.zero;
}

/// Fades and lifts a child into place once, optionally after a delay.
///
/// Used with [Motion.stagger] to make a list assemble itself rather than
/// appearing all at once.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.slow,
    this.offset = const Offset(0, 0.06),
    this.scaleFrom = 1.0,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Fractional offset of the child's own size.
  final Offset offset;

  /// Set below 1 to have the child grow into place as well.
  final double scaleFrom;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  /// The delay is folded into the controller's own duration and served by an
  /// [Interval], rather than scheduled with `Future.delayed`.
  ///
  /// A pending timer outlives the widget: it fires after dispose, and in a
  /// widget test it fails the test outright as an unclaimed timer. An interval
  /// is cancelled by disposing the controller, which happens for free.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );

  late final Animation<double> _curved = CurvedAnimation(
    parent: _c,
    curve: Interval(
      _delayFraction,
      1.0,
      curve: Motion.enter,
    ),
  );

  double get _delayFraction {
    final total = (widget.delay + widget.duration).inMicroseconds;
    if (total <= 0) return 0;
    return (widget.delay.inMicroseconds / total).clamp(0.0, 0.95);
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (Motion.of(context).enabled) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = _curved;
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (context, child) {
        final t = curved.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(
              widget.offset.dx * 100 * (1 - t),
              widget.offset.dy * 100 * (1 - t),
            ),
            child: widget.scaleFrom == 1.0
                ? child
                : Transform.scale(
                    scale: widget.scaleFrom + (1 - widget.scaleFrom) * t,
                    child: child,
                  ),
          ),
        );
      },
    );
  }
}

/// Shrinks slightly while pressed, then springs back. Gives every tappable
/// surface a physical response without needing a ripple on top of a gradient.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final BorderRadius? borderRadius;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: motion.d(Motion.instant),
        curve: Motion.spring,
        child: widget.child,
      ),
    );
  }
}

/// A number that rolls from its previous value to its new one.
///
/// The totals in this app change whenever any input moves, and a figure that
/// slides is far easier to read as "this went up" than one that simply swaps.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = Motion.slow,
    this.textAlign,
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final Duration duration;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value, end: value),
      duration: motion.d(duration),
      curve: Motion.standard,
      builder: (context, v, _) => Text(format(v), style: style, textAlign: textAlign),
    );
  }
}

/// Page transition used for every push in the app.
///
/// Material's default differs per platform and none of them suit a content app
/// with a persistent bottom bar; this is a shared-axis style — the incoming page
/// slides a short distance and fades while the outgoing one fades back.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required this.builder, super.settings})
      : super(
          transitionDuration: Motion.slow,
          reverseTransitionDuration: Motion.base,
          pageBuilder: (context, animation, secondary) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            final motion = Motion.of(context);
            if (!motion.enabled) return child;

            final enter = CurvedAnimation(parent: animation, curve: Motion.enter);
            final leave = CurvedAnimation(parent: secondary, curve: Motion.standard);

            return FadeTransition(
              opacity: enter,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.035), end: Offset.zero).animate(enter),
                child: FadeTransition(
                  opacity: Tween(begin: 1.0, end: 0.0).animate(leave),
                  child: SlideTransition(
                    position: Tween(begin: Offset.zero, end: const Offset(0, -0.02))
                        .animate(leave),
                    child: child,
                  ),
                ),
              ),
            );
          },
        );

  final WidgetBuilder builder;
}

/// Convenience so screens do not each construct the route.
extension NavigateX on BuildContext {
  Future<T?> pushScreen<T>(Widget screen) =>
      Navigator.of(this).push<T>(AppPageRoute<T>(builder: (_) => screen));
}
