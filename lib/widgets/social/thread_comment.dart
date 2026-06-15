import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/time_utils.dart';

/// Flat (non-bubble) root comment display for opened thread modals.
///
/// Mirrors webapp's ThreadComment.svelte:
///   [ProfilePic 36]  [author-name (profile-colored)]     [timestamp] [actions]
///                    [full content below, no truncation]
///
/// When [showAvatar] is false the avatar lives on the unified left rail
/// (see [_ThreadRootUnified] in root_comment.dart).
class ThreadComment extends StatelessWidget {
  const ThreadComment({
    super.key,
    this.profile,
    this.pubkey,
    required this.content,
    this.timestamp,
    this.showAvatar = true,
    this.onAuthorTap,
    this.headerActions,
  });

  final Profile? profile;
  final String? pubkey;
  final Widget content;
  final DateTime? timestamp;

  /// When false, avatar is rendered on the thread left rail instead.
  final bool showAvatar;

  final VoidCallback? onAuthorTap;

  /// Trailing actions on the author row (e.g. options ⋯ on root comment).
  final Widget? headerActions;

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
      padding: EdgeInsets.fromLTRB(
        showAvatar ? 14 : 0,
        showAvatar ? 12 : 8,
        showAvatar ? 14 : 0,
        showAvatar ? 12 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showAvatar) ...[
                GestureDetector(
                  onTap: onAuthorTap,
                  behavior: HitTestBehavior.opaque,
                  child: ProfilePic(profile: profile, pubkey: pubkey, size: 36),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: onAuthorTap,
                              behavior: HitTestBehavior.opaque,
                              child: Text(
                                displayName,
                                style: LabTextStyles.semibold15
                                    .copyWith(color: nameColor),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
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
                    if (headerActions != null) headerActions!,
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: showAvatar ? 10 : 4),
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

/// Options (⋯) button for the root comment author row in thread modals.
class ThreadRootOptionsButton extends StatelessWidget {
  const ThreadRootOptionsButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 16,
        height: 14,
        child: Center(
          child: LabIcon(LabIcons.options, size: 14, color: c.white33),
        ),
      ),
    );
  }
}
