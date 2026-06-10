import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';

/// How far swipe-action icons drift opposite to the drag (0–1 of bubble travel).
const double kBubbleSwipeIconParallax = 0.45;

/// Horizontal swipe gestures on a chat bubble: right → reply, left → options.
///
/// When [leading] is set (incoming [MessageBubble]), a right swipe moves only
/// the bubble; a left swipe moves the avatar and bubble together. When [leading]
/// is null ([CommentCard] feed bubbles), the bubble alone translates both ways.
///
/// Layout: a [Column] + translated child establishes intrinsic height for
/// [IntrinsicHeight] ancestors. Swipe icons are [Positioned] overlays only.
class BubbleSwiper extends StatefulWidget {
  const BubbleSwiper({
    super.key,
    this.leading,
    required this.child,
    required this.c,
    this.onReply,
    this.onActions,
    this.replyIconInset = 50,
    this.optionsIconInset = 8,
  });

  final Widget? leading;
  final Widget child;
  final LabColors c;
  final VoidCallback? onReply;
  final VoidCallback? onActions;

  /// Left inset for the reply icon circle.
  final double replyIconInset;

  /// Right inset for the options icon circle.
  final double optionsIconInset;

  @override
  State<BubbleSwiper> createState() => _BubbleSwiperState();
}

class _BubbleSwiperState extends State<BubbleSwiper>
    with TickerProviderStateMixin {
  static const double _maxDrag = 56.0;
  static const double _triggerAt = 32.0;

  double _liveX = 0;
  double _snapStart = 0;
  bool _triggered = false;
  bool? _goingRight;

  late final AnimationController _snapCtrl;
  late final CurvedAnimation _snapCurve;
  late final AnimationController _popCtrl;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _snapCurve = CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutCubic);
    _snapCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() {
          _liveX = 0;
          _goingRight = null;
        });
        _snapStart = 0.0;
        _snapCtrl.reset();
      }
    });
    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _popScale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _popCtrl, curve: Curves.easeOut),
    );
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
        if (_liveX > 0) {
          widget.onReply?.call();
        } else {
          widget.onActions?.call();
        }
      });
    }
  }

  void _onDragEnd(DragEndDetails _) {
    if (_liveX == 0) return;
    _snapStart = _liveX;
    setState(() {
      _triggered = false;
      _goingRight = null;
    });
    _snapCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final hasLeading = widget.leading != null;

    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: ListenableBuilder(
        listenable: Listenable.merge([_snapCtrl, _popCtrl]),
        builder: (context, _) {
          final offset = _snapCtrl.isAnimating
              ? _snapStart * (1.0 - _snapCurve.value)
              : _liveX;

          final leftOffset = hasLeading ? offset.clamp(-_maxDrag, 0.0) : 0.0;
          final rightOffset = hasLeading ? offset.clamp(0.0, _maxDrag) : 0.0;
          final soloOffset = hasLeading ? 0.0 : offset;

          final rightDrag =
              hasLeading ? rightOffset : offset.clamp(0.0, _maxDrag);
          final leftDrag =
              hasLeading ? -leftOffset : (-offset).clamp(0.0, _maxDrag);

          final rightProg = (rightDrag / _triggerAt).clamp(0.0, 1.0);
          final leftProg = (leftDrag / _triggerAt).clamp(0.0, 1.0);
          final popMult = _popScale.value;

          final replyParallaxX = -rightDrag * kBubbleSwipeIconParallax;
          final optionsParallaxX = leftDrag * kBubbleSwipeIconParallax;

          // Bubble sizes the [Stack]; swipe icons overlay via [Positioned.fill].
          // (Icons with top+bottom before the child broke intrinsic height.)
          final bubble = hasLeading
              ? Transform.translate(
                  offset: Offset(leftOffset, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      widget.leading!,
                      const SizedBox(width: 6),
                      Flexible(
                        child: Transform.translate(
                          offset: Offset(rightOffset, 0),
                          child: widget.child,
                        ),
                      ),
                    ],
                  ),
                )
              : Transform.translate(
                  offset: Offset(soloOffset, 0),
                  child: widget.child,
                );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  bubble,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding:
                                EdgeInsets.only(left: widget.replyIconInset),
                            child: Opacity(
                              opacity: rightProg,
                              child: Transform.translate(
                                offset: Offset(replyParallaxX, 0),
                                child: Transform.scale(
                                  scale: (0.5 + 0.5 * rightProg) * popMult,
                                  child:
                                      _SwipeCircle(icon: LabIcons.reply, c: c),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: EdgeInsets.only(
                              right: widget.optionsIconInset,
                            ),
                            child: Opacity(
                              opacity: leftProg,
                              child: Transform.translate(
                                offset: Offset(optionsParallaxX, 0),
                                child: Transform.scale(
                                  scale: (0.5 + 0.5 * leftProg) * popMult,
                                  child: _SwipeCircle(
                                    icon: LabIcons.options,
                                    c: c,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
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
