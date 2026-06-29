import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Centered empty-state copy — no panel chrome (matches webapp EmptyState).
///
/// • No background or border radius — text only
/// • Message: semibold 23, `white16` colour
/// • [topAlign]: anchors text ~128 dp from the top instead of centring
/// • [compact]: smaller vertical padding for nested contexts
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.minHeight,
    this.topAlign = false,
    this.compact = false,
  });

  final String message;

  /// Minimum vertical space for the empty area.
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
      padding = const EdgeInsets.symmetric(vertical: 50, horizontal: 14);
    }

    return Container(
      width: double.infinity,
      constraints: minHeight != null
          ? BoxConstraints(minHeight: minHeight!)
          : const BoxConstraints(),
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
