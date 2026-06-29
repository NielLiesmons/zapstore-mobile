import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/models/forum_post.dart';
import 'package:zapstore/utils/paged_subscription_notifier.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'package:zapstore/widgets/forum/forum_post_card.dart';
import 'package:zapstore/widgets/modals/forum_post_modal.dart';
import 'package:zapstore/widgets/social/comment_feed_composer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ForumFeedNotifier
// ─────────────────────────────────────────────────────────────────────────────
//
// Live-first + infinite-scroll feed of ForumPost (kind 11) events.
//
//   First page: stream: true — serves local cache immediately, merges remote
//   Older pages: one-shot `until` cursor queries, `stream: false`

class ForumFeedNotifier extends PagedSubscriptionNotifier<ForumPost> {
  ForumFeedNotifier(super.ref);

  @override
  int get pageSize => 10;

  ProviderSubscription<StorageState<ForumPost>>? _sub;

  @override
  void startSubscription() {
    _sub?.close();
    _sub = ref.listen(
      query<ForumPost>(
        until: DateTime.now(),
        limit: pageSize,
        tags: kForumPostCommunityTags,
        where: (post) => isZapstoreCommunityForumPost(post.event),
        schemaFilter: forumPostEventFilter,
        source: const LocalAndRemoteSource(relays: kDefaultRelay, stream: true),
        subscriptionPrefix: 'forum-feed',
      ),
      (_, next) => updateFirstPage(next),
      fireImmediately: true,
    );
  }

  @override
  Future<({List<ForumPost> items, int count})> fetchOlderPage(
    DateTime until,
  ) async {
    final storage = ref.read(storageNotifierProvider.notifier);
    final items = await storage.query(
      RequestFilter<ForumPost>(
        until: until,
        limit: pageSize,
        tags: kForumPostCommunityTags,
      ).toRequest(),
      source: const LocalAndRemoteSource(relays: kDefaultRelay, stream: false),
      subscriptionPrefix: 'forum-feed-older',
    );
    final filtered = items
        .where((post) => isZapstoreCommunityForumPost(post.event))
        .toList();
    return (items: filtered, count: filtered.length);
  }

  @override
  String getId(ForumPost item) => item.id;

  @override
  DateTime getCreatedAt(ForumPost item) => item.event.createdAt;

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}

final forumFeedProvider =
    StateNotifierProvider.autoDispose<ForumFeedNotifier, PagedState<ForumPost>>(
  (ref) => ForumFeedNotifier(ref),
);

// ─────────────────────────────────────────────────────────────────────────────
// ForumFeedContainer
// ─────────────────────────────────────────────────────────────────────────────
//
// Displays the forum feed using [ForumPostCard] cards. Shows shimmer skeletons
// during initial load (with a 100ms delay per DESIGN_SYSTEM.md) and triggers
// [loadMore] when the user scrolls within 300px of the bottom.

class ForumFeedContainer extends HookConsumerWidget {
  const ForumFeedContainer({
    super.key,
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(forumFeedProvider);

    // 100ms delay before showing skeletons (DESIGN_SYSTEM loading rule)
    final showSkeleton = useState(false);
    useEffect(() {
      if (state.firstPage is StorageLoading<ForumPost> &&
          state.combined.isEmpty) {
        final timer = Future.delayed(
          const Duration(milliseconds: 100),
          () {
            if (state.firstPage is StorageLoading<ForumPost> &&
                state.combined.isEmpty) {
              showSkeleton.value = true;
            }
          },
        );
        timer.ignore();
      } else {
        showSkeleton.value = false;
      }
      return null;
    }, [state.firstPage.runtimeType]);

    // Trigger loadMore when within 300px of the bottom
    useEffect(() {
      void listener() {
        if (!scrollController.hasClients) return;
        final pos = scrollController.position;
        if (pos.pixels >= pos.maxScrollExtent - 300) {
          ref.read(forumFeedProvider.notifier).loadMore();
        }
      }

      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController]);

    final posts = state.combined;

    final composer = CommentFeedComposer(
      ctaLabel: 'Your Forum Post',
      padding: const EdgeInsets.fromLTRB(14, 12, 21, 7),
      onTap: () => showForumPostModal(context, ref),
    );

    // Initial loading state
    if (posts.isEmpty) {
      if (!showSkeleton.value) return composer;
      return Column(
        children: [
          composer,
          _buildSkeletonList(count: 5),
        ],
      );
    }

    return Column(
      children: [
        composer,
        ...posts.map(
          (post) => ForumPostCard(
            key: ValueKey(post.id),
            post: post,
            onTap: () => context.push('/forum/${post.id}'),
          ),
        ),

        // Load-more indicator
        if (state.isLoadingMore) _buildSkeletonList(count: 2),

        // End of feed spacer
        if (!state.hasMore && !state.isLoadingMore)
          const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSkeletonList({required int count}) {
    return ShimmerTheme(
      child: Column(
        children: List.generate(count, (_) => const ForumPostCardSkeleton()),
      ),
    );
  }
}
