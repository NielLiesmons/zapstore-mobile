import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/services/nostr_comment_service.dart';
import 'package:zapstore/models/forum_post.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/comments_section.dart';
import 'package:zapstore/widgets/common/detail_page_chrome.dart';
import 'package:zapstore/widgets/common/empty_state.dart';
import 'package:zapstore/widgets/common/note_parser.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/profile_pic_stack.dart';
import 'package:zapstore/widgets/common/time_utils.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'package:zapstore/widgets/common/top_scroll_fader.dart';
import 'package:zapstore/widgets/modals/actions_modal.dart';
import 'package:zapstore/widgets/modals/comment_modal.dart';
import 'package:zapstore/widgets/social/comment_feed_composer.dart';
import 'package:zapstore/widgets/social/details_tab.dart';
import 'package:zapstore/widgets/social/social_tabs.dart';
import 'package:zapstore/widgets/social/zap_comment_item.dart';
import 'package:zapstore/widgets/social/zaps_section.dart';
import 'package:zapstore/widgets/social/root_comment.dart';
import 'package:zapstore/widgets/social/thread_root.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ForumPostScreen
// ─────────────────────────────────────────────────────────────────────────────
//
// Detail view for a single kind-11 ForumPost. Mirrors the structure of
// AppDetailScreen and chateau-web's ForumPostDetail.svelte:
//
//   Stack
//   ├─ Positioned.fill  → TopScrollFader → scrollable body
//   │    title · content (expandable) · SocialTabs
//   ├─ Positioned top   → blurred fixed header (back + author + timestamp)
//   └─ Positioned bottom → BottomBar (when signed in)

class ForumPostScreen extends HookConsumerWidget {
  const ForumPostScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postState = ref.watch(
      query<ForumPost>(
        ids: {postId},
        limit: 1,
        tags: kForumPostCommunityTags,
        where: (post) => isZapstoreCommunityForumPost(post.event),
        schemaFilter: forumPostEventFilter,
        source: const LocalAndRemoteSource(relays: kDefaultRelay, stream: false),
        subscriptionPrefix: 'forum-post-$postId',
      ),
    );

    final post = postState.models.firstOrNull;

    if (post == null) {
      return Scaffold(
        body: Center(
          child: postState is StorageLoading
              ? const CircularProgressIndicator()
              : const Text('Post not found'),
        ),
      );
    }

