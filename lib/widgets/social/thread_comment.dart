import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/time_utils.dart';

/// Flat (non-bubble) root comment display for the top of a thread modal.
///
/// Mirrors webapp's ThreadComment.svelte:
///   [ProfilePic 36]  [author-name (profile-colored)]  [timestamp right-aligned]
///                    [full content below, no truncation]
///
/// Used in [_ThreadBody] as the root comment header — distinct from the
/// [MessageBubble] used for replies below the divider.
class ThreadComment extends StatelessWidget {
  const ThreadComment({
    super.key,
    this.profile,
    this.pubkey,
    required this.content,
    this.timestamp,
  });

  final Profile? profile;
  final String? pubkey;
  final Widget content;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    final effectivePubkey = pubkey ?? profile?.pubkey;
    final Color nameColor = () {
      if (effectivePubkey != null && effectivePubkey.isNotEmpty) {
        return profileTextColor(hexToColor(effectivePubkey));
      }
      if (profile?.name != null) {
        return profileTextColor(stringToColor(profile!.name!));
      }
      return c.white66;
    }();

    final displayName = _resolveDisplayName(profile, effectivePubkey);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Author row: avatar + name + timestamp
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfilePic(profile: profile, pubkey: pubkey, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: LabTextStyles.semibold15.copyWith(color: nameColor),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (timestamp != null) ...[
                      const SizedBox(width: 10),
                      TimeAgoText(
                        timestamp!,
                        style: LabTextStyles.reg13.copyWith(color: c.white33),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Content — full, no truncation, matches webapp .content mt-8px
          const SizedBox(height: 10),
          DefaultTextStyle.merge(
            style: LabTextStyles.reg15.copyWith(
              color: c.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
            child: content,
          ),
        ],
      ),
    );
  }

  static String _resolveDisplayName(Profile? profile, String? pubkey) {
    if (profile?.name != null && profile!.name!.trim().isNotEmpty) {
      return profile.name!.trim();
    }
    if (pubkey != null && pubkey.length >= 14) {
      return 'npub1${pubkey.substring(0, 3)}…${pubkey.substring(pubkey.length - 6)}';
    }
    return 'anon';
  }
}
