import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Compact quote block for a zap-with-message, matching webapp's
/// QuotedZapMessage.svelte.
///
/// Layout:
///   [2.8px gold accent bar] [⚡ amount pill] [author name (gold)] [content preview]
///
/// Used in [CommentActionsModal] and the composer when replying to a zap.
class QuotedZapMessage extends StatelessWidget {
  const QuotedZapMessage({
    super.key,
    required this.authorName,
    required this.amountSats,
    this.contentPreview = '',
  });

  final String authorName;
  final int amountSats;
  final String contentPreview;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    final preview = contentPreview.length > 80
        ? '${contentPreview.substring(0, 80)}…'
        : contentPreview;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: c.white8,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gold accent bar
            Container(
              width: 2.8,
              decoration: BoxDecoration(
                gradient: c.gold,
              ),
            ),

            // Body: zap pill + name + content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Author row: gold-gradient name + zap amount
                    Row(
                      children: [
                        Flexible(
                          child: ShaderMask(
                            shaderCallback: (b) => c.gold.createShader(b),
                            child: Text(
                              authorName,
                              style: LabTextStyles.semibold13
                                  .copyWith(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        LabIcon(LabIcons.zap, size: 11, gradient: c.gold),
                        const SizedBox(width: 2),
                        Text(
                          _formatAmount(amountSats),
                          style: LabTextStyles.semibold13.copyWith(
                            color: const Color(0xFFFFB338),
                          ),
                        ),
                      ],
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        style: LabTextStyles.reg13.copyWith(color: c.white66),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatAmount(int val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(val % 1000000 == 0 ? 0 : 1)}M';
    }
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(val % 1000 == 0 ? 0 : 1)}K';
    }
    return val.toString();
  }
}
