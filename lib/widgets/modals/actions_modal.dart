import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/nostr_comment_service.dart';
import 'package:zapstore/services/notification_service.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/bookmark_widgets.dart';
import 'package:zapstore/widgets/common/label.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/composer/nostr_text_controller.dart'
    show ComposerResult;
import 'package:zapstore/models/forum_post.dart';
import 'package:zapstore/widgets/modals/actions_sub_modals.dart';
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
  App? app,
  AppStack? stack,
  ForumPost? forumPost,
  Comment? comment,
  Profile? commentAuthor,
  Zap? zap,
  String? zapSenderName,
  String? authorName,
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
      app: app,
      stack: stack,
      forumPost: forumPost,
      comment: comment,
      commentAuthor: commentAuthor,
      zap: zap,
      zapSenderName: zapSenderName,
      authorName: authorName ?? commentAuthor?.name ?? zapSenderName,
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
      showRootConnector:
          rootContext != null && comment == null && zap == null,
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
    app: null,
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

class _ActionsModalContent extends ConsumerWidget {
  const _ActionsModalContent({
    required this.contentType,
    this.app,
    this.stack,
    this.forumPost,
    this.comment,
    this.commentAuthor,
    this.zap,
    this.zapSenderName,
    this.authorName,
    this.rootContext,
    this.version,
    this.onComment,
    this.onCommentSubmit,
  });

  final ActionsContentType contentType;
  final App? app;
  final AppStack? stack;
  final ForumPost? forumPost;
  final Comment? comment;
  final Profile? commentAuthor;
  final Zap? zap;
  final String? zapSenderName;
  final String? authorName;
  final ThreadRootContext? rootContext;
  final String? version;
  final VoidCallback? onComment;
  final Future<void> Function(ComposerResult result)? onCommentSubmit;

  bool get _isCatalog => switch (contentType) {
        ActionsContentType.app ||
        ActionsContentType.stack ||
        ActionsContentType.forum =>
          true,
        _ => false,
      };

  bool get _hasSocialTarget => comment != null || zap != null;

  bool get _showStacksSection => contentType == ActionsContentType.app;

  /// Catalog-only (app/stack/forum sheet). Never on comment/zap actions —
  /// the quoted target already shows what we're acting on.
  bool get _showRootRow =>
      _isCatalog && rootContext != null && !_hasSocialTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final target = ActionsTarget.fromModal(
      contentType: contentType,
      comment: comment,
      zap: zap,
      app: app,
      stack: stack,
      forumPost: forumPost,
      authorName: authorName ?? commentAuthor?.name ?? zapSenderName,
    );

    void chooseComment() {
      if (_isCatalog && onCommentSubmit != null) {
        Navigator.of(context).pop(_kHandoffComment);
        return;
      }
      if (onComment != null) {
        Navigator.of(context).pop();
        onComment!();
        return;
      }
      if (_hasSocialTarget) {
        Navigator.of(context).pop(_kHandoffComment);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showRootRow) ...[
            const SizedBox(height: kModalInset),
            CommentModalRootRow(
              context_: rootContext!,
              version: version,
              showConnector: true,
            ),
          ],

          if (_isCatalog || _hasSocialTarget) ...[
            if (!_showRootRow) const SizedBox(height: kModalInset),
            if (_hasSocialTarget)
              _QuotedCommentCard(
                comment: comment,
                commentAuthor: commentAuthor,
                zap: zap,
                zapSenderName: zapSenderName,
                onTap: chooseComment,
                c: c,
              )
            else
              _PlainCommentButton(onTap: chooseComment, c: c),
            const SizedBox(height: 10),
          ],

          _EyebrowLabel(text: 'Actions', c: c),
          const SizedBox(height: 8),
          _ActionsRow(
            showStack: _showStacksSection && app != null,
            onStack: app == null
                ? null
                : () => openActionsNestedModal(
                      context,
                      () => openActionsAddToStackModal(
                        context,
                        ref,
                        app: app!,
                      ),
                    ),
            shareEnabled: target.canShare,
            onDetails: () => openActionsNestedModal(
              context,
              () => openActionsDetailsModal(context, target: target),
            ),
            onShare: () => openActionsNestedModal(
              context,
              () => openActionsShareModal(context, target: target),
            ),
            onReport: () => openActionsNestedModal(
              context,
              () => openActionsReportModal(context, ref, target: target),
            ),
            c: c,
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

Future<void> openActionsAddToStackModal(
  BuildContext context,
  WidgetRef ref, {
  required App app,
}) {
  final c = Theme.of(context).extension<LabColors>()!;
  return showModal<void>(
    context,
    nestedModal: true,
    title: 'Add to stacks',
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: _ActionsStacksSection(app: app, c: c),
    ),
  );
}

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

class _ActionsStacksSection extends HookConsumerWidget {
  const _ActionsStacksSection({required this.app, required this.c});

  final App app;
  final LabColors c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedInPubkey = ref.watch(Signer.activePubkeyProvider);
    if (signedInPubkey == null) {
      return Container(
        height: 48,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.black33,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Sign in to add to stacks',
          style: LabTextStyles.reg15.copyWith(color: c.white33),
        ),
      );
    }

    final stacksState = ref.watch(
      query<AppStack>(
        authors: {signedInPubkey},
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: false),
        subscriptionPrefix: 'app-actions-stacks',
        schemaFilter: publicAppStackSchemaFilter,
      ),
    );

