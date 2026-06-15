import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/time_utils.dart';
import 'package:zapstore/widgets/social/bubble_swiper.dart';

/// Chat-style message bubble matching webapp MessageBubble.svelte.
///
/// Layout:
///   [ProfilePic]  [bubble: [header: name + timestamp] [content]]
///
/// - Incoming: gray66 bg, bottom-left corner 4px, profile-colored author name
/// - Outgoing: blurple gradient, reversed, bottom-right corner 4px
///
/// Sizing strategy (matches zaplab_design LabMessageBubble):
///   • `Flexible` limits the bubble to the available row width (prevents overflow)
///   • `IntrinsicWidth` inside makes the bubble shrink to the width of its widest
///     child — i.e. the bubble "hugs" its content.
///   • `CrossAxisAlignment.stretch` on the inner Column forces the header Row to
///     fill the bubble width → `spaceBetween` correctly places the timestamp at
///     the far right even for narrow bubbles.
class MessageBubble extends StatefulWidget {
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
    this.onReply,
    this.onActions,
    this.inThreadModal = false,
    this.topPadding = 4,
  });

  final Profile? profile;
  final String? pubkey;
  final Widget content;
  final DateTime? timestamp;
  final bool isOutgoing;

  /// Light variant (white8 bg instead of gray66).
  final bool isLight;

  /// When true, horizontal padding comes from the thread-replies container only.
  final bool inThreadModal;

  /// Top spacing before the bubble row (0 in the comments feed).
  final double topPadding;

  /// Shows a loading spinner instead of timestamp (publishing state).
  final bool isPending;

  final VoidCallback? onAvatarTap;
  final VoidCallback? onNameTap;

  /// Optional widget shown beside the bubble (e.g. zap button).
  final Widget? trailing;

  /// Called when the user swipe-right triggers reply (fires at the pop peak).
  final VoidCallback? onReply;

  /// Called when the user swipe-left triggers the options sheet (at pop peak).
  final VoidCallback? onActions;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final avatarWidget = GestureDetector(
      onTap: widget.onAvatarTap,
      child: ProfilePic(
          profile: widget.profile, pubkey: widget.pubkey, size: 36),
    );

    if (widget.isOutgoing) {
      return Padding(
        padding: EdgeInsets.only(
          top: widget.topPadding,
          left: 14,
          right: 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: IntrinsicWidth(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(child: _BubbleBody(bubble: widget, c: c)),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 6),
                      widget.trailing!,
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            avatarWidget,
          ],
        ),
      );
    }

    // Incoming: Flexible+IntrinsicWidth mirrors the original layout so that
    // _BubbleBody's CrossAxisAlignment.stretch gets tight constraints.
    // _IncomingBubbleSwiper is the replacement for _SwipeReplyBubble and
    // contains avatar + gap + bubble internally (matching the original Row).
    return Padding(
      padding: EdgeInsets.only(
        top: widget.topPadding,
        left: widget.inThreadModal ? 0 : 14,
        right: widget.inThreadModal ? 0 : 40,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        // mainAxisSize: max (default) — fills available width so Flexible below
        // has a finite remaining space to give to IntrinsicWidth.
        children: [
          Flexible(
            child: IntrinsicWidth(
              child: BubbleSwiper(
                leading: avatarWidget,
                c: c,
                onReply: widget.onReply,
                onActions: widget.onActions,
                child: _BubbleBody(bubble: widget, c: c),
              ),
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: 6),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({required this.bubble, required this.c});

  final MessageBubble bubble;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    final isOut = bubble.isOutgoing;

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isOut ? 16 : 4),
      bottomRight: Radius.circular(isOut ? 4 : 16),
    );

    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.fromLTRB(11, 6, 11, 6),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: isOut ? null : (bubble.isLight ? c.white8 : c.gray66),
        gradient: isOut ? c.blurple as LinearGradient? : null,
      ),
      child: Column(
        // stretch forces every child (header Row, content) to the bubble width
        // set by IntrinsicWidth so spaceBetween works correctly in the header.
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    final profile = bubble.profile;
    final pubkey = bubble.pubkey ?? profile?.pubkey;

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

    // spaceBetween works correctly because the parent Column uses
    // crossAxisAlignment.stretch → this Row fills the bubble width.
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: bubble.onNameTap,
              child: Text(
                displayName,
                style: LabTextStyles.semibold13.copyWith(color: nameColor),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          if (bubble.timestamp != null || bubble.isPending) ...[
            const SizedBox(width: 8),
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
                    style: LabTextStyles.reg11.copyWith(color: c.white33),
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

  static String _formatTimestamp(DateTime dt) {
    return TimeUtils.formatTimestamp(dt);
  }
}

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({
    required this.content,
    required this.c,
    required this.isOutgoing,
  });

  final Widget content;
  final LabColors c;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: LabTextStyles.reg15.copyWith(
        color: isOutgoing ? c.white : c.white.withValues(alpha: 0.85),
        height: 1.5,
      ),
      child: content,
    );
  }
}

