import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/nostr_comment_service.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/modals/comment_modal.dart';
import 'package:zapstore/widgets/social/quoted_message.dart';
import 'package:zapstore/widgets/social/quoted_zap_message.dart';

// ── Zap preset amounts ────────────────────────────────────────────────────────

const _kZapPresets = [1000, 2000, 5000, 10000, 25000, 50000, 100000];

// ── Public API ────────────────────────────────────────────────────────────────

/// Shows the per-comment/zap actions sheet — a port of webapp's
/// `CommentActionsModal.svelte`.
///
/// When [comment] or [zap] is provided the sheet shows the full layout:
///   - Quoted block + "Comment" CTA card
///   - Zap preset chips row (stubs — not connected yet)
///   - Actions row: Details / Label / Share (stub sub-panels)
///   - Report button (stub)
///
/// When neither is provided (e.g. BottomBar options button) it shows a compact
/// variant with just Actions + Report.
Future<void> showCommentActionsModal(
  BuildContext context, {
  Comment? comment,
  Profile? commentAuthor,
  Zap? zap,
  String? zapSenderName,
}) {
  return showModal<void>(
    context,
    builder: (_) => _CommentActionsContent(
      comment: comment,
      commentAuthor: commentAuthor,
      zap: zap,
      zapSenderName: zapSenderName,
    ),
  );
}

// ── Modal content ─────────────────────────────────────────────────────────────

class _CommentActionsContent extends ConsumerStatefulWidget {
  const _CommentActionsContent({
    this.comment,
    this.commentAuthor,
    this.zap,
    this.zapSenderName,
  });

  final Comment? comment;
  final Profile? commentAuthor;
  final Zap? zap;
  final String? zapSenderName;

  @override
  ConsumerState<_CommentActionsContent> createState() =>
      _CommentActionsContentState();
}

/// Sub-panel state — mirrors `CommentActionsModal.svelte`'s [subPanel].
enum _SubPanel { main, details, label, share, report }

