import 'package:flutter/material.dart';

/// Wraps [child] in a scroll-driven top-edge fade.
///
/// At scroll offset 0 the top of [child] is fully opaque (no fader visible).
/// As the user scrolls down, the top [fadeHeight] pixels fade to transparent
/// over the first [triggerDistance] pixels of scroll — creating the illusion
/// that content is sliding up under a fixed top bar.
///
/// Used in both [HomeScreen] and [AppDetailScreen] so the behaviour is
/// identical in both places.
class TopScrollFader extends StatelessWidget {
  const TopScrollFader({
    super.key,
    required this.scrollController,
    required this.child,
    this.fadeHeight = 28.0,
    this.triggerDistance = 16.0,
    this.offsetBias = 0.0,
  });

  final ScrollController scrollController;
  final Widget child;

  /// Height of the gradient fade region at the top of [child].
  final double fadeHeight;

  /// Scroll distance (px) over which the fade grows from 0 → full.
  final double triggerDistance;

  /// Scroll offset at which the fader starts becoming visible.
  /// Use this when the scrollable content begins below the top of the
  /// viewport (e.g. because of a floating header with padding).
  final double offsetBias;

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: always return ShaderMask (never swap to a non-ShaderMask
    // widget) so the widget type at this position in the tree never changes —
    // changing type forces a rebuild that can detach the ScrollPosition.
    // We just vary the gradient colours from opaque→opaque (no visual fade)
    // at t=0 to transparent→opaque (full fade) at t=1.
    return ListenableBuilder(
      listenable: scrollController,
      builder: (context, child) {
        final t = scrollController.hasClients
            ? ((scrollController.offset - offsetBias) / triggerDistance)
                .clamp(0.0, 1.0)
            : 0.0;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              // alpha=1 at t=0 → no fade; alpha=0 at t=1 → full fade
              Colors.black.withValues(alpha: 1.0 - t),
              Colors.black,
            ],
          // offsetBias shifts the gradient down so it starts just below the
          // floating header rather than at the very top of the screen.
          ).createShader(Rect.fromLTWH(0, offsetBias, bounds.width, fadeHeight)),
          blendMode: BlendMode.dstIn,
          child: child!,
        );
      },
      child: child,
    );
  }
}
