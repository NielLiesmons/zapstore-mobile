import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/widgets/common/scroll_to_top_button.dart';

/// Wraps [child] in a scroll-driven top-edge fade.
///
/// At scroll offset 0 the top of [child] is fully opaque (no fader visible).
/// As the user scrolls down, the top [fadeHeight] pixels fade to transparent
/// over the first [triggerDistance] pixels of scroll — creating the illusion
/// that content is sliding up under a fixed top bar.
///
/// ### Floating-header screens (AppDetailScreen, ProfileScreen)
///
/// When the scroll content starts below a floating header (via top padding),
/// the fader gradient must be positioned at the bottom of the header, not at
/// y=0, otherwise it hides behind the header and is never visible.
///
/// Use [fadeStart] to shift the gradient down to the header bottom without
/// delaying when the fader triggers:
/// ```dart
/// TopScrollFader(
///   scrollController: scrollController,
///   fadeStart: headerHeight,   // where the gradient is drawn
///   // offsetBias defaults to 0 → triggers after just a few px of scroll
///   child: myScrollable,
/// )
/// ```
///
/// ### Column-layout screens (HomeScreen)
///
/// When the scroll content is placed in an [Expanded] below the header (not
/// inside a [Stack]), both [fadeStart] and [offsetBias] can be left at their
/// default of 0 because y=0 of the fader widget is already below the header.
///
/// ### Scroll-to-top button and bottom-bar context (default: no bottom bar)
///
/// [hasBottomBar] controls two behaviours:
///
/// **`hasBottomBar: false` (default — screens without a BottomBar widget):**
///   - Scroll-to-top button sits at `safeBottom + 24`.
///   - A blurred safe-area overlay is painted at the very bottom edge, covering
///     just the system gesture / home-indicator inset. It has a `black66`
///     background with a thin `white16` top border to blur scrolling content.
///
/// **`hasBottomBar: true` (screens with a BottomBar widget):**
///   - Scroll-to-top button clears the bottom bar: `safeBottom + 80`.
///   - No bottom overlay (the BottomBar already occupies that region).
///
/// Disable the scroll-to-top button per-screen with `showScrollToTop: false`
/// (e.g. screens with their own custom FABs at that position).
class TopScrollFader extends StatelessWidget {
  const TopScrollFader({
    super.key,
    required this.scrollController,
    required this.child,
    this.fadeHeight = 28.0,
    this.triggerDistance = 4.0,
    this.offsetBias = 0.0,
    this.fadeStart,
    this.showScrollToTop = true,
    this.scrollToTopThreshold = 1200.0,
    this.hasBottomBar = false,
  });

  final ScrollController scrollController;
  final Widget child;

  /// Height of the gradient fade region at the top of [child].
  final double fadeHeight;

  /// Scroll distance (px) over which the fade grows from 0 → full.
  /// Default 4px so the fader reaches full intensity almost immediately.
  final double triggerDistance;

  /// Scroll offset at which the fader starts becoming visible.
  /// Leave at 0 for instant-on behaviour (triggers after first px of scroll).
  final double offsetBias;

  /// Y-position (within the widget) where the gradient starts.
  /// Defaults to [offsetBias] when null.
  /// Set this to [headerHeight] on floating-header screens so the gradient
  /// is drawn right at the header bottom edge rather than at the screen top.
  final double? fadeStart;

  /// When true (default), overlays a [ScrollToTopButton] at the bottom-right.
  /// Set to false for screens that have their own FAB at that position.
  final bool showScrollToTop;

  /// Scroll offset (px) beyond which the scroll-to-top button begins to
  /// appear.  The button scales in over the following 17 px.
  final double scrollToTopThreshold;

  /// Whether this screen has a [BottomBar] widget.
  ///
  /// - `false` (default): button at `safeBottom + 24`; blurred safe-area
  ///   overlay shown at the bottom edge.
  /// - `true`: button at `safeBottom + 80` to clear the bottom bar; no overlay.
  final bool hasBottomBar;

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: always return ShaderMask (never swap to a non-ShaderMask
    // widget) so the widget type at this position in the tree never changes —
    // changing type forces a rebuild that can detach the ScrollPosition.
    final shaderMask = ListenableBuilder(
      listenable: scrollController,
      builder: (context, child) {
        final t = scrollController.hasClients
            ? ((scrollController.offset - offsetBias) / triggerDistance)
                .clamp(0.0, 1.0)
            : 0.0;
        final gradStart = fadeStart ?? offsetBias;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              // alpha=1 at t=0 → no fade; alpha=0 at t=1 → full fade
              Colors.black.withValues(alpha: 1.0 - t),
              Colors.black,
            ],
          ).createShader(
            Rect.fromLTWH(0, gradStart, bounds.width, fadeHeight),
          ),
          blendMode: BlendMode.dstIn,
          child: child!,
        );
      },
      child: child,
    );

    // Wrap in a Stack so the scroll-to-top button and optional overlay float
    // above the content.
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final needsStack = showScrollToTop || (!hasBottomBar && bottomSafe > 0);
    if (!needsStack) return shaderMask;

    final c = Theme.of(context).extension<LabColors>()!;

    return Stack(
      children: [
        Positioned.fill(child: shaderMask),
        // Blurred safe-area overlay — only on screens without a bottom bar,
        // and only when there is a non-zero gesture/home-indicator inset.
        if (!hasBottomBar && bottomSafe > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: bottomSafe,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.black66,
                    border: Border(
                      top: BorderSide(
                        color: c.white16,
                        width: LabStroke.thin,
                        strokeAlign: BorderSide.strokeAlignCenter,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Scroll-to-top button: 24px above safe inset (no bottom bar) or
        // 80px above (bottom bar present, to clear its height).
        if (showScrollToTop)
          Positioned(
            bottom: bottomSafe + (hasBottomBar ? 80.0 : 24.0),
            right: 14,
            child: ScrollToTopButton(
              scrollController: scrollController,
              threshold: scrollToTopThreshold,
            ),
          ),
      ],
    );
  }
}
