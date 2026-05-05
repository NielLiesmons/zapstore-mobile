import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/l_connector.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/common/note_parser.dart';
import 'package:zapstore/widgets/common/profile_pic_stack.dart';
import 'package:zapstore/widgets/social/message_bubble.dart';

/// Feed-level comment item matching webapp's RootComment.svelte.
///
/// Layout:
///   1. [MessageBubble] — avatar + gray66 bubble (author header + content).
///   2. [_ReplyIndicator] — connector line + [ProfilePicStack] (when replies exist).
///
/// Tapping opens [_ThreadModal] — a bottom sheet with blurred backdrop —
/// showing the root comment + all replies. No inline action rail (matches
/// webapp mobile behavior where there's no per-comment action row in the feed).
class RootComment extends ConsumerWidget {
  const RootComment({
    super.key,
    required this.comment,
  });

  final Comment comment;

  void _openThread(BuildContext context) {
    showModal<void>(
      context,
      fillHeight: true,
      maxHeightFactor: 0.75,
      footer: (_) => _ThreadFooter(comment: comment),
      builder: (_) => _ThreadBody(comment: comment),
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
      onTap: () => _openThread(context),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessageBubble(
            profile: author,
            pubkey: comment.event.pubkey,
            content: contentWidget,
            timestamp: comment.createdAt,
          ),

          // Reply indicator — pulled 2px up to sit closer to the bubble above.
          if (replies.isNotEmpty)
            Transform.translate(
              offset: const Offset(0, -2),
              child: _ReplyIndicator(
                replierItems: replierItemsWithProfiles,
                replyCount: replies.length,
                replyIndicatorText: replyIndicatorText,
                onTap: () => _openThread(context),
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

/// Scrollable body: root comment + divider + replies.
class _ThreadBody extends ConsumerWidget {
  const _ThreadBody({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final replies = comment.replies.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

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
        // Root comment (isLight variant = white8 bg)
        MessageBubble(
          profile: author,
          pubkey: comment.event.pubkey,
          content: NoteParser.parse(
            context,
            comment.content,
            emojiTags: NoteParser.extractEmojiTags(comment.event.tags),
          ),
          timestamp: comment.createdAt,
          isLight: true,
        ),

        // Divider — 1.4px white11, matching .thread-divider in webapp
        Container(height: 1.4, color: c.white11),

        // Replies
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
          ...replies.map((r) => _ThreadReply(reply: r)),

        const SizedBox(height: 8),
      ],
    );
  }
}

/// Pinned footer bar: comment input placeholder (tapping will open a nested
/// CommentModal — demonstrating the modal-in-modal scale effect).
class _ThreadFooter extends StatelessWidget {
  const _ThreadFooter({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return ModalFooterBar(
      child: GestureDetector(
        onTap: () {
          // Capture scope before the async gap to avoid BuildContext lint.
          final scope = ModalNestScope.maybeOf(context);
          scope?.onNestedChange(true);
          showModal<void>(
            context,
            title: 'Reply',
            builder: (_) => const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(height: 160),
            ),
          ).then((_) => scope?.onNestedChange(false));
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.black33,
            borderRadius: BorderRadius.circular(16),
            border: LabBorder.all(color: c.white33, width: 0.33),
          ),
          child: Row(
            children: [
              LabIcon(
                LabIcons.reply,
                size: 18,
                color: c.white33,
              ),
              const SizedBox(width: 8),
              Text(
                'Reply',
                style: LabTextStyles.med17.copyWith(color: c.white33),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single reply inside the thread modal — light MessageBubble.
class _ThreadReply extends ConsumerWidget {
  const _ThreadReply({required this.reply});

  final Comment reply;

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

    return MessageBubble(
      profile: profile,
      pubkey: reply.event.pubkey,
      content: NoteParser.parse(
        context,
        reply.content,
        emojiTags: NoteParser.extractEmojiTags(reply.event.tags),
      ),
      timestamp: reply.createdAt,
      isLight: true,
    );
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
            // Width matches the decreased avatar→bubble gap in MessageBubble (−2px).
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


