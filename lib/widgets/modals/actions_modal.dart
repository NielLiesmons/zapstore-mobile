import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/nostr_comment_service.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/composer/nostr_text_controller.dart'
    show ComposerResult;
import 'package:zapstore/widgets/modals/comment_modal.dart';
import 'package:zapstore/widgets/social/quoted_message.dart';
import 'package:zapstore/widgets/social/quoted_zap_message.dart';
import 'package:zapstore/widgets/social/thread_root.dart';

// ── Handoff token — parent keeps nested dim while comment sheet opens ─────────

const _kHandoffComment = 'actions-handoff-comment';

/// Content kinds supported by [showActionsModal] — mirrors webapp ActionsModal.
enum ActionsContentType { comment, zap, app, stack, forum }

// ── Public API ────────────────────────────────────────────────────────────────

/// Unified actions sheet — port of webapp `ActionsModal.svelte`.
///
/// When opened inside another [showModal] (e.g. thread modal), the parent
/// scales/dims via [ModalNestScope] and this sheet uses a transparent barrier.
Future<void> showActionsModal(
  BuildContext context, {
  ActionsContentType contentType = ActionsContentType.comment,
  Comment? comment,
  Profile? commentAuthor,
  Zap? zap,
  String? zapSenderName,
  ThreadRootContext? rootContext,
  String? version,
  VoidCallback? onComment,
  Future<void> Function(ComposerResult result)? onCommentSubmit,
  WidgetRef? ref,
}) async {
  final isNested = ModalNestScope.maybeOf(context) != null;
  if (isNested) ModalNestScope.setNested(context, isOpen: true);

  final handoff = await showModal<String>(
    context,
    nestedModal: isNested,
    builder: (ctx) => _ActionsModalContent(
      contentType: contentType,
      comment: comment,
      commentAuthor: commentAuthor,
      zap: zap,
      zapSenderName: zapSenderName,
      rootContext: rootContext,
      version: version,
      onComment: onComment,
      onCommentSubmit: onCommentSubmit,
    ),
  );

  if (!context.mounted) return;

  if (handoff == _kHandoffComment) {
    await showCommentModal(
      context,
      nestedModal: isNested,
      placeholder: _commentPlaceholder(contentType, rootContext),
      rootContext: rootContext,
      version: version,
      showRootConnector: rootContext != null,
      quotedComment: comment,
      quotedCommentAuthor: commentAuthor,
      quotedZap: zap,
      quotedAuthorName: zapSenderName,
      onSubmit: onCommentSubmit ??
          (comment != null && ref != null
              ? (result) => publishReplyComment(
                    ref: ref,
                    result: result,
                    parentComment: comment,
                  )
              : null),
    );
  }

  if (isNested && context.mounted) {
    ModalNestScope.setNested(context, isOpen: false);
  }
}

String _commentPlaceholder(
  ActionsContentType type,
  ThreadRootContext? root,
) {
  final label = root?.label;
  return switch (type) {
    ActionsContentType.app =>
      'Comment on ${label ?? 'this app'}…',
    ActionsContentType.stack =>
      'Comment on ${label ?? 'this stack'}…',
    ActionsContentType.forum =>
      'Comment on ${label ?? 'this post'}…',
    _ => 'Reply…',
  };
}

/// Backward-compatible alias.
Future<void> showCommentActionsModal(
  BuildContext context, {
  Comment? comment,
  Profile? commentAuthor,
  Zap? zap,
  String? zapSenderName,
  ThreadRootContext? rootContext,
  String? version,
  VoidCallback? onComment,
  Future<void> Function(ComposerResult result)? onCommentSubmit,
  ActionsContentType? contentType,
  WidgetRef? ref,
}) {
  final type = contentType ??
      (zap != null
          ? ActionsContentType.zap
          : comment != null
              ? ActionsContentType.comment
              : rootContext?.isApp == true
                  ? ActionsContentType.app
                  : rootContext?.isStack == true
                      ? ActionsContentType.stack
                      : rootContext?.isForum == true
                          ? ActionsContentType.forum
                          : ActionsContentType.comment);

  return showActionsModal(
    context,
    contentType: type,
    comment: comment,
    commentAuthor: commentAuthor,
    zap: zap,
    zapSenderName: zapSenderName,
    rootContext: rootContext,
    version: version,
    onComment: onComment,
    onCommentSubmit: onCommentSubmit,
    ref: ref,
  );
}

// ── Modal content ─────────────────────────────────────────────────────────────

enum _SubPanel { main, details, label, share, report }

class _ActionsModalContent extends ConsumerStatefulWidget {
  const _ActionsModalContent({
    required this.contentType,
    this.comment,
    this.commentAuthor,
    this.zap,
    this.zapSenderName,
    this.rootContext,
    this.version,
    this.onComment,
    this.onCommentSubmit,
  });

  final ActionsContentType contentType;
  final Comment? comment;
  final Profile? commentAuthor;
  final Zap? zap;
  final String? zapSenderName;
  final ThreadRootContext? rootContext;
  final String? version;
  final VoidCallback? onComment;
  final Future<void> Function(ComposerResult result)? onCommentSubmit;

  @override
  ConsumerState<_ActionsModalContent> createState() =>
      _ActionsModalContentState();
}

