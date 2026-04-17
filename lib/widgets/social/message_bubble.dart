import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';

/// Chat-style message bubble matching webapp MessageBubble.svelte.
///
/// Layout:
///   [ProfilePic]  [bubble: [header: name + timestamp] [content]]
///
/// - Incoming: gray66 bg, bottom-left corner 4px, profile-colored author name
/// - Outgoing: blurple gradient, reversed, bottom-right corner 4px
/// - Loading: shimmer placeholder
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    this.profile,
    this.pubkey,
    required this.content,
    this.timestamp,
    this.isOutgoing = false,
    this.isLight = false,
    this.isPending = false,
    this.onAvatarTap,
    this.onNameTap,
    this.trailing,
  });

  final Profile? profile;
  final String? pubkey;
  final Widget content;
  final DateTime? timestamp;
  final bool isOutgoing;

  /// Light variant (white8 bg instead of gray66).
  final bool isLight;

  /// Shows a loading spinner instead of timestamp (publishing state).
  final bool isPending;

  final VoidCallback? onAvatarTap;
  final VoidCallback? onNameTap;

  /// Optional widget shown in the action rail beside the bubble (e.g. zap button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    final avatarWidget = GestureDetector(
      onTap: onAvatarTap,
      child: ProfilePic(profile: profile, pubkey: pubkey, size: 36),
    );

    return Padding(
      // 24px extra right space for incoming messages so bubbles don't span wall-to-wall.
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: 12,
        right: isOutgoing ? 12 : 36,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isOutgoing) ...[avatarWidget, const SizedBox(width: 8)],
          Flexible(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment:
                  isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                // No inner Flexible — let _BubbleBody size to content via
                // mainAxisSize.min in its header row.
                _BubbleBody(bubble: this, c: c),
                if (trailing != null) ...[const SizedBox(width: 6), trailing!],
              ],
            ),
          ),
          if (isOutgoing) ...[const SizedBox(width: 8), avatarWidget],
        ],
      ),
    );
  }
}

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({required this.bubble, required this.c});

  final MessageBubble bubble;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    final isOut = bubble.isOutgoing;

    // Border radius: 16px all corners, 4px on the "tail" corner
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isOut ? 16 : 4),
      bottomRight: Radius.circular(isOut ? 4 : 16),
    );

    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: isOut ? null : (bubble.isLight ? c.white8 : c.gray66),
        gradient: isOut ? c.blurple as LinearGradient? : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isOut) _BubbleHeader(bubble: bubble, c: c),
          _BubbleContent(content: bubble.content, c: c, isOutgoing: isOut),
        ],
      ),
    );
  }
}

class _BubbleHeader extends StatelessWidget {
  const _BubbleHeader({required this.bubble, required this.c});

  final MessageBubble bubble;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    final profile = bubble.profile;
    final pubkey = bubble.pubkey ?? profile?.pubkey;

    // Resolve profile color: hex pubkey → hexToColor, name fallback → stringToColor
    final Color nameColor = () {
      if (pubkey != null && pubkey.isNotEmpty) {
        final base = hexToColor(pubkey);
        return profileTextColor(base);
      }
      if (profile?.name != null) {
        final base = stringToColor(profile!.name!);
        return profileTextColor(base);
      }
      return c.white66;
    }();

    final displayName = _resolveDisplayName(profile, pubkey);

    // Use MainAxisSize.min so the bubble body only grows to hug content width.
    // The timestamp sits right after the name (with a small gap) rather than
    // being pushed to the far right, matching webapp's fit-content bubble behavior.
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: bubble.onNameTap,
              child: Text(
                displayName,
                // 13px semibold for profile names — matches webapp's .author-name
                style: AppTextStyles.semibold13.copyWith(color: nameColor),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          if (bubble.timestamp != null || bubble.isPending) ...[
            const SizedBox(width: 6),
            bubble.isPending
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: c.blurpleLightColor,
                    ),
                  )
                : Text(
                    _formatTimestamp(bubble.timestamp!),
                    style: AppTextStyles.reg11.copyWith(color: c.white33),
                  ),
          ],
        ],
      ),
    );
  }

  static String _resolveDisplayName(Profile? profile, String? pubkey) {
    if (profile?.name != null && profile!.name!.trim().isNotEmpty) {
      return profile.name!.trim();
    }
    if (pubkey != null && pubkey.length >= 14) {
      final s = pubkey;
      return 'npub1${s.substring(0, 3)}...${s.substring(s.length - 6)}';
    }
    return 'anon';
  }

  /// Webapp-matching timestamp format (Timestamp.svelte):
  ///   < 1 min  → "Just Now"
  ///   today    → "Today HH:MM"
  ///   yesterday → "Yesterday"
  ///   older    → "Jan 21"
  static String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just Now';

    final today = DateTime(now.year, now.month, now.day);
    final dtDay = DateTime(dt.year, dt.month, dt.day);

    if (dtDay == today) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Today $h:$m';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (dtDay == yesterday) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({
    required this.content,
    required this.c,
    required this.isOutgoing,
  });

  final Widget content;
  final AppColors c;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: AppTextStyles.reg15.copyWith(
        color: isOutgoing ? c.white : c.white.withValues(alpha: 0.85),
        height: 1.5,
      ),
      child: content,
    );
  }
}
