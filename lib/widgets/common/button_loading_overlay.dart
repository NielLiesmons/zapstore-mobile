import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';

/// Subtle pulsing [LabColors.white8] overlay for in-progress buttons.
///
/// Replaces spinner glyphs — the label stays visible underneath.
class ButtonLoadingOverlay extends StatefulWidget {
  const ButtonLoadingOverlay({
    super.key,
    required this.active,
    required this.child,
    this.borderRadius = 17,
  });

  final bool active;
  final Widget child;
  final double borderRadius;

  @override
  State<ButtonLoadingOverlay> createState() => _ButtonLoadingOverlayState();
}

class _ButtonLoadingOverlayState extends State<ButtonLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (widget.active)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: FadeTransition(
                  opacity: _opacity,
                  child: ColoredBox(color: c.white8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
