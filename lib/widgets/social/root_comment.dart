import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/nostr_comment_service.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/l_connector.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/common/note_parser.dart';
import 'package:zapstore/widgets/common/profile_pic_stack.dart';
import 'package:zapstore/widgets/modals/comment_actions_modal.dart';
import 'package:zapstore/widgets/modals/comment_modal.dart';
import 'package:zapstore/widgets/composer/nostr_text_controller.dart' show ComposerResult;
import 'package:zapstore/widgets/social/message_bubble.dart';
import 'package:zapstore/widgets/social/quoted_message.dart';
import 'package:zapstore/widgets/social/thread_comment.dart';

/// Feed-level comment item matching webapp's RootComment.svelte.
///
/// Layout:
///   1. [MessageBubble] — avatar + gray66 bubble (author header + content).
///   2. [_ReplyIndicator] — connector line + [ProfilePicStack] (when replies exist).
///
/// Tapping opens [_ThreadModal] — a bottom sheet with blurred backdrop —
/// showing the root comment (flat [ThreadComment]) + all replies as bubbles.
class RootComment extends ConsumerWidget {
  const RootComment({
    super.key,
    required this.comment,
    this.onReply,
    this.onActions,
  });

  final Comment comment;

  /// Called when the user swipes right on the bubble (reply gesture).
  /// If null the swipe animation still plays but nothing opens.
  final VoidCallback? onReply;

  /// Called when the user swipes left on the bubble (actions gesture).
  /// If null the swipe animation still plays but nothing opens.
  final VoidCallback? onActions;

