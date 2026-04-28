import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';

/// Overlapping profile avatar stack matching webapp's ProfilePicStack.svelte.
///
/// Shows up to [maxDisplay] avatars overlapping by [overlap] pixels (first on top).
/// Optional [text] + [suffix] shown in a white8 pill to the right.
///
/// Used in the comment reply indicator row.
class ProfilePicStack extends StatelessWidget {
  const ProfilePicStack({
    super.key,
    required this.profiles,
    this.text = '',
    this.suffix = '',
    this.maxDisplay = 3,
    this.avatarSize = 24.0,
    this.overlap = 8.0,
    this.onTap,
  });

  final List<ProfilePicItem> profiles;
  final String text;
  final String suffix;
  final int maxDisplay;
  final double avatarSize;
  final double overlap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final displayed = profiles.take(maxDisplay).toList();
    final c = Theme.of(context).extension<LabColors>()!;

    Widget stack = SizedBox(
      width: displayed.isEmpty
          ? 0
          : avatarSize + (displayed.length - 1) * (avatarSize - overlap),
      height: avatarSize,
      child: Stack(
        children: displayed.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          // First avatar (i=0) sits on top; z-index decreases left→right.
          // In Flutter Stack, last child paints on top, so reverse the list.
          return Positioned(
            left: i * (avatarSize - overlap),
            child: Container(
              decoration: i < displayed.length - 1
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      // Right-side shadow to separate overlapping avatars
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.66),
                          blurRadius: 8,
                          spreadRadius: -2,
                          offset: const Offset(4, 0),
                        ),
                      ],
                    )
                  : null,
              child: ProfilePic(
                profile: item.profile,
                pubkey: item.pubkey,
                size: avatarSize,
              ),
            ),
          );
        }).toList().reversed.toList(), // reverse so first avatar paints last (on top)
      ),
    );

    final hasPill = text.isNotEmpty || suffix.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          stack,
          if (hasPill)
            Transform.translate(
              offset: Offset(-overlap, 0),
              child: Container(
                height: avatarSize,
                // Count-only (no text): tighter symmetric padding so the number
                // isn't pushed right by the extra avatar-overlap indent.
                padding: text.isNotEmpty
                    ? const EdgeInsets.only(left: 16, right: 12)
                    : const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: c.white8,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (text.isNotEmpty)
                      Text(
                        text,
                        style: LabTextStyles.med13.copyWith(color: c.white66),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (text.isNotEmpty && suffix.isNotEmpty)
                      const SizedBox(width: 6),
                    if (suffix.isNotEmpty)
                      Text(
                        suffix,
                        style: LabTextStyles.bold13.copyWith(color: c.white33),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Data class for an item in [ProfilePicStack].
class ProfilePicItem {
  const ProfilePicItem({this.profile, this.pubkey});

  final Profile? profile;
  final String? pubkey;
}