class _CommentActionsContentState
    extends ConsumerState<_CommentActionsContent> {
  _SubPanel _panel = _SubPanel.main;

  bool get _hasTarget => widget.comment != null || widget.zap != null;

  void _openCommentComposer(BuildContext ctx) {
    Navigator.of(ctx).pop();
    showCommentModal(
      ctx,
      placeholder: 'Reply…',
      quotedComment: widget.comment,
      quotedCommentAuthor: widget.commentAuthor,
      quotedZap: widget.zap,
      quotedAuthorName: widget.zapSenderName,
      // Wire up publish when replying to a comment.
      // Zap-comment replies are not yet wired (they require looking up the
      // root target from the zap's tags — tracked as a future improvement).
      onSubmit: widget.comment != null
          ? (result) => publishReplyComment(
                ref: ref,
                result: result,
                parentComment: widget.comment!,
              )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_panel == _SubPanel.main) ..._buildMain(context, c),
          if (_panel == _SubPanel.details) ..._buildStubPanel(context, c, 'Details'),
          if (_panel == _SubPanel.label) ..._buildStubPanel(context, c, 'Label'),
          if (_panel == _SubPanel.share) ..._buildStubPanel(context, c, 'Share'),
          if (_panel == _SubPanel.report) ..._buildReportPanel(context, c),
        ],
      ),
    );
  }

  // ── Main panel ──────────────────────────────────────────────────────────────

  List<Widget> _buildMain(BuildContext context, LabColors c) {
    return [
      // Comment CTA card — quoted preview + reply affordance
      if (_hasTarget) ...[
        _CommentCard(
          comment: widget.comment,
          commentAuthor: widget.commentAuthor,
          zap: widget.zap,
          zapSenderName: widget.zapSenderName,
          onTap: () => _openCommentComposer(context),
          c: c,
        ),
        const SizedBox(height: 10),
      ],

      // Zap section
      if (_hasTarget) ...[
        _EyebrowLabel(text: 'Zap', c: c),
        const SizedBox(height: 8),
        _ZapChipsRow(presets: _kZapPresets, c: c),
        const SizedBox(height: 10),
      ],

      // Actions row
      _EyebrowLabel(text: 'Actions', c: c),
      const SizedBox(height: 8),
      _ActionsRow(
        onDetails: () => setState(() => _panel = _SubPanel.details),
        onLabel: () => setState(() => _panel = _SubPanel.label),
        onShare: () => setState(() => _panel = _SubPanel.share),
        c: c,
      ),
      const SizedBox(height: 10),

      // Report button
      _ReportButton(
        isZap: widget.zap != null,
        onTap: () => setState(() => _panel = _SubPanel.report),
        c: c,
      ),
    ];
  }

  // ── Stub sub-panels ─────────────────────────────────────────────────────────

  List<Widget> _buildStubPanel(BuildContext context, LabColors c, String title) {
    return [
      _SubPanelHeader(title: title, onBack: () => setState(() => _panel = _SubPanel.main), c: c),
      const SizedBox(height: 16),
      Container(
        height: 80,
        alignment: Alignment.center,
        child: Text(
          '$title panel coming soon',
          style: LabTextStyles.reg15.copyWith(color: c.white33),
        ),
      ),
    ];
  }

  List<Widget> _buildReportPanel(BuildContext context, LabColors c) {
    return [
      _SubPanelHeader(title: 'Report', onBack: () => setState(() => _panel = _SubPanel.main), c: c),
      const SizedBox(height: 16),
      Container(
        height: 80,
        alignment: Alignment.center,
        child: Text(
          'Report panel coming soon',
          style: LabTextStyles.reg15.copyWith(color: c.white33),
        ),
      ),
    ];
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Comment CTA card: quoted preview on top + reply footer.
class _CommentCard extends StatelessWidget {
  const _CommentCard({
    this.comment,
    this.commentAuthor,
    this.zap,
    this.zapSenderName,
    required this.onTap,
    required this.c,
  });

  final Comment? comment;
  final Profile? commentAuthor;
  final Zap? zap;
  final String? zapSenderName;
  final VoidCallback onTap;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    Widget quoteBlock;
    if (comment != null) {
      quoteBlock = QuotedMessage.fromComment(comment!, author: commentAuthor);
    } else if (zap != null) {
      quoteBlock = QuotedZapMessage(
        authorName: zapSenderName ?? 'Someone',
        amountSats: zap!.amount,
        contentPreview: zap!.event.content,
      );
    } else {
      quoteBlock = const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.black33,
          borderRadius: BorderRadius.circular(16),
          border: LabBorder.all(color: c.white33, width: 0.33),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quoted block
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: quoteBlock,
            ),

            // Reply footer row
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
              child: Row(
                children: [
                  LabIcon(LabIcons.reply, size: 18, color: c.white33),
                  const SizedBox(width: 10),
                  Text(
                    'Comment',
                    style: LabTextStyles.med15.copyWith(color: c.white33),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eyebrow label: "ZAP", "ACTIONS", etc.
class _EyebrowLabel extends StatelessWidget {
  const _EyebrowLabel({required this.text, required this.c});
  final String text;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Text(
        text.toUpperCase(),
        style: LabTextStyles.eyebrow13.copyWith(color: c.white33),
      ),
    );
  }
}

/// Scrollable row of zap preset chips with a chevron at the right.
class _ZapChipsRow extends StatelessWidget {
  const _ZapChipsRow({required this.presets, required this.c});
  final List<int> presets;
  final LabColors c;

  String _fmt(int n) {
    if (n >= 1000000) return '${n ~/ 1000000}M';
    if (n >= 1000) return '${n ~/ 1000}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: c.black33,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: presets.map((amt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ZapChip(label: _fmt(amt), c: c, onTap: null),
                  );
                }).toList(),
              ),
            ),
          ),
          // Chevron — opens full zap slider (stub)
          Container(
            width: 32,
            height: 36,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: c.white8,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: LabIcon(LabIcons.chevronDown, size: 14, color: c.white66),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZapChip extends StatelessWidget {
  const _ZapChip({required this.label, required this.c, this.onTap});
  final String label;
  final LabColors c;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.white8,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LabIcon(LabIcons.zap, size: 12, gradient: c.gold),
            const SizedBox(width: 4),
            Text(
              label,
              style: LabTextStyles.semibold15.copyWith(color: c.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three equal action tiles: Details / Label / Share.
class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.onDetails,
    required this.onLabel,
    required this.onShare,
    required this.c,
  });
  final VoidCallback onDetails;
  final VoidCallback onLabel;
  final VoidCallback onShare;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionTile(icon: LabIcons.details, label: 'Details', onTap: onDetails, c: c),
        const SizedBox(width: 12),
        _ActionTile(icon: LabIcons.label, label: 'Label', onTap: onLabel, c: c),
        const SizedBox(width: 12),
        _ActionTile(icon: LabIcons.share, label: 'Share', onTap: onShare, c: c),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.c,
  });
  final String icon;
  final String label;
  final VoidCallback onTap;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
          decoration: BoxDecoration(
            color: c.black33,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: LabIcon(icon, size: 24, color: c.white66),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: LabTextStyles.med15.copyWith(color: c.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width rouge report button.
class _ReportButton extends StatelessWidget {
  const _ReportButton({
    required this.isZap,
    required this.onTap,
    required this.c,
  });
  final bool isZap;
  final VoidCallback onTap;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.black33,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          isZap ? 'Report this zap' : 'Report this comment',
          style: LabTextStyles.med15.copyWith(color: c.rougeColor),
        ),
      ),
    );
  }
}

/// Back-button header for sub-panels.
class _SubPanelHeader extends StatelessWidget {
  const _SubPanelHeader({
    required this.title,
    required this.onBack,
    required this.c,
  });
  final String title;
  final VoidCallback onBack;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.white8,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: LabIcon(LabIcons.chevronLeft, size: 14, color: c.white66),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: LabTextStyles.semibold17.copyWith(color: c.white),
        ),
      ],
    );
  }
}
