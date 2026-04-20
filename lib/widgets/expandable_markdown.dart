import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/utils/text_styles.dart';

class ExpandableMarkdown extends HookWidget {
  const ExpandableMarkdown({
    super.key,
    required this.data,
    this.onTapLink,
    this.styleSheet,
  });

  final String data;
  final void Function(String, String?, String?)? onTapLink;
  final MarkdownStyleSheet? styleSheet;

  static const double _collapsedMaxHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final expanded = useState(false);

    bool isLikelyLong(String text) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) return false;
      final wordCount = trimmed.split(RegExp(r'\s+')).length;
      final newlineCount = '\n'.allMatches(trimmed).length;
      final charCount = trimmed.length;
      return wordCount > 60 || newlineCount > 4 || charCount > 300;
    }

    final shouldCollapse = !expanded.value && isLikelyLong(data);

    final effectiveTapLink = onTapLink ??
        (String text, String? href, String? title) {
          if (href != null) navigateToContent(context, href);
        };

    final content = MarkdownBody(
      data: data,
      onTapLink: effectiveTapLink,
      styleSheet: styleSheet,
    );

    if (!shouldCollapse) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          if (expanded.value) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => expanded.value = false,
              child: _ReadMorePill(label: 'Show less', colors: c),
            ),
          ],
        ],
      );
    }

    return Stack(
      children: [
        // Collapsed content, clipped at maxHeight
        SizedBox(
          height: _collapsedMaxHeight,
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: content,
            ),
          ),
        ),

        // Gradient overlay fading content into background
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 80,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, c.black],
                ),
              ),
            ),
          ),
        ),

        // "Read More" pill button, absolute at bottom-left
        Positioned(
          left: 0,
          bottom: 8,
          child: GestureDetector(
            onTap: () => expanded.value = true,
            child: _ReadMorePill(label: 'Read More', colors: c),
          ),
        ),
      ],
    );
  }
}

class _ReadMorePill extends StatelessWidget {
  const _ReadMorePill({required this.label, required this.colors});

  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colors.white8,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.med13.copyWith(color: colors.white66),
          ),
        ),
      ),
    );
  }
}
