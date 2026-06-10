import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/models/forum_post.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/app_pic.dart';
import 'package:zapstore/widgets/common/note_parser.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'package:zapstore/widgets/common/time_utils.dart';
import 'package:zapstore/widgets/modals/actions_modal.dart';
import 'package:zapstore/widgets/social/bubble_swiper.dart';
import 'package:zapstore/widgets/social/quoted_message.dart';
import 'package:zapstore/widgets/social/root_comment.dart';
import 'package:zapstore/widgets/social/thread_root.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Layout tokens — port of webapp `CommentCard.svelte` (activity + inbox feeds).
// Slightly tightened avatar vs web `smMd` (35): 34×34 reads cleaner on handset.
// ─────────────────────────────────────────────────────────────────────────────

const double kActivityCommentLeftColWidth = 36;

const double kActivityCommentBadgeSize = 28;

const double kActivityCommentAvatarSize = 34;

const double kActivityCommentColGap = 8;

/// Space between successive activity rows — matches roomy activity shell rhythm.
const double kActivityCommentListGap = 16;

const EdgeInsets _kBubblePadding = EdgeInsets.fromLTRB(11, 6, 11, 6);

const BorderRadius _kBubbleRadius = BorderRadius.only(
  topLeft: Radius.circular(LabRadius.r14),
  topRight: Radius.circular(LabRadius.r14),
  bottomRight: Radius.circular(LabRadius.r14),
  bottomLeft: Radius.circular(LabRadius.r4),
);

const BorderRadius _kBubbleQuotedRadius = BorderRadius.only(
  topLeft: Radius.circular(LabRadius.r14),
  topRight: Radius.circular(LabRadius.r14),
  bottomRight: Radius.circular(LabRadius.r14),
  bottomLeft: Radius.circular(LabRadius.r4),
);

/// Roots for NIP‑22 threads: Zapstore relay (inbox parity) plus catalog fallback.
const LocalAndRemoteSource _kActivityRootSource = LocalAndRemoteSource(
  relays: {kDefaultRelay, 'AppCatalog'},
  stream: true,
);

// ─────────────────────────────────────────────────────────────────────────────
// Tag helpers (same rules as `CommentCard.svelte` `isReply` + oneliner)
// ─────────────────────────────────────────────────────────────────────────────

String? _activityRootCoord(EventBase<Model<dynamic>> event) =>
    event.getFirstTagValue('E') ?? event.getFirstTagValue('A');

String? _activityParentCoord(EventBase<Model<dynamic>> event) =>
    event.getFirstTagValue('e') ?? event.getFirstTagValue('a');

/// True when the immediate parent is not the thread root → dotted connector + quote.
bool activityCommentIsNestedReply(EventBase<Model<dynamic>> event) {
  final parent = _activityParentCoord(event);
  if (parent == null || parent.isEmpty) return false;
  final root = _activityRootCoord(event);
  if (root != null && parent == root) return false;
  return true;
}

String _truncateOneliner(String raw, [int max = 80]) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  if (t.length <= max) return t;
  return '${t.substring(0, max)}…';
}

String _formatDisplayNpub(String pubkey) {
  final enc = Utils.encodeShareableFromString(pubkey, type: 'npub');
  if (enc.length < 14) return enc;
  return '${enc.substring(0, 8)}…${enc.substring(enc.length - 6)}';
}

String _authorLabel(Profile? profile, String pubkey) {
  final n = profile?.name?.trim() ?? '';
  if (n.isNotEmpty) return n;
  return _formatDisplayNpub(pubkey);
}

_RootOneliner _rootOnelinerFromModel(Model model) {
  if (model is ForumPost) {
    final title = model.title?.trim();
    final firstLine = model.content.split('\n').first.trim();
    final label = _truncateOneliner(
      title?.isNotEmpty == true
          ? title!
          : (firstLine.isNotEmpty ? firstLine : 'Publication'),
    );
    return _RootOneliner(label: label.isEmpty ? 'Publication' : label, kind: _RootKind.forum);
  }
  if (model is App) {
    final name = model.name?.trim();
    final d = model.identifier;
    final label = _truncateOneliner(name?.isNotEmpty == true ? name! : d);
    return _RootOneliner(label: label.isEmpty ? 'App' : label, kind: _RootKind.app);
  }
  if (model is AppStack) {
    final title = model.name?.trim();
    final d = model.identifier;
    final label = _truncateOneliner(title?.isNotEmpty == true ? title! : d);
    return _RootOneliner(label: label.isEmpty ? 'Stack' : label, kind: _RootKind.stack);
  }
  if (model is Comment) {
    final line = model.content.split('\n').first.trim();
    final label = _truncateOneliner(line.isNotEmpty ? line : model.content);
    return _RootOneliner(label: label.isEmpty ? 'Comment' : label, kind: _RootKind.comment);
  }
  return const _RootOneliner(label: 'Post', kind: _RootKind.forum);
}

