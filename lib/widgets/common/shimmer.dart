import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';

/// Provides a single shared [AnimationController] to all [Shimmer] descendants
/// on the same screen so they all animate in perfect sync with one ticker.
///
/// Place once near the root of each screen that contains loading skeletons:
/// ```dart
/// ShimmerTheme(
///   child: Scaffold(...),
/// )
/// ```
class ShimmerTheme extends StatefulWidget {
  const ShimmerTheme({super.key, required this.child});

  final Widget child;

  static Animation<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerThemeData>()?.animation;

  @override
  State<ShimmerTheme> createState() => _ShimmerThemeState();
}

class _ShimmerThemeState extends State<ShimmerTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerThemeData(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _ShimmerThemeData extends InheritedWidget {
  const _ShimmerThemeData({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_ShimmerThemeData oldWidget) =>
      animation != oldWidget.animation;
}

/// A performant shimmer skeleton placeholder.
///
/// Reads the shared [Animation] from the nearest [ShimmerTheme] ancestor so
/// that all skeletons on screen animate with one controller (zero per-widget
/// overhead). Falls back to a static base color if no [ShimmerTheme] is found.
///
/// All sizes are in logical pixels. Shape is either a rounded rectangle
/// (default) or a circle ([isCircle] = true).
class Shimmer extends StatelessWidget {
  const Shimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8.0,
    this.isCircle = false,
  });

  final double width;
  final double height;
  final double radius;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    final themeData = ShimmerTheme.of(context);
    final c = Theme.of(context).extension<LabColors>();

    final baseColor = c?.gray ?? const Color(0xFF232323);
    final highlightColor = c?.gray66 ?? const Color(0xA8333333);

    final borderRadius = isCircle
        ? BorderRadius.circular(width / 2)
        : BorderRadius.circular(radius);

    if (themeData == null) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox(
            width: width,
            height: height,
            child: ColoredBox(color: baseColor),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: themeData,
        builder: (context, _) {
          final t = themeData.value;
          final shimmerGradient = LinearGradient(
            colors: [baseColor, highlightColor, baseColor],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment(-2.0 + t * 4.0, 0.0),
            end: Alignment(-1.0 + t * 4.0, 0.0),
          );

          return ClipRRect(
            borderRadius: borderRadius,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => shimmerGradient.createShader(bounds),
              child: SizedBox(
                width: width,
                height: height,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}