    final stacks = stacksState.models.toList();
    final saving = useState(false);
    final selectedIds = useState<Set<String>>({});

    useEffect(() {
      selectedIds.value = {
        for (final stack in stacks)
          if (stack.event.getTagSetValues('a').contains(app.id))
            stack.identifier,
      };
      return null;
    }, [stacks.map((s) => '${s.id}:${s.event.tags.length}').join('|'), app.id]);

    if (stacksState is StorageLoading && stacks.isEmpty) {
      return SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: c.white33,
            ),
          ),
        ),
      );
    }

    if (stacks.isEmpty) {
      return Container(
        height: 48,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.black33,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'No stacks yet',
          style: LabTextStyles.reg15.copyWith(color: c.white33),
        ),
      );
    }

    Future<void> toggle(String identifier) async {
      if (saving.value) return;
      final previous = Set<String>.from(selectedIds.value);
      final next = Set<String>.from(previous);
      if (next.contains(identifier)) {
        next.remove(identifier);
      } else {
        next.add(identifier);
      }
      selectedIds.value = next;
      saving.value = true;
      try {
        await saveAppPublicStackSelections(
          ref,
          app: app,
          existingStacks: stacks,
          selectedCollectionIds: next,
        );
      } catch (e) {
        selectedIds.value = previous;
        if (context.mounted) {
          context.showError('Could not update stacks', technicalDetails: '$e');
        }
      } finally {
        saving.value = false;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final stack in stacks) ...[
            LabLabel(
              stack.name ?? stack.identifier,
              size: LabLabelSize.defaultSize,
              isSelected: selectedIds.value.contains(stack.identifier),
              onTap: saving.value ? null : () => toggle(stack.identifier),
            ),
            const SizedBox(width: 8),
          ],
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
    this.showStack = false,
    this.onStack,
    required this.onDetails,
    required this.onShare,
    required this.onReport,
    required this.shareEnabled,
    required this.c,
  });

  final bool showStack;
  final VoidCallback? onStack;
  final VoidCallback onDetails;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final bool shareEnabled;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showStack) ...[
          _ActionTile(
            iconWidget: Image.asset(
              kStackEmojiAsset,
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) =>
                  LabIcon(LabIcons.index, size: 20, color: c.white66),
            ),
            label: 'Stack',
            onTap: onStack,
            c: c,
          ),
          const SizedBox(width: 12),
        ],
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
          onTap: shareEnabled ? onShare : null,
          c: c,
          dimmed: !shareEnabled,
        ),
        const SizedBox(width: 12),
        _ActionTile(
          icon: LabIcons.alert,
          label: 'Report',
          onTap: onReport,
          c: c,
          iconSize: 20,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.onTap,
    required this.c,
    this.dimmed = false,
    this.iconSize = 24,
  }) : assert(icon != null || iconWidget != null);

  final String? icon;
  final Widget? iconWidget;
  final String label;
  final VoidCallback? onTap;
  final LabColors c;
  final bool dimmed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final iconColor = dimmed ? c.white33 : c.white66;
    final labelColor = dimmed ? c.white33 : c.white;

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
                  child: iconWidget ??
                      LabIcon(icon!, size: iconSize, color: iconColor),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: LabTextStyles.med15.copyWith(color: labelColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
