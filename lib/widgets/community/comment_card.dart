import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/models/forum_post.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/nostr_query_id.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/app_pic.dart';
import 'package:zapstore/widgets/common/note_parser.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'package:zapstore/widgets/common/time_utils.dart';
import 'package:zapstore/providers/inbox_seen_provider.dart';
import 'package:zapstore/widgets/social/bubble_swiper.dart';
import 'package:zapstore/widgets/social/quoted_message.dart';
import 'package:zapstore/widgets/social/thread_root.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Layout tokens — port of webapp `CommentCard.svelte` (activity + inbox feeds).
// Slightly tightened avatar vs web `smMd` (35): 34×34 reads cleaner on handset.
// ─────────────────────────────────────────────────────────────────────────────

const double kCommentCardLeftColWidth = 36;

const double kCommentCardBadgeSize = 28;

const double kCommentCardAvatarSize = 34;

const double kCommentCardColGap = 8;

/// Space between successive feed rows — matches activity / inbox shell rhythm.
const double kCommentCardListGap = 16;

/// Hairline divider between successive feed rows (activity lists).
class CommentCardRowDivider extends StatelessWidget {
  const CommentCardRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    const halfGap = kCommentCardListGap / 2 + 4;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: halfGap),
        Container(height: LabStroke.thin, color: c.white11),
        const SizedBox(height: halfGap),
      ],
    );
  }
}

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
const LocalAndRemoteSource kCommentCardRootSource = LocalAndRemoteSource(
  relays: {kDefaultRelay, 'AppCatalog'},
  stream: true,
);

/// Normalized `E` / `A` tag for batched root lookups.
String? commentCardRootQueryId(EventBase<Model<dynamic>> event) =>
    normalizeNostrQueryId(
      event.getFirstTagValue('E') ?? event.getFirstTagValue('A'),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Tag helpers (same rules as `CommentCard.svelte` `isReply` + oneliner)
// ─────────────────────────────────────────────────────────────────────────────

String? _commentCardRootCoord(EventBase<Model<dynamic>> event) =>
    event.getFirstTagValue('E') ?? event.getFirstTagValue('A');

String? _commentCardParentCoord(EventBase<Model<dynamic>> event) =>
    event.getFirstTagValue('e') ?? event.getFirstTagValue('a');

/// True when the immediate parent is not the thread root → dotted connector + quote.
bool commentCardIsNestedReply(EventBase<Model<dynamic>> event) {
  final parent = _commentCardParentCoord(event);
  if (parent == null || parent.isEmpty) return false;
  final root = _commentCardRootCoord(event);
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
// Connectors — [Positioned] + [CustomPaint] on the left rail [Stack].
//
// Do **not** use [LayoutBuilder] or [Expanded] inside [IntrinsicHeight] here
// (unbounded constraints during the intrinsic pass → hard crash). Same fix as
// [ForumPostCard]'s reply connector.
// ─────────────────────────────────────────────────────────────────────────────

/// Dotted (top) + solid (bottom) when [nested]; solid only otherwise.
/// Matches web `.line-dotted` / `.line-solid` with `flex: 1` each.
class _CommentCardConnectorPainter extends CustomPainter {
  const _CommentCardConnectorPainter({
    required this.color,
    required this.nested,
  });

  final Color color;
  final bool nested;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    final x = size.width / 2;
    if (!nested) {
      _paintSolid(canvas, x, 0, size.height);
      return;
    }
    final mid = size.height / 2;
    _paintDotted(canvas, x, 0, mid);
    _paintSolid(canvas, x, mid, size.height - mid);
  }

  void _paintSolid(Canvas canvas, double x, double top, double height) {
    if (height <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(x, top), Offset(x, top + height), paint);
  }

  void _paintDotted(Canvas canvas, double x, double top, double height) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    var y = top;
    final end = top + height;
    while (y < end) {
      final segEnd = math.min(y + 6, end);
      canvas.drawLine(Offset(x, y), Offset(x, segEnd), paint);
      y += 10;
    }
  }

  @override
  bool shouldRepaint(_CommentCardConnectorPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.nested != nested;
}

// ─────────────────────────────────────────────────────────────────────────────
// Stack mini badge — port of `ActivityStackMiniBadge.svelte`
// ─────────────────────────────────────────────────────────────────────────────

class _CommentCardStackMiniBadge extends StatelessWidget {
  const _CommentCardStackMiniBadge();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Container(
      width: kCommentCardBadgeSize,
      height: kCommentCardBadgeSize,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.gray33,
        borderRadius: BorderRadius.circular(6),
        border: LabBorder.all(color: c.white16, width: LabStroke.thin),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tile(c),
                const SizedBox(width: 2),
                _tile(c),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tile(c),
                const SizedBox(width: 2),
                _tile(c),
              ],
            ),
          ],
        ),
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
// CommentCard — port of webapp `CommentCard.svelte`
// ─────────────────────────────────────────────────────────────────────────────

