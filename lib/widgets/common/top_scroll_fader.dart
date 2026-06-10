import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/widgets/common/scroll_to_top_button.dart';

/// Max pixels a safe-area fade overlay may extend beyond the system inset.
const double kSafeFadeMaxExtend = 8.0;

/// Opacity at the 50% midpoint of each safe-edge fade zone.
const double kSafeFadePlateauOpacity = 0.8;

/// Height over which the bottom safe-area fades into [LabColors.black]
/// (screens without [TopScrollFader.safeEdgeFades]).
const double kBottomSafeFadeHeight = 16.0;

/// Top safe-edge fade (50/50 split): 100% → 80% → 0%.
LinearGradient _topSafeEdgeGradient(Color black) {
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      black,
      black.withValues(alpha: kSafeFadePlateauOpacity),
      black.withValues(alpha: 0),
    ],
    stops: const [0, 0.5, 1],
  );
}

/// Bottom safe-edge fade (50/50 split): 0% → 80% → 100%.
LinearGradient _bottomSafeEdgeGradient(Color black) {
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      black.withValues(alpha: 0),
      black.withValues(alpha: kSafeFadePlateauOpacity),
      black,
    ],
    stops: const [0, 0.5, 1],
  );
}
///
/// Use this **inside** a [SingleChildScrollView] when a prefix of the scroll
/// column must **not** be masked (e.g. `BackdropFilter` over inbox cards:
/// a parent [ShaderMask] would break blur compositing).
class ScrollContentTopFade extends StatelessWidget {
  const ScrollContentTopFade({
    super.key,
    required this.scrollController,
    required this.child,
    this.fadeHeight = 28.0,
    this.triggerDistance = 4.0,
    this.offsetBias = 0.0,
    this.fadeStart,
  });

  final ScrollController scrollController;
  final Widget child;
  final double fadeHeight;
  final double triggerDistance;
  final double offsetBias;
  final double? fadeStart;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
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
  }
}

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
///   - A bottom gradient fades scrolling content into [LabColors.black].
///
/// **`safeEdgeFades: true` (detail pages):** each edge overlay is
/// `safeInset + [kSafeFadeMaxExtend]` tall with a 50/50 stop split: 100% at
/// the screen edge → [kSafeFadePlateauOpacity] at midpoint → 0% at the content
/// edge (top; mirrored for bottom).
///
/// **`hasBottomBar: true` (screens with a BottomBar widget):**
///   - Scroll-to-top button clears the bottom bar: `safeBottom + 80`.
///   - No bottom overlay (the BottomBar already occupies that region).
///
/// Disable the scroll-to-top button per-screen with `showScrollToTop: false`
/// (e.g. screens with their own custom FABs at that position).
///
/// Set [applyScrollShader] to `false` when [child] applies its own
/// [ScrollContentTopFade] on part of the scroll column (e.g. home feed below
/// inbox) so [BackdropFilter] is not under a global [ShaderMask].
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
    this.applyScrollShader = true,
    this.safeEdgeFades = false,
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
  /// - `false` (default): button at `safeBottom + 24`; bottom safe-area fade.
  /// - `true`: button at `safeBottom + 80` to clear the bottom bar; no overlay.
  final bool hasBottomBar;

  /// When `true` (default), wraps [child] in [ScrollContentTopFade]. Home
  /// passes `false` and fades only the feed subsection inside the scroll view.
  final bool applyScrollShader;

  /// Detail-style edge fades: solid black within each safe inset, with the
  /// transparent transition at most [kSafeFadeMaxExtend] px into the content.
  final bool safeEdgeFades;

  @override
  Widget build(BuildContext context) {
    final scrollShaderLayer = applyScrollShader
        ? ScrollContentTopFade(
            scrollController: scrollController,
            fadeHeight: fadeHeight,
            triggerDistance: triggerDistance,
            offsetBias: offsetBias,
            fadeStart: fadeStart,
            child: child,
          )
        : child;

    // Wrap in a Stack so the scroll-to-top button and optional overlay float
    // above the content.
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final topSafe = MediaQuery.paddingOf(context).top;
    final showTopEdgeFade = safeEdgeFades && topSafe > 0;
    final showBottomEdgeFade = !hasBottomBar && bottomSafe > 0;
    final needsStack =
        showScrollToTop || showTopEdgeFade || showBottomEdgeFade;
    if (!needsStack) return scrollShaderLayer;

    final c = Theme.of(context).extension<LabColors>()!;
    final topFadeZone = topSafe + kSafeFadeMaxExtend;
    final bottomFadeZone = bottomSafe + kSafeFadeMaxExtend;

    return Stack(
      children: [
        Positioned.fill(child: scrollShaderLayer),
        if (showTopEdgeFade)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topFadeZone,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _topSafeEdgeGradient(c.black),
                ),
              ),
            ),
          ),
        // Bottom safe-area fade — content dissolves into design-system black.
        if (showBottomEdgeFade)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: safeEdgeFades ? bottomFadeZone : bottomSafe,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: safeEdgeFades
                      ? _bottomSafeEdgeGradient(c.black)
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            c.black.withValues(alpha: 0),
                            c.black,
                          ],
                          stops: [
                            0,
                            (kBottomSafeFadeHeight / bottomSafe)
                                .clamp(0.0, 1.0),
                          ],
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
