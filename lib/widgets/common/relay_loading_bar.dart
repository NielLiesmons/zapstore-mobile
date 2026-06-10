import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';

/// Indeterminate shimmer bar shown while a relay fetch is in flight — port of
/// webapp `RelayLoadingBar.svelte`. Drop below tab pills / panel headers.
class RelayLoadingBar extends StatefulWidget {
  const RelayLoadingBar({super.key, required this.loading});

  final bool loading;

  @override
  State<RelayLoadingBar> createState() => _RelayLoadingBarState();
}

class _RelayLoadingBarState extends State<RelayLoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.loading) _controller.repeat();
  }

  @override
  void didUpdateWidget(RelayLoadingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.loading && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.loading) return const SizedBox.shrink();

    final c = Theme.of(context).extension<LabColors>()!;

    return SizedBox(
      height: 2,
      width: double.infinity,
      child: ClipRect(
        child: ColoredBox(
          color: c.blurpleColor.withValues(alpha: 0.12),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FractionallySizedBox(
                widthFactor: 0.55,
                alignment: Alignment(
                  -1 + (_controller.value * 3.82),
                  0,
                ),
                child: child,
              );
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c.blurpleColor.withValues(alpha: 0),
                    c.blurpleColor.withValues(alpha: 0.66),
                    c.blurpleColor.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
