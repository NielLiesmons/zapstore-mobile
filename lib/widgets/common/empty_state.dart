import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Consistent empty-state panel matching webapp's EmptyState.svelte.
///
/// • Background: `gray16`, border-radius 16
/// • Message: 24 sp semibold, `white16` colour
/// • Default: vertically centred text with 50 dp top/bottom padding
/// • [compact]: smaller padding (16 / 20) — for nested contexts like modals
/// • [topAlign]: anchors text ~128 dp from the top instead of centring it
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.minHeight,
    this.topAlign = false,
    this.compact = false,
  });

  final String message;

  /// Override the minimum container height (dp). Useful for tall areas like
  /// SocialTabs content where you want the panel to fill the available space.
  final double? minHeight;

  /// When true the text sits ~128 dp from the top (webapp `top-align` modifier).
  final bool topAlign;

  /// Smaller padding for nested contexts (webapp `compact` modifier).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    EdgeInsets padding;
    if (compact) {
      padding = const EdgeInsets.fromLTRB(20, 16, 20, 20);
    } else if (topAlign) {
      padding = const EdgeInsets.only(top: 128, bottom: 50);
    } else {
      padding = const EdgeInsets.symmetric(vertical: 50);
    }

    return Container(
      width: double.infinity,
      constraints: minHeight != null
          ? BoxConstraints(minHeight: minHeight!)
          : const BoxConstraints(),
      decoration: BoxDecoration(
        color: c.gray16,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: topAlign ? Alignment.topCenter : Alignment.center,
      child: Padding(
        padding: padding,
          child: Text(
          message,
          style: LabTextStyles.semibold23.copyWith(
            color: c.white.withValues(alpha: 0.16),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