enum _RootKind { forum, app, stack, comment }

class _RootOneliner {
  const _RootOneliner({required this.label, required this.kind});

  final String label;
  final _RootKind kind;
}

// ─────────────────────────────────────────────────────────────────────────────
// Connectors
// ─────────────────────────────────────────────────────────────────────────────

/// Repeating dash: 6px paint + 4px gap — matches `.line-dotted` in CommentCard.
class _DottedVerticalLine extends StatelessWidget {
  const _DottedVerticalLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _DottedVerticalPainter(color),
        );
      },
    );
  }
}

class _DottedVerticalPainter extends CustomPainter {
  _DottedVerticalPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    var y = 0.0;
    while (y < size.height) {
      final end = math.min(y + 6, size.height);
      canvas.drawLine(Offset(x, y), Offset(x, end), paint);
      y += 10;
    }
  }

  @override
  bool shouldRepaint(_DottedVerticalPainter oldDelegate) => oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Stack mini badge — port of `ActivityStackMiniBadge.svelte`
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityStackMiniBadge extends StatelessWidget {
  const _ActivityStackMiniBadge();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Container(
      width: kActivityCommentBadgeSize,
      height: kActivityCommentBadgeSize,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.gray33,
        borderRadius: BorderRadius.circular(6),
        border: LabBorder.all(color: c.white16, width: LabStroke.thin),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              _tile(c),
              const SizedBox(width: 2),
              _tile(c),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _tile(c),
              const SizedBox(width: 2),
              _tile(c),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(LabColors c) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: c.blurpleColor66,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity comment card — port of webapp `CommentCard.svelte`
// ─────────────────────────────────────────────────────────────────────────────

/// Activity-thread row with root badge rail, dashed/solid connectors, and chat bubble.
class ActivityCommentCard extends ConsumerWidget {
  const ActivityCommentCard({
    super.key,
    required this.comment,
    this.onRootTap,
    this.onCardTap,
    this.onReply,
    this.onActions,
  });

  final Comment comment;

  final VoidCallback? onRootTap;

  final VoidCallback? onCardTap;

  final VoidCallback? onReply;

  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final ev = comment.event;

    final rootCoord = _activityRootCoord(ev);
    final parentCoord = _activityParentCoord(ev);
    final nested = activityCommentIsNestedReply(ev);

    final rootState = rootCoord != null
        ? ref.watch(
            queryKinds(
              ids: {rootCoord},
              limit: 1,
              source: _kActivityRootSource,
              subscriptionPrefix: 'act-r-${comment.id.hashCode}',
              where: null,
              and: null,
            ),
          )
        : null;

    Model? rootModel;
    final rootRaw = rootState?.models.firstOrNull;
    if (rootRaw is Model) rootModel = rootRaw;

    final rootLoading =
        rootState != null && rootState is StorageLoading && rootModel == null;

    final parentPk = nested ? ev.getFirstTagValue('p') : null;
    final parentKind = nested ? comment.parentKind : null;

    final fetchParentQuote = nested && parentKind == 1111 && parentCoord != null;

    final parentCommentState = fetchParentQuote
        ? ref.watch(
            query<Comment>(
              ids: {parentCoord},
              limit: 1,
              source: _kActivityRootSource,
              subscriptionPrefix: 'act-p-${comment.id.hashCode}',
            ),
          )
        : null;

    Comment? parentComment;
    final pcRaw = parentCommentState?.models.firstOrNull;
    if (pcRaw is Comment) parentComment = pcRaw;

    final parentCommentLoading = fetchParentQuote &&
        parentCommentState != null &&
        parentCommentState is StorageLoading &&
        parentComment == null;

    final Profile? author = ref.watch(
          query<Profile>(
            authors: {comment.event.pubkey},
            source: const LocalAndRemoteSource(
              relays: {'social', 'vertex'},
              stream: false,
              cachedFor: Duration(hours: 2),
            ),
            subscriptionPrefix: 'act-a-${comment.event.pubkey.hashCode}',
          ),
        ).models
        .firstOrNull;

    final Profile? parentAuthor = parentPk != null
        ? ref.watch(
              query<Profile>(
                authors: {parentPk},
                source: const LocalAndRemoteSource(
                  relays: {'social', 'vertex'},
                  stream: false,
                  cachedFor: Duration(hours: 2),
                ),
                subscriptionPrefix: 'act-pa-${parentPk.hashCode}',
              ),
            ).models
            .firstOrNull
        : null;

    late final _RootOneliner oneliner;
    final bool rootMissingAfterLoad = rootCoord != null &&
        rootState != null &&
        rootState is! StorageLoading &&
        rootModel == null;

    if (rootMissingAfterLoad || rootCoord == null) {
      final pending = rootLoading;
      final k = comment.rootKind;
      if (pending) {
        oneliner = _RootOneliner(
          label: k == 32267
              ? 'Loading App…'
              : k == 30267
                  ? 'Loading Stack…'
                  : k == 11
                      ? 'Loading Publication…'
                      : 'Loading…',
          kind: k == 30267
              ? _RootKind.stack
              : k == 32267
                  ? _RootKind.app
                  : _RootKind.forum,
        );
      } else {
        oneliner = _RootOneliner(
          label: k == 30267
              ? 'Stack not found'
              : k == 32267
                  ? 'App not found'
                  : k == 11
                      ? 'Publication not found'
                      : 'Thread not found',
          kind: _RootKind.forum,
        );
      }
    } else {
      oneliner = _rootOnelinerFromModel(rootModel!);
    }

    final showQuote = nested && (parentCommentLoading || parentComment != null);

    final nameColor = profileTextColor(hexToColor(comment.event.pubkey));
    final contentWidget = NoteParser.parse(
      context,
      comment.content,
      emojiTags: NoteParser.extractEmojiTags(comment.event.tags),
    );

    final bubbleRadius = showQuote ? _kBubbleQuotedRadius : _kBubbleRadius;

    final rootContext = resolveThreadRootContext(
      comment: comment,
      rootModel: rootModel,
      rootLoading: rootLoading,
      rootMissing: rootMissingAfterLoad || rootCoord == null,
    );

    return GestureDetector(
      onTap: onCardTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: kActivityCommentLeftColWidth,
          child: Column(
            children: [
              SizedBox(
                height: kActivityCommentBadgeSize,
                child: Center(
                  child: _RootBadge(
                    rootModel: rootModel,
                    rootLoading: rootLoading,
                    oneliner: oneliner,
                    rootMissing: rootMissingAfterLoad || rootCoord == null,
                  ),
                ),
              ),
              if (nested)
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 2,
                      child: _DottedVerticalLine(color: c.white16),
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 2,
                    child: ColoredBox(color: c.white16),
                  ),
                ),
              ),
              SizedBox(
                height: kActivityCommentAvatarSize,
                child: Center(
                  child: ProfilePic(
                    profile: author,
                    pubkey: comment.event.pubkey,
                    size: kActivityCommentAvatarSize,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: kActivityCommentColGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: kActivityCommentBadgeSize,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _RootLabelRow(
                    oneliner: oneliner,
                    onTap: onRootTap,
                    muted: rootLoading || (rootMissingAfterLoad && !rootLoading),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              BubbleSwiper(
                c: c,
                replyIconInset: 8,
                onReply: onReply ??
                    () => showThreadModal(
                          context,
                          ref,
                          comment: comment,
                          rootContext: rootContext,
                          initialExpand: true,
                        ),
                onActions: onActions ??
                    () => showCommentActionsModal(
                          context,
                          comment: comment,
                          commentAuthor: author,
                          rootContext: rootContext,
                          ref: ref,
                        ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 200),
                  child: Container(
                    padding: _kBubblePadding,
                    decoration: BoxDecoration(
                      color: c.gray66,
                      borderRadius: bubbleRadius,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _authorLabel(author, comment.event.pubkey),
                                style: LabTextStyles.semibold13.copyWith(color: nameColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TimeAgoText(
                                  comment.createdAt,
                                  style: LabTextStyles.med11.copyWith(color: c.white33),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (showQuote) ...[
                          if (parentCommentLoading)
                            const _QuoteSkeleton()
                          else if (parentComment != null)
                            QuotedMessage.fromComment(
                              parentComment,
                              author: parentAuthor,
                            ),
                        ],
                        DefaultTextStyle(
                          style: LabTextStyles.reg15.copyWith(
                            color: c.white.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                          child: contentWidget,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

class _RootLabelRow extends StatelessWidget {
  const _RootLabelRow({
    required this.oneliner,
    this.onTap,
    this.muted = false,
  });

  final _RootOneliner oneliner;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final color = muted ? c.white33 : c.white66;

    final isStack = oneliner.kind == _RootKind.stack;
    final textWidget = isStack
        ? RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: LabTextStyles.med15.copyWith(color: c.white33),
              children: [
                const TextSpan(text: 'Stack '),
                TextSpan(
                  text: oneliner.label,
                  style: LabTextStyles.med15.copyWith(color: color),
                ),
              ],
            ),
          )
        : Text(
            oneliner.label,
            style: LabTextStyles.med15.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

    if (onTap != null && !muted) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: textWidget,
      );
    }
    return textWidget;
  }
}

class _RootBadge extends StatelessWidget {
  const _RootBadge({
    required this.rootModel,
    required this.rootLoading,
    required this.oneliner,
    required this.rootMissing,
  });

  final Model? rootModel;
  final bool rootLoading;
  final _RootOneliner oneliner;
  final bool rootMissing;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    if (rootMissing && !rootLoading) {
      return Container(
        width: kActivityCommentBadgeSize,
        height: kActivityCommentBadgeSize,
        decoration: BoxDecoration(
          color: c.white8,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: LabIcon(LabIcons.alert, size: 14, color: c.white33),
        ),
      );
    }

    if (rootLoading) {
      return Shimmer(
        width: kActivityCommentBadgeSize,
        height: kActivityCommentBadgeSize,
        radius: 6,
      );
    }

    if (rootModel is App) {
      final app = rootModel as App;
      final iconUrl = app.icons.firstOrNull;
      return AppPic(
        iconUrl: iconUrl,
        name: app.name,
        identifier: app.identifier,
        size: kActivityCommentBadgeSize,
        onTap: null,
      );
    }

    if (rootModel is AppStack) {
      return const _ActivityStackMiniBadge();
    }

    if (rootModel is Comment) {
      return Container(
        width: kActivityCommentBadgeSize,
        height: kActivityCommentBadgeSize,
        decoration: BoxDecoration(
          color: c.white8,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: LabIcon(LabIcons.reply, size: 14, color: c.white66),
        ),
      );
    }

    if (rootModel is ForumPost || oneliner.kind == _RootKind.forum) {
      return ForumEmojiBadge(
        size: kActivityCommentBadgeSize,
        backgroundColor: c.white8,
      );
    }

    return ForumEmojiBadge(
      size: kActivityCommentBadgeSize,
      backgroundColor: c.white8,
    );
  }
}

class _QuoteSkeleton extends StatelessWidget {
  const _QuoteSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: const SizedBox(
          height: 44,
          child: Shimmer(width: double.infinity, height: 44, radius: LabRadius.r8),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton list (loading gate)
// ─────────────────────────────────────────────────────────────────────────────

class ActivityCommentCardSkeleton extends StatelessWidget {
  const ActivityCommentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: kActivityCommentLeftColWidth,
          child: Column(
            children: [
              const Shimmer(
                width: kActivityCommentBadgeSize,
                height: kActivityCommentBadgeSize,
                radius: 6,
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 48,
                child: Center(
                  child: Container(
                    width: 2,
                    color: c.white8,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Shimmer(
                width: kActivityCommentAvatarSize,
                height: kActivityCommentAvatarSize,
                isCircle: true,
              ),
            ],
          ),
        ),
        const SizedBox(width: kActivityCommentColGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Shimmer(width: 180, height: 14, radius: LabRadius.r8),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(LabRadius.r14),
                  topRight: Radius.circular(LabRadius.r14),
                  bottomRight: Radius.circular(LabRadius.r14),
                  bottomLeft: Radius.circular(LabRadius.r4),
                ),
                child: Shimmer(
                  width: double.infinity,
                  height: 72,
                  radius: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ActivityCommentCardSkeletonList extends StatelessWidget {
  const ActivityCommentCardSkeletonList({super.key, this.rowCount = 5});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rowCount; i++) ...[
          if (i > 0) const SizedBox(height: kActivityCommentListGap),
          const ActivityCommentCardSkeleton(),
        ],
      ],
    );
  }
}
