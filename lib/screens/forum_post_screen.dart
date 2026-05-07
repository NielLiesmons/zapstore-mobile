import 'dart:math' show max;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/services/nostr_comment_service.dart';
import 'package:zapstore/models/forum_post.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/dropdown_menu.dart';
import 'package:zapstore/widgets/common/empty_state.dart';
import 'package:zapstore/widgets/common/note_parser.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/profile_pic_stack.dart';
import 'package:zapstore/widgets/common/time_utils.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'package:zapstore/widgets/common/top_scroll_fader.dart';
import 'package:zapstore/widgets/modals/comment_actions_modal.dart';
import 'package:zapstore/widgets/modals/comment_modal.dart';
import 'package:zapstore/widgets/social/bottom_bar.dart';
import 'package:zapstore/widgets/social/details_tab.dart';
import 'package:zapstore/widgets/social/social_tabs.dart';
import 'package:zapstore/widgets/social/zap_comment_item.dart';
import 'package:zapstore/widgets/social/zaps_section.dart';
import 'package:zapstore/widgets/social/root_comment.dart';

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
  const ForumPostScreen({
    super.key,
    required this.postId,
    this.initialComments,
  });

  final String postId;

  /// Comments fetched by [ForumPostCard] on the home screen, passed here so
  /// the detail view can display them instantly while the full query warms up.
  final List<Comment>? initialComments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Load the forum post
    final postState = ref.watch(
      query<ForumPost>(
        ids: {postId},
        limit: 1,
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: false),
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

    return _ForumPostContent(post: post, initialComments: initialComments);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content widget — separated so it only rebuilds once the post is loaded
// ─────────────────────────────────────────────────────────────────────────────

class _ForumPostContent extends HookConsumerWidget {
  const _ForumPostContent({required this.post, this.initialComments});

  final ForumPost post;
  final List<Comment>? initialComments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final signedInPubkey = ref.watch(Signer.activePubkeyProvider);
    final isSignedIn = signedInPubkey != null;

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
    final scrollTopPad = topPad + 48.0;
    final scrollController = useScrollController();

    return Scaffold(
      body: Stack(
        children: [
          // ── Scrollable body ────────────────────────────────────────────────
          Positioned.fill(
            child: TopScrollFader(
              scrollController: scrollController,
              fadeStart: scrollTopPad,
              hasBottomBar: true,
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: scrollTopPad + 10,
                  bottom: MediaQuery.paddingOf(context).bottom + 80,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Post title ─────────────────────────────────────────
                    if (post.title?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                        child: Text(
                          post.title!,
                          style: LabTextStyles.semibold23.copyWith(
                            color: c.white,
                            height: 1.3,
                          ),
                        ),
                      ),

                    // ── Post body ──────────────────────────────────────────
                    if (post.content.isNotEmpty)
                      _ExpandableBody(content: post.content),

                    // ── Social tabs ────────────────────────────────────────
                        SocialTabs(
                      contentBuilder: (tab) => switch (tab) {
                        SocialTab.comments => _ForumCommentsSection(
                            post: post,
                            initialComments: initialComments,
                          ),
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

          // ── Fixed blurred header ───────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ForumPostHeader(
              post: post,
              author: author,
              catalogProfile: catalogProfile,
            ),
          ),

          // ── Bottom bar ────────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BottomBar(
              isSignedIn: isSignedIn,
              onZap: () {},
              onComment: () => showCommentModal(
                context,
                placeholder: 'Reply to this post…',
                onSubmit: (result) => publishRootComment(
                  ref: ref,
                  result: result,
                  forumPost: post,
                ),
              ),
              onOptions: () => showCommentActionsModal(context),
              onGetStarted: () {},
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixed blurred header — identical structure to _DetailHeader in AppDetailScreen
// ─────────────────────────────────────────────────────────────────────────────
//
// Layout (topPad + 8 + 30 + 10 = topPad + 48, same scrollTopPad constant):
//   SizedBox(topPad + 8)
//   Padding(horizontal: 14)
//     Row: [back 30×30] [10] [ProfilePic 28] [12] [Expanded: "By name" + timestamp] [10] [ProfilePicStack]
//   SizedBox(10)

class _ForumPostHeader extends HookWidget {
  const _ForumPostHeader({
    required this.post,
    required this.author,
    required this.catalogProfile,
  });

  final ForumPost post;
  final Profile? author;
  final Profile? catalogProfile;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final topPad = MediaQuery.paddingOf(context).top;

    final overlayController = useMemoized(() => OverlayPortalController());
    final layerLink = useMemoized(() => LayerLink());
    final groupId =
        useMemoized(() => 'forum-community-dropdown-${post.id}');

    final publisherName = author?.name ??
        '${post.pubkey.substring(0, 6)}…${post.pubkey.substring(post.pubkey.length - 4)}';

    final communityItems = [
      if (catalogProfile != null) ProfilePicItem(profile: catalogProfile),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: c.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: topPad + 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => context.pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: c.gray33,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: LabIcon(
                              LabIcons.chevronLeft,
                              size: 14,
                              color: c.white33,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Author avatar — 28px matches AppDetailScreen
                    ProfilePic(profile: author, pubkey: post.pubkey, size: 28),

                    const SizedBox(width: 12),

                    // "By [name]" + timestamp inline
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                style: LabTextStyles.med15.copyWith(color: c.white66),
                                children: [
                                  const TextSpan(text: 'By '),
                                  TextSpan(text: publisherName),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: TimeAgoText(
                              post.createdAt,
                              style: LabTextStyles.reg13
                                  .copyWith(color: c.white33),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Community stack with overlay dropdown
                    if (communityItems.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      OverlayPortal(
                        controller: overlayController,
                        overlayChildBuilder: (ctx) =>
                            CompositedTransformFollower(
                          link: layerLink,
                          showWhenUnlinked: false,
                          targetAnchor: Alignment.bottomRight,
                          followerAnchor: Alignment.topRight,
                          offset: const Offset(0, 4),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: TapRegion(
                              groupId: groupId,
                              onTapOutside: (_) => overlayController.hide(),
                              child: LabDropdownMenu(
                                constraints:
                                    const BoxConstraints(minWidth: 220),
                                children: [
                                  LabDropdownItem(
                                    isFirst: true,
                                    child: Text(
                                      'This post is published in the following communities:',
                                      style: LabTextStyles.reg13
                                          .copyWith(color: c.white66),
                                    ),
                                  ),
                                  for (final item in communityItems)
                                    LabDropdownItem(
                                      child: Text(
                                        item.profile?.name ?? 'Community',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        child: TapRegion(
                          groupId: groupId,
                          child: CompositedTransformTarget(
                            link: layerLink,
                            child: ProfilePicStack(
                              profiles: communityItems,
                              avatarSize: 28,
                              suffix: '${communityItems.length}',
                              onTap: () {
                                if (overlayController.isShowing) {
                                  overlayController.hide();
                                } else {
                                  overlayController.show();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
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
  const _ForumCommentsSection({
    required this.post,
    this.initialComments,
  });

  final ForumPost post;

  /// Comments pre-loaded on the home feed — used as the immediate display
  /// while the full remote query warms up, eliminating skeleton re-flashing.
  final List<Comment>? initialComments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Unified subscription prefix matches ForumPostCard so the Riverpod
    // provider is shared when the card is still in the widget tree.
    final commentsState = ref.watch(
      query<Comment>(
        tags: {'#E': {post.id}},
        source: const LocalAndRemoteSource(
          relays: 'AppCatalog',
          stream: true,
        ),
        subscriptionPrefix: 'forum-post-comments-${post.id}',
      ),
    );

    final zapsState = ref.watch(
      query<Zap>(
        tags: {'#e': {post.id}},
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: true),
        subscriptionPrefix: 'forum-post-comments-zaps-${post.id}',
      ),
    );

    // When the query is still loading, fall back to pre-loaded comments so the
    // UI shows content immediately instead of a skeleton.
    final comments = switch (commentsState) {
      StorageData(:final models) => models,
      _ => initialComments ?? <Comment>[],
    };
    final zapModels = switch (zapsState) {
      StorageData(:final models) => models,
      _ => <Zap>[],
    };

    final rootComments = comments.where((c) => c.parentKind != 1111).toList();
    final zapsWithComments = zapModels
        .where((z) => z.event.content.trim().isNotEmpty)
        .toList();

    // Merge root comments and zaps-with-comments, sorted newest first.
    final entries = <_FeedEntry>[
      ...rootComments.map((c) => _FeedEntry(createdAt: c.createdAt, comment: c)),
      ...zapsWithComments.map((z) => _FeedEntry(createdAt: z.createdAt, zap: z)),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (entries.isEmpty) {
      // Only show skeleton if we have no pre-loaded data to fall back to.
      if (commentsState is StorageLoading && initialComments == null) {
        return const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: BubbleSkeletonList(),
        );
      }
      return const EmptyState(
        message: 'No comments yet. Be the first!',
        minHeight: 160,
      );
    }

    return Column(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          if (entries[i].comment != null)
            RootComment(
              key: ValueKey(entries[i].comment!.id),
              comment: entries[i].comment!,
            )
          else
            ZapCommentItem(
              key: ValueKey(entries[i].zap!.id),
              zap: entries[i].zap!,
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
