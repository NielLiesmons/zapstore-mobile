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
        padding: const EdgeInsets.only(top: 4, left: 14, right: 14),
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
      padding: const EdgeInsets.only(top: 4, left: 14, right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        // mainAxisSize: max (default) — fills available width so Flexible below
        // has a finite remaining space to give to IntrinsicWidth.
        children: [
          Flexible(
            child: IntrinsicWidth(
              child: _IncomingBubbleSwiper(
                  bubble: widget, avatar: avatarWidget, c: c),
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

// ─────────────────────────────────────────────────────────────────────────────
// Unified swipe handler for incoming bubbles
// ─────────────────────────────────────────────────────────────────────────────

/// Handles both swipe directions for incoming [MessageBubble]s in one widget.
///
/// RIGHT swipe → only the bubble body slides right.
///   Reply circle is revealed in the gap between avatar and bubble.
/// LEFT swipe  → avatar + bubble translate together as one unit.
///   Options circle is revealed to the right of the bubble.
///
/// Single GestureDetector; two nested Transform.translate calls
/// (outer for left, inner for right) — exactly mirrors the right-swipe
/// behaviour but at one level higher for the left direction.
class _IncomingBubbleSwiper extends StatefulWidget {
  const _IncomingBubbleSwiper({
    required this.bubble,
    required this.avatar,
    required this.c,
  });

  final MessageBubble bubble;
  final Widget avatar;
  final LabColors c;

  @override
  State<_IncomingBubbleSwiper> createState() => _IncomingBubbleSwiperState();
}

class _IncomingBubbleSwiperState extends State<_IncomingBubbleSwiper>
    with TickerProviderStateMixin {
  static const double _maxDrag   = 56.0;
  static const double _triggerAt = 32.0;

  double _liveX     = 0;
  double _snapStart = 0;
  bool   _triggered = false;
  bool?  _goingRight;

  late final AnimationController _snapCtrl;
  late final CurvedAnimation     _snapCurve;
  late final AnimationController _popCtrl;
  late final Animation<double>   _popScale;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _snapCurve =
        CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutCubic);
    _snapCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() { _liveX = 0; _goingRight = null; });
        _snapStart = 0.0; // clear before reset to avoid spurious addListener
        _snapCtrl.reset();
      }
    });
    _popCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 140));
    _popScale = Tween<double>(begin: 1.0, end: 1.2)
        .animate(CurvedAnimation(parent: _popCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _snapCurve.dispose();
    _snapCtrl.dispose();
    _popCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_snapCtrl.isAnimating) return;
    final delta = d.delta.dx;
    if (_goingRight == null) {
      if (delta.abs() < 1) return;
      _goingRight = delta > 0;
    }
    if (_goingRight! && delta < 0 && _liveX <= 0) return;
    if (!_goingRight! && delta > 0 && _liveX >= 0) return;

    final newX = (_liveX + delta).clamp(-_maxDrag, _maxDrag);
    final prevTriggered = _triggered;
    setState(() {
      _liveX = newX;
      _triggered = newX.abs() >= _triggerAt;
    });

    if (!prevTriggered && _triggered) {
      HapticFeedback.lightImpact();
      _popCtrl.forward(from: 0).then((_) {
        if (mounted) _popCtrl.reverse();
      });
      Future.delayed(const Duration(milliseconds: 70), () {
        if (!mounted) return;
        if (_liveX > 0) widget.bubble.onReply?.call();
        else            widget.bubble.onActions?.call();
      });
    }
  }

  void _onDragEnd(DragEndDetails _) {
    if (_liveX == 0) return;
    _snapStart = _liveX;
    setState(() { _triggered = false; _goingRight = null; });
    _snapCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return AnimatedBuilder(
      animation: Listenable.merge([_snapCtrl, _popCtrl]),
      builder: (context, _) {
        final offset = _snapCtrl.isAnimating
            ? _snapStart * (1.0 - _snapCurve.value)
            : _liveX;

        // Left drag:  whole row (avatar + bubble) moves together.
        final leftOffset  = offset.clamp(-_maxDrag, 0.0);
        // Right drag: only the bubble body moves.
        final rightOffset = offset.clamp(0.0, _maxDrag);

        final rightProg = (offset / _triggerAt).clamp(0.0, 1.0);
        final leftProg  = (-offset / _triggerAt).clamp(0.0, 1.0);
        final popMult   = _popScale.value;

        return GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Reply circle ──────────────────────────────────────────────
              // avatar(36) + gap(6) = 42px; starts 8px inside bubble left edge.
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(left: 50),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Opacity(
                      opacity: rightProg,
                      child: Transform.scale(
                        scale: (0.5 + 0.5 * rightProg) * popMult,
                        child: _SwipeCircle(icon: LabIcons.reply, c: c),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Options circle ────────────────────────────────────────────
              // Fixed at the right edge of the Stack; revealed as the row
              // slides left.
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Opacity(
                      opacity: leftProg,
                      child: Transform.scale(
                        scale: (0.5 + 0.5 * leftProg) * popMult,
                        child: _SwipeCircle(icon: LabIcons.options, c: c),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Content ───────────────────────────────────────────────────
              // Left drag: the whole row (avatar + bubble) moves together.
              // The outer Flexible+IntrinsicWidth in _MessageBubbleState gives
              // this Stack tight constraints so CrossAxisAlignment.stretch in
              // _BubbleBody works correctly. The inner Row uses the default
              // mainAxisSize.max to fill those tight constraints.
              Transform.translate(
                offset: Offset(leftOffset, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  // mainAxisSize: max (default) — fills Stack tight constraints
                  // propagated from the outer IntrinsicWidth in _MessageBubbleState.
                  children: [
                    widget.avatar,
                    const SizedBox(width: 6),
                    // Flexible: gets remaining width (= bubble intrinsic width).
                    // Right drag: only the bubble body translates.
                    Flexible(
                      child: Transform.translate(
                        offset: Offset(rightOffset, 0),
                        child: _BubbleBody(bubble: widget.bubble, c: widget.c),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SwipeCircle extends StatelessWidget {
  const _SwipeCircle({required this.icon, required this.c});
  final String icon;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.gray33),
      child: Center(
        child: LabIcon(icon, size: 13, color: c.white33),
      ),
    );
  }
}
