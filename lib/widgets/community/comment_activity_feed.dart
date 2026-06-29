import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/providers/comment_activity_feed_provider.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/paged_subscription_notifier.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/empty_state.dart';
import 'package:zapstore/widgets/community/comment_card.dart';
import 'package:zapstore/widgets/modals/actions_modal.dart';
import 'package:zapstore/widgets/social/root_comment.dart';

/// Distance from the bottom of the scroll view that triggers load-more.
const double kActivityFeedLoadMoreThreshold = 320;

/// Lazy-sliced comment activity list — only builds [visibleLimit] [CommentCard]s.
///
/// Root entities and quoted parents hydrate per-card via [CommentCard]'s own
/// subscriptions (same pattern as inbox / webapp CommentCard).
class CommentActivityFeed extends HookConsumerWidget {
  const CommentActivityFeed({
    super.key,
    required this.paged,
    required this.visibleLimit,
    required this.onLoadMore,
    this.scrollController,
    this.emptyMessage = 'No activity yet',
  });

  final PagedState<Comment> paged;
  final int visibleLimit;
  final VoidCallback onLoadMore;
  final ScrollController? scrollController;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = List<Comment>.from(paged.combined)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final firstPage = paged.firstPage;
    final isLoadingEmpty =
        firstPage is StorageLoading<Comment> && comments.isEmpty;
    final showSkeletonGate = useState(false);
    final loadingExpired = useState(false);

    useEffect(() {
      Timer? skeletonTimer;
      Timer? expireTimer;
      if (isLoadingEmpty) {
        skeletonTimer = Timer(const Duration(milliseconds: 100), () {
          showSkeletonGate.value = true;
        });
        expireTimer = Timer(const Duration(seconds: 6), () {
          loadingExpired.value = true;
        });
      } else {
        showSkeletonGate.value = false;
        loadingExpired.value = false;
      }
      return () {
        skeletonTimer?.cancel();
        expireTimer?.cancel();
      };
    }, [isLoadingEmpty]);

    if (comments.isEmpty) {
      if (isLoadingEmpty &&
          showSkeletonGate.value &&
          !loadingExpired.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: CommentCardSkeletonList(rowCount: 4),
        );
      }
      if (firstPage is StorageError) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Could not load activity',
            style: LabTextStyles.reg15.copyWith(
              color: Theme.of(context).extension<LabColors>()!.white33,
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: EmptyState(message: emptyMessage, minHeight: 120),
      );
    }

    final visible = comments.take(visibleLimit).toList();
    final feedRoots = ref.watch(activityFeedRootsProvider);
    final hasMore = activityFeedLikelyHasMore(
      visibleLimit: visibleLimit,
      loadedCount: comments.length,
      relayHasMore: paged.hasMore,
      isLoadingMore: paged.isLoadingMore,
    );

    void checkLoadMore() {
      if (!hasMore) return;
      final controller = scrollController;
      if (controller == null || !controller.hasClients) return;
      final pos = controller.position;
      final nearBottom = pos.maxScrollExtent <= 0 ||
          pos.pixels >= pos.maxScrollExtent - kActivityFeedLoadMoreThreshold;
      if (nearBottom) onLoadMore();
    }

    // Scroll listener — no one-shot arm; keeps loading while near bottom.
    useEffect(() {
      final controller = scrollController;
      if (controller == null) return null;
      controller.addListener(checkLoadMore);
      return () => controller.removeListener(checkLoadMore);
    }, [scrollController, hasMore, visibleLimit, comments.length]);

    // After rows grow, re-check whether we're still at the bottom and need more.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) => checkLoadMore());
      return null;
    }, [visibleLimit, comments.length, paged.isLoadingMore]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          for (int i = 0; i < visible.length; i++) ...[
            if (i > 0) const CommentCardRowDivider(),
            CommentCard(
              key: ValueKey(visible[i].id),
              comment: visible[i],
              useBatchedRoots: true,
              batchedRootModel:
                  feedRoots.modelFor(commentCardRootQueryId(visible[i].event)),
              batchedRootsLoading: feedRoots.loading,
              onCardTap: () => showThreadModal(
                context,
                ref,
                comment: visible[i],
              ),
              onReply: () => showThreadModal(
                context,
                ref,
                comment: visible[i],
                initialExpand: true,
              ),
              onActions: () => showCommentActionsModal(
                context,
                comment: visible[i],
                ref: ref,
              ),
            ),
          ],
          if (hasMore || paged.isLoadingMore) ...[
            const SizedBox(height: kCommentCardListGap),
            _ActivityFeedLoadMoreFooter(loading: paged.isLoadingMore),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ActivityFeedLoadMoreFooter extends StatelessWidget {
  const _ActivityFeedLoadMoreFooter({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: c.white33,
                ),
              )
            : const SizedBox(height: 1),
      ),
    );
  }
}

/// Returns true when [scrollOffset] is within [threshold] px of the bottom.
@visibleForTesting
bool activityFeedScrollNearBottom({
  required double scrollOffset,
  required double maxScrollExtent,
  double threshold = kActivityFeedLoadMoreThreshold,
}) {
  return maxScrollExtent <= 0 || scrollOffset >= maxScrollExtent - threshold;
}