  void _openThread(BuildContext context, WidgetRef ref) {
    showModal<void>(
      context,
      fillHeight: true,
      maxHeightFactor: 0.75,
      footer: (ctx) => _ThreadFooter(
        comment: comment,
        onReply: (result) =>
            publishReplyComment(ref: ref, result: result, parentComment: comment),
      ),
      builder: (_) => _ThreadBody(
        comment: comment,
        onReply: (parent, result) =>
            publishReplyComment(ref: ref, result: result, parentComment: parent),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorState = ref.watch(
      query<Profile>(
        authors: {comment.event.pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          stream: false,
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'cb-profile-${comment.event.pubkey}',
      ),
    );
    final author = authorState.models.firstOrNull;
    final replies = comment.replies.toList();

    // Unique replier pubkeys (up to 3 for avatar stack)
    final uniqueReplierPubkeys = <String>{};
    final replierItems = <ProfilePicItem>[];
    for (final r in replies) {
      if (uniqueReplierPubkeys.add(r.event.pubkey)) {
        replierItems.add(ProfilePicItem(pubkey: r.event.pubkey));
        if (replierItems.length >= 3) break;
      }
    }

    // Fetch profiles for repliers to build display names
    final replierProfilesState = uniqueReplierPubkeys.isNotEmpty
        ? ref.watch(
            query<Profile>(
              authors: uniqueReplierPubkeys,
              source: const LocalAndRemoteSource(
                relays: {'social', 'vertex'},
                stream: false,
                cachedFor: Duration(hours: 2),
              ),
              subscriptionPrefix: 'cb-replier-${comment.id}',
            ),
          )
        : null;

    final replierProfiles = {
      for (final p in replierProfilesState?.models ?? <Profile>[])
        p.pubkey: p,
    };

    final replyIndicatorText = _buildReplyIndicatorText(replierItems, replierProfiles);

    // Merge loaded profiles back into the items so ProfilePicStack renders
    // actual avatars instead of initials fallback.
    final replierItemsWithProfiles = replierItems
        .map((item) => ProfilePicItem(
              pubkey: item.pubkey,
              profile: item.pubkey != null ? replierProfiles[item.pubkey] : null,
            ))
        .toList();

    final contentWidget = NoteParser.parse(
      context,
      comment.content,
      emojiTags: NoteParser.extractEmojiTags(comment.event.tags),
    );

    return GestureDetector(
      onTap: () => _openThread(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessageBubble(
            profile: author,
            pubkey: comment.event.pubkey,
            content: contentWidget,
            timestamp: comment.createdAt,
            onReply: onReply ??
                () => showCommentModal(
                      context,
                      placeholder: 'Reply…',
                      quotedComment: comment,
                      quotedCommentAuthor: author,
                      onSubmit: (result) => publishReplyComment(
                        ref: ref,
                        result: result,
                        parentComment: comment,
                      ),
                    ),
            onActions: onActions ??
                () => showCommentActionsModal(
                      context,
                      comment: comment,
                      commentAuthor: author,
                    ),
          ),

          // Reply indicator — pulled 2px up to sit closer to the bubble above.
          if (replies.isNotEmpty)
            Transform.translate(
              offset: const Offset(0, -2),
              child: _ReplyIndicator(
                replierItems: replierItemsWithProfiles,
                replyCount: replies.length,
                replyIndicatorText: replyIndicatorText,
                onTap: () => _openThread(context, ref),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the reply indicator label: "Name", "Name & Name", "Name & N Others".
  static String _buildReplyIndicatorText(
    List<ProfilePicItem> items,
    Map<String, Profile> profilesMap,
  ) {
    if (items.isEmpty) return '';
    final n = items.length;
    final nameA = _shortName(profilesMap[items[0].pubkey]);
    if (n == 1) return nameA;
    if (n == 2) {
      return '$nameA & ${_shortName(profilesMap[items[1].pubkey])}';
    }
    return '$nameA & ${n - 1} Others';
  }

  static String _shortName(Profile? p) {
    final name = p?.name?.trim() ?? '';
    if (name.isEmpty) return 'Someone';
    if (name.length <= 18) return name;
    return '${name.substring(0, 18)}...';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thread modal — body + footer (used by showAppModal via fillHeight + footer)
// ─────────────────────────────────────────────────────────────────────────────

/// Scrollable body: flat [ThreadComment] root + divider + reply bubbles.
class _ThreadBody extends ConsumerWidget {
  const _ThreadBody({required this.comment, this.onReply});

  final Comment comment;

  /// Called when the user submits a reply from inside the thread body.
  /// Receives (parentComment, composerResult) — the immediate parent to reply to.
  final Future<void> Function(Comment parent, ComposerResult result)? onReply;

  /// BFS walk of [root.replies] → [reply.replies] → … collecting ALL
  /// descendants at every depth, sorted chronologically.
  ///
  /// Mirrors webapp's collectCommentSubtree() in thread-discussion.js.
  static List<Comment> _collectSubtree(Comment root) {
    final result = <Comment>[];
    final seen = <String>{};
    final queue = <Comment>[...root.replies.toList()];
    while (queue.isNotEmpty) {
      final c = queue.removeAt(0);
      if (seen.add(c.id)) {
        result.add(c);
        queue.addAll(c.replies.toList());
      }
    }
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    // Recursively collect all descendants (level 2, 3, 4 …) chronologically.
    final replies = _collectSubtree(comment);

    // Build an id→Comment lookup for resolving quoted parents in nested replies.
    final byId = <String, Comment>{
      comment.id: comment,
      for (final r in replies) r.id: r,
    };

    final authorState = ref.watch(
      query<Profile>(
        authors: {comment.event.pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          stream: false,
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'tm-profile-${comment.event.pubkey}',
      ),
    );
    final author = authorState.models.firstOrNull;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Root comment — flat ThreadComment header (not a bubble)
        ThreadComment(
          profile: author,
          pubkey: comment.event.pubkey,
          content: NoteParser.parse(
            context,
            comment.content,
            emojiTags: NoteParser.extractEmojiTags(comment.event.tags),
          ),
          timestamp: comment.createdAt,
        ),

        // Divider — 1.4px white11, matching .thread-divider in webapp
        Container(height: 1.4, color: c.white11),

        // 4px top padding before the first reply
        const SizedBox(height: 4),

        // Replies — 4px additional gap between each bubble
        if (replies.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Center(
              child: Text(
                'No comments yet',
                style: LabTextStyles.reg15.copyWith(color: c.white33),
              ),
            ),
          )
        else
          for (int i = 0; i < replies.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            _ThreadReply(
              reply: replies[i],
              rootId: comment.id,
              byId: byId,
              onReply: () {
                final scope = ModalNestScope.maybeOf(context);
                scope?.onNestedChange(true);
                showCommentModal(
                  context,
                  placeholder: 'Reply…',
                  quotedComment: replies[i],
                  onSubmit: onReply != null
                      ? (result) => onReply!(replies[i], result)
                      : null,
                ).then((_) => scope?.onNestedChange(false));
              },
              onActions: () => showCommentActionsModal(
                context,
                comment: replies[i],
              ),
            ),
          ],

        const SizedBox(height: 8),
      ],
    );
  }
}

/// Pinned footer bar for the thread modal — three-button row matching the
/// [BottomBar] used on forum post / app / stack detail screens:
///   [Zap ⚡] [Comment input placeholder ────────────] [⋯]
class _ThreadFooter extends StatelessWidget {
  const _ThreadFooter({required this.comment, this.onReply});

  final Comment comment;

  /// Called with the composer result when the user submits a reply.
  final Future<void> Function(ComposerResult result)? onReply;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return ModalFooterBar(
      child: Row(
        children: [
          // Zap button — blurple, 41px (stub; no zap flow yet)
          Container(
            width: 41,
            height: 41,
            decoration: BoxDecoration(
              gradient: c.blurple,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Center(
              child: LabIcon(LabIcons.zap, size: 20, color: c.whiteEnforced),
            ),
          ),
          const SizedBox(width: 12),

          // Comment input placeholder — tapping opens the composer with
          // the root comment as quoted context.
          Expanded(
            child: GestureDetector(
              onTap: () {
                final scope = ModalNestScope.maybeOf(context);
                scope?.onNestedChange(true);
                showCommentModal(
                  context,
                  placeholder: 'Reply…',
                  quotedComment: comment,
                  onSubmit: onReply,
                ).then((_) => scope?.onNestedChange(false));
              },
              child: Container(
                height: 41,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: c.black33,
                  borderRadius: BorderRadius.circular(17),
                  border: LabBorder.all(color: c.white33, width: 0.33),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    LabIcon(LabIcons.reply, size: 16, color: c.white33),
                    const SizedBox(width: 8),
                    Text(
                      'Reply',
                      style: LabTextStyles.med15.copyWith(color: c.white33),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Options button — 41×41 hit area, 34px icon, no background.
          GestureDetector(
            onTap: () => showCommentActionsModal(context, comment: comment),
            child: SizedBox(
              width: 41,
              height: 41,
              child: Center(
                child: LabIcon(LabIcons.options, size: 34, color: c.white33),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single reply inside the thread modal.
///
/// Shows a [QuotedMessage] above the bubble when this reply's parent is not
/// the root comment (i.e. it is a nested reply), matching the webapp's
/// inline quoted-parent display.
class _ThreadReply extends ConsumerWidget {
  const _ThreadReply({
    required this.reply,
    required this.rootId,
    required this.byId,
    this.onReply,
    this.onActions,
  });

  final Comment reply;

  /// The ID of the root comment — used to detect nested (non-direct) replies.
  final String rootId;

  /// All comments in this thread keyed by event ID — used to resolve the
  /// quoted parent for nested replies.
  final Map<String, Comment> byId;

  final VoidCallback? onReply;
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(
      query<Profile>(
        authors: {reply.event.pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          stream: false,
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'tr-profile-${reply.event.pubkey}',
      ),
    );
    final profile = profileState.models.firstOrNull;

    // Resolve whether this reply targets a non-root comment (nested reply).
    final parentId = _getParentEventId(reply);
    final isNestedReply = parentId != null && parentId != rootId;
    final quotedComment = isNestedReply ? byId[parentId] : null;

    // Build bubble content: optional QuotedMessage prepended.
    Widget bubbleContent = NoteParser.parse(
      context,
      reply.content,
      emojiTags: NoteParser.extractEmojiTags(reply.event.tags),
    );

    if (quotedComment != null) {
      bubbleContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          QuotedMessage.fromComment(quotedComment),
          bubbleContent,
        ],
      );
    }

    return MessageBubble(
      profile: profile,
      pubkey: reply.event.pubkey,
      content: bubbleContent,
      timestamp: reply.createdAt,
      isLight: true,
      onReply: onReply,
      onActions: onActions,
    );
  }

  /// Extracts the lowercase `e` tag value (direct parent event ID) from a
  /// NIP-22 comment event, matching getCommentParentEventId() in thread-discussion.js.
  static String? _getParentEventId(Comment c) {
    for (final tag in c.event.tags) {
      if (tag.length >= 2 && tag[0] == 'e' && tag[1].isNotEmpty) {
        return tag[1].toLowerCase();
      }
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reply indicator (connector line + ProfilePicStack)
// ─────────────────────────────────────────────────────────────────────────────

/// Matches the `reply-indicator` div in RootComment.svelte:
/// vertical bar + curved L-corner SVG + [ProfilePicStack] with name text + count.
class _ReplyIndicator extends StatelessWidget {
  const _ReplyIndicator({
    required this.replierItems,
    required this.replyCount,
    required this.replyIndicatorText,
    this.onTap,
  });

  final List<ProfilePicItem> replierItems;
  final int replyCount;
  final String replyIndicatorText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Aligns the connector with the avatar center of the MessageBubble above
        // (avatar = 36px centered at 14 screen-pad + 18 = 32px from left edge)
        padding: const EdgeInsets.only(left: 32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Connector: visual 28px + 13px bottom padding aligns L-shape
            // endpoint with the vertical center of the 28px avatars on the right.
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: SizedBox(
                width: 25,
                height: 28,
                child: LabLConnector(color: c.white16),
              ),
            ),
            const SizedBox(width: 2),

            Flexible(
              child: ProfilePicStack(
                profiles: replierItems,
                text: replyIndicatorText,
                suffix: '$replyCount',
                avatarSize: 28,
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
