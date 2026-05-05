import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:zapstore/utils/extensions.dart';
import 'shimmer.dart';

/// Centralized widget for displaying profile names with proper loading states.
///
/// Loading logic at call sites should be:
/// `isLoading = state is StorageLoading && profile == null`
///
/// This ensures:
/// - If we have cached data, show it immediately (no loading state)
/// - If loading with no cached data, show skeleton + npub
/// - If not loading and no data, show abbreviated npub
class ProfileNameWidget extends StatelessWidget {
  const ProfileNameWidget({
    super.key,
    required this.pubkey,
    this.profile,
    this.isLoading = false,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.skeletonWidth = 80,
  });

  /// The pubkey used for fallback npub display
  final String pubkey;

  /// The loaded profile (nullable)
  final Profile? profile;

  /// Whether we're loading AND have no cached data
  final bool isLoading;

  /// Text style for the name
  final TextStyle? style;

  /// Maximum lines for the text
  final int maxLines;

  /// Text overflow behavior
  final TextOverflow overflow;

  /// Width of the skeleton container during loading
  final double skeletonWidth;

  String get _abbreviatedNpub {
    final npub = Utils.encodeShareableFromString(pubkey, type: 'npub');
    return npub.abbreviateNpub();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    final textHeight = (effectiveStyle?.fontSize ?? 14).roundToDouble();

    // Loading: use our design-system Shimmer (gray palette, no blurple tint).
    if (isLoading) {
      return Shimmer(width: skeletonWidth, height: textHeight);
    }

    // Data state: show profile name or abbreviated npub if not found
    return Text(
      profile?.nameOrNpub.abbreviateNpub() ?? _abbreviatedNpub,
      style: effectiveStyle,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

