import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/social/code_block.dart';

/// Details tab — matches webapp's DetailsTab.svelte exactly.
///
/// Layout: "IDENTIFIERS" eyebrow → gray66 panel with rows separated by
/// 1.4px white11 dividers → optional "RAW DATA" eyebrow + CodeBlock.
/// Each row has its own animated copy button (copy → check feedback).
class DetailsTab extends StatelessWidget {
  const DetailsTab({
    super.key,
    this.shareableId,
    this.publicationLabel = 'Publication',
    this.npub,
    this.pubkey,
    this.rawData,
    this.repository,
    this.shareLink,
    this.panelBackground = _PanelBg.gray66,
  });

  final String? shareableId;
  final String publicationLabel;
  final String? npub;
  final String? pubkey;
  final String? rawData;
  final String? repository;
  final String? shareLink;
  final _PanelBg panelBackground;

  String _formatShareableId(String id) {
    if (id.length < 30) return id;
    return '${id.substring(0, 16)}...${id.substring(id.length - 8)}';
  }

  String _urlWithoutProtocol(String url) =>
      url.replaceAll(RegExp(r'^https?://'), '');

  String _truncateNpub(String n) {
    if (n.length < 14) return n;
    final prefix = n.startsWith('npub1') ? 'npub1${n.substring(5, 8)}' : n.substring(0, 3);
    return '$prefix......${n.substring(n.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final bg = panelBackground == _PanelBg.black33 ? c.black33 : c.gray66;
    final codeBlockBg = panelBackground == _PanelBg.black33;

    // Build the list of identifier rows in order
    final rows = <_RowData>[];

    if (shareableId != null && shareableId!.isNotEmpty) {
      rows.add(_RowData(
        label: publicationLabel,
        displayValue: _formatShareableId(shareableId!),
        copyValue: shareableId!,
      ));
    }

    if (shareLink != null && shareLink!.isNotEmpty) {
      rows.add(_RowData(
        label: 'Share link',
        displayValue: _urlWithoutProtocol(shareLink!),
        copyValue: shareLink!,
      ));
    }

    if (npub != null && npub!.isNotEmpty) {
      rows.add(_RowData(
        label: 'Profile',
        displayValue: _truncateNpub(npub!),
        copyValue: npub!,
      ));
    }

    if (repository != null && repository!.isNotEmpty) {
      rows.add(_RowData(
        label: 'Repository',
        displayValue: _urlWithoutProtocol(repository!),
        copyValue: repository!,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "IDENTIFIERS" eyebrow label
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text(
              'IDENTIFIERS',
              style: AppTextStyles.h3.copyWith(color: c.white33),
            ),
          ),

          // Identifier panel
          if (rows.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < rows.length; i++) ...[
                      _IdentifierRow(row: rows[i], c: c),
                      if (i < rows.length - 1)
                        Container(height: 1.4, color: c.white11),
                    ],
                  ],
                ),
              ),
            ),

          // Raw event data
          if (rawData != null && rawData!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                'RAW DATA',
                style: AppTextStyles.h3.copyWith(color: c.white33),
              ),
            ),
            CodeBlock(
              code: rawData!,
              language: 'JSON',
              useBlackBackground: codeBlockBg,
            ),
          ],
        ],
      ),
    );
  }
}

enum _PanelBg { gray66, black33 }

class _RowData {
  const _RowData({
    required this.label,
    required this.displayValue,
    required this.copyValue,
  });
  final String label;
  final String displayValue;
  final String copyValue;
}

class _IdentifierRow extends StatefulWidget {
  const _IdentifierRow({required this.row, required this.c});
  final _RowData row;
  final AppColors c;

  @override
  State<_IdentifierRow> createState() => _IdentifierRowState();
}

class _IdentifierRowState extends State<_IdentifierRow> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.row.copyValue));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          // Label — fixed width so values align
          SizedBox(
            width: 80,
            child: Text(
              widget.row.label,
              style: AppTextStyles.reg15.copyWith(color: c.white),
            ),
          ),

          // Value — flex, right-aligned, truncated
          Expanded(
            child: Text(
              widget.row.displayValue,
              style: AppTextStyles.reg15.copyWith(color: c.white66),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),

          const SizedBox(width: 14),

          // Animated copy button (32×32, white8 bg, r8)
          GestureDetector(
            onTap: _handleCopy,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Container(
                key: ValueKey(_copied),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.white8,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: _copied
                      ? AppIcon(AppIcons.check, size: 14,
                          color: c.blurpleLightColor)
                      : AppIcon(AppIcons.copy, size: 16,
                          outlineColor: c.white66, outlineThickness: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
