import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Defers building [child] until the user scrolls near [mountOffset].
///
/// Mirrors webapp profile Activity `IntersectionObserver` sentinel — avoids
/// subscribing to heavy activity queries until the section is approached.
class LazyMountOnScroll extends HookWidget {
  const LazyMountOnScroll({
    super.key,
    required this.scrollController,
    required this.placeholder,
    required this.child,
    this.mountOffset = 400,
  });

  final ScrollController scrollController;
  final Widget placeholder;
  final Widget child;

  /// Scroll offset (px) past which [child] is mounted.
  final double mountOffset;

  @override
  Widget build(BuildContext context) {
    final mounted = useState(false);

    useEffect(() {
      void check() {
        if (mounted.value) return;
        if (!scrollController.hasClients) return;
        final pos = scrollController.position;
        if (pos.pixels + pos.viewportDimension >= mountOffset) {
          mounted.value = true;
        }
      }

      scrollController.addListener(check);
      WidgetsBinding.instance.addPostFrameCallback((_) => check());
      return () => scrollController.removeListener(check);
    }, [scrollController]);

    return mounted.value ? child : placeholder;
  }
}
