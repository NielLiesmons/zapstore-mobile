import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';

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

  /// Optional widget shown beside the bubble (e.g. zap button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    final avatarWidget = GestureDetector(
      onTap: onAvatarTap,
      child: ProfilePic(profile: profile, pubkey: pubkey, size: 36),
    );

    return Padding(
      // No bottom padding so the reply-indicator row sits flush under the bubble.
      padding: EdgeInsets.only(
        top: 4,
        left: 14,
        right: isOutgoing ? 14 : 40,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isOutgoing) ...[avatarWidget, const SizedBox(width: 6)],
          // Flexible: limits max width so long content can't overflow.
          // IntrinsicWidth: shrinks the bubble to the width of its widest child.
          Flexible(
            child: IntrinsicWidth(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: isOutgoing
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  Flexible(
                    child: isOutgoing
                        ? _BubbleBody(bubble: this, c: c)
                        : _SwipeReplyBubble(bubble: this, c: c),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 6), trailing!],
                ],
              ),
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
  final AppColors c;

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
                style: AppTextStyles.semibold13.copyWith(color: nameColor),
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
  ///   < 1 min    → "Just Now"
  ///   today      → "Today HH:MM"
  ///   yesterday  → "Yesterday"
  ///   older      → "Jan 21"
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

// ─────────────────────────────────────────────────────────────────────────────
// Swipe-to-reply wrapper (incoming bubbles only)
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [_BubbleBody] with a swipe-right gesture that reveals a reply icon.
///
/// - Drag right → bubble translates right; reply circle fades + scales in.
/// - Release → elastic snap-back animation returns bubble to rest.
/// - Haptic tick fires when drag crosses the trigger threshold (44px).
/// - Does NOT wire up any reply callback yet — purely visual.
class _SwipeReplyBubble extends StatefulWidget {
  const _SwipeReplyBubble({required this.bubble, required this.c});

  final MessageBubble bubble;
  final AppColors c;

  @override
  State<_SwipeReplyBubble> createState() => _SwipeReplyBubbleState();
}

class _SwipeReplyBubbleState extends State<_SwipeReplyBubble>
    with SingleTickerProviderStateMixin {
  // Max drag distance and threshold at which the haptic + full icon appear.
  static const double _maxDrag = 64.0;
  static const double _triggerAt = 44.0;

  double _liveX = 0;
  double _snapStart = 0;
  bool _triggered = false;

  late final AnimationController _snapCtrl;
  late final CurvedAnimation _snapCurve;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _snapCurve = CurvedAnimation(
      parent: _snapCtrl,
      curve: Curves.easeOutCubic,
    );
    _snapCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Reset live offset after snap finishes.
        if (mounted) setState(() => _liveX = 0);
        _snapCtrl.reset();
      }
    });
  }

  @override
  void dispose() {
    _snapCurve.dispose();
    _snapCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_snapCtrl.isAnimating) return;
    final delta = d.delta.dx;
    // Only allow rightward drag.
    if (delta < 0 && _liveX <= 0) return;
    final newX = (_liveX + delta).clamp(0.0, _maxDrag);
    final prevTriggered = _triggered;
    setState(() {
      _liveX = newX;
      _triggered = newX >= _triggerAt;
    });
    if (!prevTriggered && _triggered) {
      HapticFeedback.lightImpact();
    }
  }

  void _onDragEnd(DragEndDetails _) {
    if (_liveX <= 0) return;
    _snapStart = _liveX;
    setState(() => _triggered = false);
    _snapCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return AnimatedBuilder(
      animation: _snapCtrl,
      builder: (context, child) {
        // During snap animation use the eased value; during drag use _liveX.
        final offset = _snapCtrl.isAnimating
            ? (_snapStart * (1.0 - _snapCurve.value)).clamp(0.0, _maxDrag)
            : _liveX;
        final progress = (offset / _triggerAt).clamp(0.0, 1.0);

        return GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            // Clip.none allows the bubble to translate beyond the Stack bounds.
            clipBehavior: Clip.none,
            children: [
              // Reply icon sits at the original left edge of the bubble.
              // As the bubble slides right it is progressively revealed.
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: 0.5 + 0.5 * progress,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.white16,
                        ),
                        child: Center(
                          child: AppIcon(
                            AppIcons.reply,
                            size: 13,
                            outlineColor: c.white66,
                            outlineThickness: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bubble body — translated right on drag.
              Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              ),
            ],
          ),
        );
      },
      // child is built once and reused across animation frames.
      child: _BubbleBody(bubble: widget.bubble, c: c),
    );
  }
}
