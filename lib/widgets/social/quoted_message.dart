import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Compact quote block matching webapp's QuotedMessage.svelte.
///
/// Layout:
///   [2.8px accent bar (pubkey-derived color)] [author name (colored)] [content preview]
///
/// Used in:
///   - Reply bubbles inside [_ThreadBody] when a reply's parent is not the root
///   - The comment composer modal when replying (swipe-right → reply with context)
///   - [CommentActionsModal] as a preview of the target comment
class QuotedMessage extends StatelessWidget {
  const QuotedMessage({
    super.key,
    required this.authorName,
    this.authorPubkey,
    this.contentPreview = '',
  });

  final String authorName;
  final String? authorPubkey;

  /// Plain text preview — truncated to ~80 chars.
  final String contentPreview;

  factory QuotedMessage.fromComment(Comment comment, {Profile? author}) {
    final name = author?.name?.trim().isNotEmpty == true
        ? author!.name!.trim()
        : _abbreviatePubkey(comment.event.pubkey);
    final preview = comment.content.replaceAll('\n', ' ').trim();
    return QuotedMessage(
      authorName: name,
      authorPubkey: comment.event.pubkey,
      contentPreview: preview.length > 80
          ? '${preview.substring(0, 80)}…'
          : preview,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    final accentColor = () {
      if (authorPubkey != null && authorPubkey!.isNotEmpty) {
        return hexToColor(authorPubkey!);
      }
      if (authorName.isNotEmpty) {
        return stringToColor(authorName);
      }
      return c.white33;
    }();

    final nameColor = profileTextColor(accentColor);

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2.8px colored accent bar — matches .quoted-bar in webapp
          Container(
            width: 2.8,
            height: 40,
            color: accentColor,
          ),

          // Body: name + content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    authorName,
                    style: LabTextStyles.semibold13.copyWith(color: nameColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    preview.isEmpty ? ' ' : preview,
                    style: LabTextStyles.reg13.copyWith(color: c.white66),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _abbreviatePubkey(String pubkey) {
    if (pubkey.length < 14) return pubkey;
    return 'npub1${pubkey.substring(0, 3)}…${pubkey.substring(pubkey.length - 6)}';
  }
}
