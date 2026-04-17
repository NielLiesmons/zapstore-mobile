import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/url_utils.dart';
import 'shimmer.dart';

/// Circular profile picture matching the webapp's ProfilePic.svelte design.
///
/// - 0.33px white16 border
/// - [CachedNetworkImage] with [Shimmer] loading state
/// - Colored initial letter fallback derived from [pubkey]
/// - Generic profile icon fallback when no name/image available
///
/// [size] is the full diameter in pixels (e.g. 48 = a 48×48 circle).
class ProfilePic extends StatelessWidget {
  const ProfilePic({
    super.key,
    this.profile,
    this.pubkey,
    this.size = 48.0,
  });

  final Profile? profile;

  /// Pubkey used for deterministic fallback color when no profile image exists.
  /// Also used to distinguish signed-in vs signed-out state for the icon fallback.
  final String? pubkey;

  /// Full diameter in pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final pictureUrl = sanitizeHttpUrl(profile?.pictureUrl);
    final name = profile?.name;
    final resolvedPubkey = pubkey ?? profile?.pubkey;

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: AppBorder.all(color: c.white16, width: 0.33),
        ),
        child: ClipOval(
          child: pictureUrl != null
              ? CachedNetworkImage(
                  imageUrl: pictureUrl,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  fadeInDuration: const Duration(milliseconds: 300),
                  fadeOutDuration: const Duration(milliseconds: 150),
                  placeholder: (_, __) => Shimmer(
                    width: size,
                    height: size,
                    isCircle: true,
                  ),
                  errorWidget: (_, __, ___) =>
                      _buildFallback(context, c, name, resolvedPubkey),
                )
              : _buildFallback(context, c, name, resolvedPubkey),
        ),
      ),
    );
  }

  Widget _buildFallback(
    BuildContext context,
    AppColors c,
    String? name,
    String? pubkey,
  ) {
    final initial = _getInitial(name, pubkey);

    if (initial != null) {
      final seed = pubkey ?? name ?? '';
      final bool isHex = RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(seed);
      final color = isHex ? hexToColor(seed) : stringToColor(seed);
      final bg = profileBgColor(color);
      final fg = color;
      final fontSize = size * 0.44;

      return SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: bg,
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: fg,
                height: 1.0,
                leadingDistribution: TextLeadingDistribution.even,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ColoredBox(
        color: c.white8,
        child: Center(
          child: AppIcon(
            AppIcons.profile,
            size: size * 0.56,
            color: c.white33,
          ),
        ),
      ),
    );
  }
}

String? _getInitial(String? name, String? pubkey) {
  if (name != null && name.trim().isNotEmpty) {
    return name.trim()[0].toUpperCase();
  }
  if (pubkey != null && pubkey.length >= 2) {
    return pubkey[pubkey.length - 2].toUpperCase();
  }
  return null;
}

