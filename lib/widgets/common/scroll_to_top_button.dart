import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScrollToTopButton
//
// Round 44×44 FAB-style button that:
//   • is hidden until the user scrolls past [threshold] (default 1200 px)
//   • scales in smoothly over the first [scaleRange] px beyond the threshold
//   • taps to animate back to the top of the scroll view
//
// Styling:
//   gray66 bg · white16 thin-stroke border · arrowUp icon in white33
//
// Positioning is handled by the CALLER (typically a Positioned inside the
// TopScrollFader's Stack), so this widget has no built-in position knowledge.
// ─────────────────────────────────────────────────────────────────────────────

class ScrollToTopButton extends StatelessWidget {
  const ScrollToTopButton({
    super.key,
    required this.scrollController,
    this.threshold = 1200.0,
    this.scaleRange = 17.0,
  });

  final ScrollController scrollController;

  /// Scroll offset (px) at which the button starts to appear.
  final double threshold;

  /// Scroll range (px) over which the button scales from 0 → 1.
  final double scaleRange;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return ListenableBuilder(
      listenable: scrollController,
      builder: (context, _) {
        final offset =
            scrollController.hasClients ? scrollController.offset : 0.0;
        final scale = ((offset - threshold) / scaleRange).clamp(0.0, 1.0);

        return IgnorePointer(
          ignoring: scale < 0.01,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              ),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.gray66,
                  shape: BoxShape.circle,
                  border: LabBorder.all(
                    color: c.white16,
                    width: LabStroke.thin,
                  ),
                ),
                child: Center(
                  child: LabIcon(
                    LabIcons.arrowUp,
                    size: 18,
                    color: c.white33,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
