import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/widgets/common/read_more_button.dart';

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
  static const double _fadeHeight = 56.0;

  @override
  Widget build(BuildContext context) {
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
            ReadMoreButton(
              label: 'Show less',
              onTap: () => expanded.value = false,
            ),
          ],
        ],
      );
    }

    return SizedBox(
      height: _collapsedMaxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (bounds) {
                final fadeStart =
                    ((bounds.height - _fadeHeight) / bounds.height)
                        .clamp(0.0, 1.0);
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: [0.0, fadeStart, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ClipRect(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: content,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: ReadMoreButton(
              label: 'Read more',
              onTap: () => expanded.value = true,
            ),
          ),
        ],
      ),
    );
  }
}