    return _ForumPostContent(post: post);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content widget — separated so it only rebuilds once the post is loaded
// ─────────────────────────────────────────────────────────────────────────────

class _ForumPostContent extends HookConsumerWidget {
  const _ForumPostContent({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    // Author profile
    final authorState = ref.watch(
      query<Profile>(
        authors: {post.pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'forum-post-detail-profile-${post.pubkey}',
      ),
    );
    final author = authorState.models.firstOrNull;

    // Zapstore community profile for the header stack
    final catalogProfileState = ref.watch(
      query<Profile>(
        authors: {kZapstoreCommunityPubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          cachedFor: Duration(hours: 6),
        ),
        subscriptionPrefix: 'forum-post-detail-catalog-profile',
      ),
    );
    final catalogProfile = catalogProfileState.models.firstOrNull;

    final topPad = MediaQuery.paddingOf(context).top;
    final scrollController = useScrollController();
    final publisherName = author?.name ?? detailShortPubkey(post.pubkey);
    final communityItems = [
      if (catalogProfile != null) ProfilePicItem(profile: catalogProfile),
    ];

    final commentsState = ref.watch(
      query<Comment>(
        tags: {'#E': {post.id}},
        source: const LocalAndRemoteSource(
          relays: kDefaultRelay,
          stream: true,
        ),
        subscriptionPrefix: 'forum-post-comments-${post.id}',
      ),
    );
    final commentTabMeta = commentFeedTabMeta(commentsState);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TopScrollFader(
              scrollController: scrollController,
              fadeHeight: 48,
              safeEdgeFades: true,
              hasBottomBar: false,
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: topPad + 8,
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailAuthorMetaRow(
                      leading: ProfilePic(
                        profile: author,
                        pubkey: post.pubkey,
                        size: kDetailAuthorAvatarSize,
                      ),
                      title: publisherName,
                      onAuthorTap: () => pushUser(context, post.pubkey),
                      timestamp: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: TimeAgoText(
                          post.createdAt,
                          style: LabTextStyles.reg13.copyWith(color: c.white33),
                        ),
                      ),
                      trailing: DetailCommunityMenu(
                        groupId: 'forum-community-dropdown-${post.id}',
                        menuTitle:
                            'This post is published in the following communities:',
                        items: communityItems,
                      ),
                    ),

                    if (post.title?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                        child: Text(
                          post.title!,
                          style: LabTextStyles.heroTitle.copyWith(
                            color: c.white,
                          ),
                        ),
                      ),

                    // ── Post body ──────────────────────────────────────────
                    if (post.content.isNotEmpty)
                      _ExpandableBody(content: post.content),

                    // ── Social tabs ────────────────────────────────────────
                    SocialTabs(
                      commentCount: commentTabMeta.count,
                      commentsLoading: commentTabMeta.initialLoading,
                      commentsSyncing: commentTabMeta.syncing,
                      contentBuilder: (tab) => switch (tab) {
                        SocialTab.comments => _ForumCommentsSection(post: post),
                        SocialTab.zaps => ZapsSection(
                            tags: {'#e': {post.id}},
                            subscriptionId: post.id,
                          ),
                        SocialTab.labels => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No labels yet')),
                          ),
                        SocialTab.details => DetailsTab(
                            publicationLabel: 'Post',
                            shareableId: post.id,
                            pubkey: post.pubkey,
                            repository: null,
                          ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          DetailActionsButtonOverlay(
            onTap: () => showActionsModal(
              context,
              contentType: ActionsContentType.forum,
              rootContext: ThreadRootContext.fromForumPost(post),
              onCommentSubmit: (result) => publishRootComment(
                ref: ref,
                result: result,
                forumPost: post,
              ),
              ref: ref,
            ),
            scrollController: scrollController,
            expandLabel: 'Forum Post',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable body — line-count trimming (matches webapp's ShortTextContent)
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandableBody extends HookWidget {
  const _ExpandableBody({required this.content});

  final String content;

  // Mirror webapp's ShortTextContent constants exactly.
  static const _linesLimit = 16;
  static const _mediaLines = 10;
  static const _nostrRefLines = 10;
  static const _charsPerLine = 60;

  static bool _isMediaLine(String line) {
    final t = line.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return false;
    try {
      final path = Uri.parse(t).path.toLowerCase();
      if (RegExp(r'\.(jpg|jpeg|png|gif|webp|avif|bmp|ico|mp4|webm|ogg|mov)$')
          .hasMatch(path)) {
        return true;
      }
      final host = Uri.parse(t).host.toLowerCase();
      return host == 'nostr.build' ||
          host.endsWith('.nostr.build') ||
          host == 'void.cat';
    } catch (_) {
      return false;
    }
  }

  static bool _isNostrRefLine(String line) {
    return RegExp(r'^nostr:n(addr|event)[a-z0-9]+$', caseSensitive: false)
        .hasMatch(line.trim());
  }

  static int _lineCount(String line) {
    if (_isMediaLine(line)) return _mediaLines;
    if (_isNostrRefLine(line)) return _nostrRefLines;
    if (line.isEmpty) return 1;
    return max(1, (line.length / _charsPerLine).ceil());
  }

  /// Returns (contentToRender, wasTruncated).
  /// Mirrors webapp's buildDisplay / truncateText logic.
  static (String, bool) _trim(String raw) {
    final lines = raw.split('\n');
    int usedLines = 0;
    final sb = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lc = _lineCount(line);
      if (usedLines + lc > _linesLimit) {
        final remaining = _linesLimit - usedLines;
        if (remaining > 0 && !_isMediaLine(line) && !_isNostrRefLine(line)) {
          if (i > 0) sb.write('\n');
          sb.write(line.substring(0, (remaining * _charsPerLine).clamp(0, line.length)));
        }
        return (sb.toString(), true);
      }
      if (i > 0) sb.write('\n');
      sb.write(line);
      usedLines += lc;
    }
    return (raw, false);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final expanded = useState(false);

    // Stable: compute once per content change so button never flickers.
    final (trimmed, wasTruncated) = useMemoized(() => _trim(content), [content]);
    final display = expanded.value ? content : trimmed;

    final textStyle = LabTextStyles.reg15.copyWith(
      color: c.white.withValues(alpha: 0.85),
      height: 1.55,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          NoteParser.parse(
            context,
            display,
            textStyle: textStyle,
          ),
          if (wasTruncated) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => expanded.value = !expanded.value,
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: c.white8,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Center(
                  child: Text(
                    expanded.value ? 'Read less' : 'Read more',
                    style: LabTextStyles.med13.copyWith(color: c.white66),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Forum comments section
// ─────────────────────────────────────────────────────────────────────────────
//
// Kind-1111 comments referencing this forum post via the uppercase #E tag
// (NIP-22: RegularModel root reference). Renders using the existing
// RootComment widget, same as app comments.

class _FeedEntry {
  const _FeedEntry({required this.createdAt, this.comment, this.zap})
      : assert(comment != null || zap != null);

  final DateTime createdAt;
  final Comment? comment;
  final Zap? zap;
}

class _ForumCommentsSection extends ConsumerWidget {
  const _ForumCommentsSection({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same subscription prefix as ForumPostCard — Riverpod shares the provider
    // when the card is still in the widget tree, and the SQLite cache populated
    // by the card's unlimited query provides instant data on first open.
    final commentsState = ref.watch(
      query<Comment>(
        tags: {'#E': {post.id}},
        source: const LocalAndRemoteSource(
          relays: kDefaultRelay,
          stream: true,
        ),
        subscriptionPrefix: 'forum-post-comments-${post.id}',
      ),
    );

    final zapsState = ref.watch(
      query<Zap>(
        tags: {'#e': {post.id}},
        source: const LocalAndRemoteSource(relays: kDefaultRelay, stream: true),
        subscriptionPrefix: 'forum-post-comments-zaps-${post.id}',
      ),
    );

    final comments = commentsState.models;
    final zapModels = zapsState.models;

    final rootComments = comments.where((c) => c.parentKind != 1111).toList();
    final zapsWithComments = zapModels
        .where((z) => z.event.content.trim().isNotEmpty)
        .toList();

    // Merge root comments and zaps-with-comments, sorted newest first.
    final entries = <_FeedEntry>[
      ...rootComments.map((c) => _FeedEntry(createdAt: c.createdAt, comment: c)),
      ...zapsWithComments.map((z) => _FeedEntry(createdAt: z.createdAt, zap: z)),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommentFeedComposer(
          ctaLabel: 'Your Comment',
          onTap: () => showCommentModal(
            context,
            placeholder: 'Comment on this post…',
            rootContext: ThreadRootContext.fromForumPost(post),
            showRootConnector: true,
            onSubmit: (result) => publishRootComment(
              ref: ref,
              result: result,
              forumPost: post,
            ),
          ),
        ),
        if (entries.isEmpty)
          if (commentsState is StorageLoading && comments.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: BubbleSkeletonList(),
            )
          else
            const EmptyState(
              message: 'No comments yet. Be the first!',
              minHeight: 160,
            )
        else
          Column(
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                if (entries[i].comment != null)
                  RootComment(
                    key: ValueKey(entries[i].comment!.id),
                    comment: entries[i].comment!,
                    rootContext: ThreadRootContext.fromForumPost(post),
                  )
                else
                  ZapCommentItem(
                    key: ValueKey(entries[i].zap!.id),
                    zap: entries[i].zap!,
                    topPadding: i == 0 ? 0 : 4,
                  ),
              ],
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