/// Kind-1111 feed row: root badge rail, dashed/solid connectors, message bubble.
class CommentCard extends ConsumerWidget {
  const CommentCard({
    super.key,
    required this.comment,
    this.inboxOwnerPubkey,
    this.onRootTap,
    this.onCardTap,
    this.onReply,
    this.onActions,
    this.batchedRootModel,
    this.batchedRootsLoading = false,
    this.useBatchedRoots = false,
  });

  final Comment comment;

  /// When set (activity feed batch), skips per-card root subscription.
  final Model? batchedRootModel;
  final bool batchedRootsLoading;
  final bool useBatchedRoots;

  /// When set (inbox feed), shows a blurple unread dot until [event id] is seen.
  final String? inboxOwnerPubkey;

  /// Tap on the root label row (navigate to app/stack/forum).
  final VoidCallback? onRootTap;

  /// Tap anywhere on the card — e.g. open the thread modal from inbox.
  final VoidCallback? onCardTap;

  /// Swipe-right on the bubble (reply). Defaults to thread modal with composer.
  final VoidCallback? onReply;

  /// Swipe-left on the bubble (options). Defaults to the comment actions sheet.
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final ev = comment.event;

    final rootQueryId = commentCardRootQueryId(ev);
    final parentCoordRaw = _commentCardParentCoord(ev);
    final parentQueryId = normalizeNostrQueryId(parentCoordRaw);
    final nested = commentCardIsNestedReply(ev);

    final rootState = !useBatchedRoots && rootQueryId != null
        ? ref.watch(
            queryKinds(
              ids: {rootQueryId},
              limit: 1,
              source: kCommentCardRootSource,
              subscriptionPrefix: 'cc-r-${comment.id.hashCode}',
              where: null,
              and: null,
            ),
          )
        : null;

    Model? rootModel = useBatchedRoots ? batchedRootModel : null;
    if (!useBatchedRoots) {
      final rootRaw = rootState?.models.firstOrNull;
      if (rootRaw is Model) rootModel = rootRaw;
    }

    final rootLoading = useBatchedRoots
        ? batchedRootsLoading && rootModel == null && rootQueryId != null
        : rootState != null && rootState is StorageLoading && rootModel == null;

    final authorPubkey = normalizeAuthorPubkey(comment.event.pubkey);
    final parentPkRaw = nested ? ev.getFirstTagValue('p') : null;
    final parentPubkey = normalizeAuthorPubkey(parentPkRaw);
    final parentKind = nested ? comment.parentKind : null;

    final fetchParentQuote =
        nested && parentKind == 1111 && parentQueryId != null;

