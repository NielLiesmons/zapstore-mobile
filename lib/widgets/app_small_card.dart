import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/utils/url_utils.dart';
import 'package:zapstore/widgets/common/app_pic.dart';

/// Compact app card matching webapp's AppSmallCard.svelte:
/// 56px icon + name (semibold17) + 1-line description (reg13).
/// Used in the horizontal "Latest Apps" scroll on the discover page.
class AppSmallCard extends StatelessWidget {
  const AppSmallCard({super.key, required this.app});

  final App app;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final description = app.description.isNotEmpty
        ? _stripMarkdown(app.description)
        : '';

    return GestureDetector(
      onTap: () => pushApp(
        context,
        app.identifier,
        author: app.pubkey,
        kind: app.event.kind,
      ),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPic(
            iconUrl: firstValidHttpUrl(app.icons),
            name: app.name,
            identifier: app.identifier,
            size: 56,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name ?? app.identifier,
                    style: LabTextStyles.semibold17.copyWith(color: c.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description.isNotEmpty ? description : 'No description',
                    style: LabTextStyles.reg13.copyWith(
                      color: description.isNotEmpty ? c.white66 : c.white33,
                    ),
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

  static String _stripMarkdown(String input) {
    final doc = md.Document(encodeHtml: false);
    final nodes = doc.parseLines(input.split('\n'));
    final buffer = StringBuffer();

    void writeNode(md.Node node) {
      if (node is md.Text) {
        buffer.write(node.text);
        return;
      }
      if (node is md.Element) {
        if (node.tag == 'br') buffer.write(' ');
        for (final child in node.children ?? []) {
          writeNode(child);
        }
        if (const {'p', 'li', 'ul', 'ol', 'blockquote', 'h1', 'h2', 'h3'}
            .contains(node.tag)) {
          buffer.write(' ');
        }
      }
    }

    for (final node in nodes) {
      writeNode(node);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
