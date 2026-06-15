import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/providers/comment_activity_feed_provider.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/empty_state.dart';
import 'package:zapstore/widgets/community/comment_card.dart';
import 'package:zapstore/widgets/modals/actions_modal.dart';
import 'package:zapstore/widgets/social/root_comment.dart';

/// Lazy-sliced comment activity list — only builds [visibleLimit] [CommentCard]s.
///
/// Root entities and quoted parents hydrate per-card via [CommentCard]'s own
/// subscriptions (same pattern as inbox / webapp CommentCard).
class CommentActivityFeed extends HookConsumerWidget {
  const CommentActivityFeed({
    super.key,
    required this.commentsState,
    required this.visibleLimit,
    required this.onLoadMore,
    this.scrollController,
    this.emptyMessage = 'No activity yet',
  });

  final StorageState<Comment> commentsState;
  final int visibleLimit;
  final VoidCallback onLoadMore;
  final ScrollController? scrollController;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = List<Comment>.from(commentsState.models)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final showSkeletonGate = useState(false);
    useEffect(() {
      if (commentsState is StorageLoading && comments.isEmpty) {
        final timer = Future.delayed(
          const Duration(milliseconds: 100),
          () => showSkeletonGate.value = true,
        );
        timer.ignore();
      } else {
        showSkeletonGate.value = false;
      }
      return null;
    }, [commentsState.runtimeType, comments.length]);

    if (comments.isEmpty) {
      if (commentsState is StorageLoading && showSkeletonGate.value) {
        return const CommentCardSkeletonList(rowCount: 4);
      }
      if (commentsState is StorageError) {
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
        child: EmptyState(message: emptyMessage, minHeight: 160),
      );
    }

    final visible = comments.take(visibleLimit).toList();
    final hasMore = activityFeedLikelyHasMore(
      visibleLimit: visibleLimit,
      loadedCount: comments.length,
      isSyncing: commentsState is StorageLoading,
    );

    // Load more when the parent scroll view nears the bottom.
    useEffect(() {
      final controller = scrollController;
      if (controller == null) return null;

      var loadArmed = true;

      void listener() {
        if (!hasMore || !controller.hasClients) return;
        final pos = controller.position;
        final nearBottom =
            pos.maxScrollExtent <= 0 || pos.pixels >= pos.maxScrollExtent - 320;
        if (nearBottom) {
          if (loadArmed) {
            loadArmed = false;
            onLoadMore();
          }
        } else {
          loadArmed = true;
        }
      }

      controller.addListener(listener);
      WidgetsBinding.instance.addPostFrameCallback((_) => listener());
      return () => controller.removeListener(listener);
    }, [scrollController, hasMore, visibleLimit]);

    return Column(
      children: [
        for (int i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: kCommentCardListGap),
          CommentCard(
            key: ValueKey(visible[i].id),
            comment: visible[i],
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
        if (hasMore) ...[
          const SizedBox(height: kCommentCardListGap),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