    final parentCommentState = fetchParentQuote
        ? ref.watch(
            query<Comment>(
              ids: {parentQueryId},
              limit: 1,
              source: kCommentCardRootSource,
              subscriptionPrefix: 'cc-p-${comment.id.hashCode}',
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

    final Profile? author = authorPubkey != null
        ? ref.watch(
              query<Profile>(
                authors: {authorPubkey},
                source: const LocalAndRemoteSource(
                  relays: {'social', 'vertex'},
                  stream: false,
                  cachedFor: Duration(hours: 2),
                ),
                subscriptionPrefix: 'cc-a-${authorPubkey.hashCode}',
              ),
            ).models
            .firstOrNull
        : null;

    final Profile? parentAuthor = parentPubkey != null
        ? ref.watch(
              query<Profile>(
                authors: {parentPubkey},
                source: const LocalAndRemoteSource(
                  relays: {'social', 'vertex'},
                  stream: false,
                  cachedFor: Duration(hours: 2),
                ),
                subscriptionPrefix: 'cc-pa-${parentPubkey.hashCode}',
              ),
            ).models
            .firstOrNull
        : null;

    late final _RootOneliner oneliner;
    final bool rootMissingAfterLoad = rootQueryId != null &&
        rootModel == null &&
        (useBatchedRoots
            ? !batchedRootsLoading
            : rootState != null && rootState is! StorageLoading);

    if (rootModel != null) {
      oneliner = _rootOnelinerFromModel(rootModel);
    } else {
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
    }

    final showQuote = nested && (parentCommentLoading || parentComment != null);

    final inboxPk = inboxOwnerPubkey;
    final showUnreadDot = inboxPk != null &&
        !ref.watch(inboxSeenProvider(inboxPk)).contains(comment.event.id);

    final nameColor = profileTextColor(hexToColor(comment.event.pubkey));
    final contentWidget = NoteParser.parseSafe(
      context,
      comment.content,
      emojiTags: NoteParser.extractEmojiTags(comment.event.tags),
    );

    final bubbleRadius = showQuote ? _kBubbleQuotedRadius : _kBubbleRadius;

    final bubble = ConstrainedBox(
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
                    style:
                        LabTextStyles.semibold13.copyWith(color: nameColor),
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
    );

    final rootHref = rootModel != null
        ? ThreadRootContext.hrefForModel(rootModel)
        : ThreadRootContext.hrefForRootCoord(
            rootQueryId,
            kind: comment.rootKind,
          );
    final effectiveOnRootTap = onRootTap ??
        (rootHref != null && !rootLoading
            ? () => context.push(rootHref)
            : null);

    // Badge + label sit in a fixed-height top row (root tap navigates — not card tap).
    // [IntrinsicHeight] wraps only the avatar rail + bubble so the intrinsic pass
    // measures bubble height — not the 28px badge band (that mismatch caused
    // ~192px [RenderFlex] overflows).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: effectiveOnRootTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: kCommentCardLeftColWidth,
                height: kCommentCardBadgeSize,
                child: Center(
                  child: _RootBadge(
                    rootModel: rootModel,
                    rootLoading: rootLoading,
                    oneliner: oneliner,
                    rootMissing: rootMissingAfterLoad || rootQueryId == null,
                  ),
                ),
              ),
              const SizedBox(width: kCommentCardColGap),
              Expanded(
                child: SizedBox(
                  height: kCommentCardBadgeSize,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _RootLabelRow(
                      oneliner: oneliner,
                      onTap: effectiveOnRootTap,
                      muted: rootLoading ||
                          (rootMissingAfterLoad && rootHref == null),
                      showUnreadDot: showUnreadDot,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onCardTap,
          behavior: HitTestBehavior.opaque,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: kCommentCardLeftColWidth,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 0,
                        bottom: kCommentCardAvatarSize,
                        left: (kCommentCardLeftColWidth - 2) / 2,
                        width: 2,
                        child: CustomPaint(
                          painter: _CommentCardConnectorPainter(
                            color: c.white16,
                            nested: nested,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: ProfilePic(
                          profile: author,
                          pubkey: comment.event.pubkey,
                          size: kCommentCardAvatarSize,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: kCommentCardColGap),
                Expanded(
                  child: BubbleSwiper(
                    c: c,
                    replyIconInset: 8,
                    onReply: onReply,
                    onActions: onActions,
                    child: bubble,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RootLabelRow extends StatelessWidget {
  const _RootLabelRow({
    required this.oneliner,
    this.onTap,
    this.muted = false,
    this.showUnreadDot = false,
  });

  final _RootOneliner oneliner;
  final VoidCallback? onTap;
  final bool muted;
  final bool showUnreadDot;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final color = muted ? c.white33 : c.white66;

    final isStack = oneliner.kind == _RootKind.stack;
    final label = isStack
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

    final labelMain = onTap != null && !muted
        ? GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: label,
          )
        : label;

    return Row(
      children: [
        Expanded(child: labelMain),
        if (showUnreadDot) ...[
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: c.blurpleColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
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
        width: kCommentCardBadgeSize,
        height: kCommentCardBadgeSize,
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
        width: kCommentCardBadgeSize,
        height: kCommentCardBadgeSize,
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
        size: kCommentCardBadgeSize,
        onTap: null,
      );
    }

    if (rootModel is AppStack) {
      return const _CommentCardStackMiniBadge();
    }

    if (rootModel is Comment) {
      return Container(
        width: kCommentCardBadgeSize,
        height: kCommentCardBadgeSize,
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
        size: kCommentCardBadgeSize,
        backgroundColor: c.white8,
      );
    }

    return ForumEmojiBadge(
      size: kCommentCardBadgeSize,
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

class CommentCardSkeleton extends StatelessWidget {
  const CommentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: kCommentCardLeftColWidth,
          child: Column(
            children: [
              const Shimmer(
                width: kCommentCardBadgeSize,
                height: kCommentCardBadgeSize,
                radius: 6,
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 48,
                child: Center(
                  child: Container(width: 2, color: c.white8),
                ),
              ),
              const SizedBox(height: 6),
              const Shimmer(
                width: kCommentCardAvatarSize,
                height: kCommentCardAvatarSize,
                isCircle: true,
              ),
            ],
          ),
        ),
        const SizedBox(width: kCommentCardColGap),
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

class CommentCardSkeletonList extends StatelessWidget {
  const CommentCardSkeletonList({super.key, this.rowCount = 5});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rowCount; i++) ...[
          if (i > 0) const SizedBox(height: kCommentCardListGap),
          const CommentCardSkeleton(),
        ],
      ],
    );
  }
}