class _ActionsModalContentState extends ConsumerState<_ActionsModalContent> {
  _SubPanel _panel = _SubPanel.main;

  bool get _isCatalog => switch (widget.contentType) {
        ActionsContentType.app ||
        ActionsContentType.stack ||
        ActionsContentType.forum =>
          true,
        _ => false,
      };

  bool get _hasSocialTarget =>
      widget.comment != null || widget.zap != null;

  bool get _showStacksSection => widget.contentType == ActionsContentType.app;

  /// Catalog-only (app/stack/forum sheet). Never on comment/zap actions —
  /// the quoted target already shows what we're acting on.
  bool get _showRootRow =>
      _isCatalog && widget.rootContext != null && !_hasSocialTarget;

  void _chooseComment() {
    if (_isCatalog && widget.onCommentSubmit != null) {
      Navigator.of(context).pop(_kHandoffComment);
      return;
    }
    if (widget.onComment != null) {
      Navigator.of(context).pop();
      widget.onComment!();
      return;
    }
    if (_hasSocialTarget) {
      Navigator.of(context).pop(_kHandoffComment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_panel == _SubPanel.main) ..._buildMain(context, c),
          if (_panel == _SubPanel.details)
            ..._buildStubPanel(context, c, 'Details'),
          if (_panel == _SubPanel.label) ..._buildStubPanel(context, c, 'Label'),
          if (_panel == _SubPanel.share) ..._buildStubPanel(context, c, 'Share'),
          if (_panel == _SubPanel.report) ..._buildReportPanel(context, c),
        ],
      ),
    );
  }

  List<Widget> _buildMain(BuildContext context, LabColors c) {
    return [
      if (_showRootRow) ...[
        const SizedBox(height: kModalInset),
        CommentModalRootRow(
          context_: widget.rootContext!,
          version: widget.version,
          showConnector: true,
        ),
      ],

      // Comment CTA — quoted card (social) or plain button (catalog)
      if (_isCatalog || _hasSocialTarget) ...[
        if (!_showRootRow) const SizedBox(height: kModalInset),
        if (_hasSocialTarget)
          _QuotedCommentCard(
            comment: widget.comment,
            commentAuthor: widget.commentAuthor,
            zap: widget.zap,
            zapSenderName: widget.zapSenderName,
            onTap: _chooseComment,
            c: c,
          )
        else
          _PlainCommentButton(onTap: _chooseComment, c: c),
        const SizedBox(height: 10),
      ],

      if (_showStacksSection) ...[
        _EyebrowLabel(text: 'Add to stacks', c: c),
        const SizedBox(height: 8),
        _StacksSectionStub(c: c),
        const SizedBox(height: 10),
      ],

      _EyebrowLabel(text: 'Actions', c: c),
      const SizedBox(height: 8),
      _ActionsRow(
        onDetails: () => setState(() => _panel = _SubPanel.details),
        onShare: () => setState(() => _panel = _SubPanel.share),
        c: c,
      ),
      const SizedBox(height: 10),

      _ReportButton(
        isZap: widget.zap != null || widget.contentType == ActionsContentType.zap,
        isCatalog: _isCatalog,
        onTap: () => setState(() => _panel = _SubPanel.report),
        c: c,
      ),
    ];
  }

  List<Widget> _buildStubPanel(
    BuildContext context,
    LabColors c,
    String title,
  ) {
    return [
      _SubPanelHeader(
        title: title,
        onBack: () => setState(() => _panel = _SubPanel.main),
        c: c,
      ),
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
      _SubPanelHeader(
        title: 'Report',
        onBack: () => setState(() => _panel = _SubPanel.main),
        c: c,
      ),
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

class _PlainCommentButton extends StatelessWidget {
  const _PlainCommentButton({required this.onTap, required this.c});

  final VoidCallback onTap;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.black33,
          borderRadius: BorderRadius.circular(16),
          border: LabBorder.all(color: c.white33, width: 0.33),
        ),
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
    );
  }
}

class _QuotedCommentCard extends StatelessWidget {
  const _QuotedCommentCard({
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
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: quoteBlock,
            ),
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

class _StacksSectionStub extends StatelessWidget {
  const _StacksSectionStub({required this.c});
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.black33,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.white8,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: LabIcon(LabIcons.plus, size: 16, color: c.white66),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Stacks coming soon',
            style: LabTextStyles.reg15.copyWith(color: c.white33),
          ),
        ],
      ),
    );
  }
}

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

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.onDetails,
    required this.onShare,
    required this.c,
  });

  final VoidCallback onDetails;
  final VoidCallback onShare;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionTile(
          icon: LabIcons.details,
          label: 'Details',
          onTap: onDetails,
          c: c,
        ),
        const SizedBox(width: 12),
        _ActionTile(
          icon: LabIcons.share,
          label: 'Share',
          onTap: onShare,
          c: c,
        ),
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

class _ReportButton extends StatelessWidget {
  const _ReportButton({
    required this.isZap,
    required this.isCatalog,
    required this.onTap,
    required this.c,
  });

  final bool isZap;
  final bool isCatalog;
  final VoidCallback onTap;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    final label = isCatalog
        ? 'Report'
        : isZap
            ? 'Report this tip'
            : 'Report this comment';

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
          label,
          style: LabTextStyles.med15.copyWith(color: c.rougeColor),
        ),
      ),
    );
  }
}

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
