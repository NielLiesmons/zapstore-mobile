import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';

/// Opens a full-screen image lightbox:
///   • blurred dark backdrop, tap outside the image to close
///   • X close button (top-right, circular)
///   • swipeable PageView (no chevron buttons — native swipe on mobile)
///   • dot indicators at bottom when multiple images
///   • keyboard: Escape = close, ← / → = prev/next
void showMediaLightbox(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
}) {
  if (urls.isEmpty) return;
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) => MediaLightbox(
        urls: urls,
        initialIndex: initialIndex.clamp(0, urls.length - 1),
      ),
      transitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class MediaLightbox extends StatefulWidget {
  const MediaLightbox({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<MediaLightbox> createState() => _MediaLightboxState();
}

class _MediaLightboxState extends State<MediaLightbox> {
  late int _index;
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _hasMultiple => widget.urls.length > 1;

  void _animateTo(int i) {
    setState(() => _index = i);
    _ctrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final pad = MediaQuery.paddingOf(context);

    return KeyboardListener(
      autofocus: true,
      focusNode: FocusNode(),
      onKeyEvent: (e) {
        if (e is! KeyDownEvent) return;
        if (e.logicalKey == LogicalKeyboardKey.escape) Navigator.pop(context);
        if (_hasMultiple && e.logicalKey == LogicalKeyboardKey.arrowLeft) _animateTo((_index - 1 + widget.urls.length) % widget.urls.length);
        if (_hasMultiple && e.logicalKey == LogicalKeyboardKey.arrowRight) _animateTo((_index + 1) % widget.urls.length);
      },
      child: Stack(
        children: [
          // ── Blurred dark backdrop (fills screen, no tap handler needed —
          //    tap-to-close is handled per-page in _ImagePage) ─────────────
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: ColoredBox(
                  color: c.black.withValues(alpha: 0.92),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),

          // ── Swipeable images (each page handles tap-outside-to-close) ───
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _ImagePage(url: widget.urls[i]),
          ),

          // ── Close button ────────────────────────────────────────────────
          Positioned(
            top: pad.top + 12,
            right: 16,
            child: _CircleBtn(
              onTap: () => Navigator.pop(context),
              child: LabIcon(LabIcons.cross, size: 16, color: c.white),
            ),
          ),

          // ── Dot indicators ──────────────────────────────────────────────
          if (_hasMultiple)
            Positioned(
              bottom: pad.bottom + 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < widget.urls.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _animateTo(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? c.white
                              : c.white.withValues(alpha: 0.33),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ImagePage extends StatelessWidget {
  const _ImagePage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    // Tap anywhere outside the image card closes the lightbox.
    // An inner GestureDetector on the card itself absorbs the tap so that
    // tapping the image does NOT trigger close.
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: GestureDetector(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: c.white.withValues(alpha: 0.16),
                  width: 0.33,
                ),
                color: c.gray33,
                boxShadow: [
                  BoxShadow(
                    color: c.black.withValues(alpha: 0.33),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.white.withValues(alpha: 0.16),
        ),
        child: Center(child: child),
      ),
    );
  }
}
