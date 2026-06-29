import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/providers/activity_feed_notifier.dart';
import 'package:zapstore/utils/paged_subscription_notifier.dart';
import 'package:zapstore/widgets/community/comment_card.dart';

/// How many [CommentCard] rows to paint at once — keeps heavy cards off-screen.
const int kActivityFeedInitialVisible = 15;
const int kActivityFeedVisibleStep = 15;

/// Webapp ACTIVITY_FEED_VISIBLE_MAX — UI may reveal up to this many rows.
const int kActivityFeedMaxVisible = 2500;

/// How many items from the end of the loaded pool should trigger a relay fetch.
const int kActivityFeedRelayPrefetchMargin = 5;

final communityActivityVisibleLimitProvider =
    StateProvider.autoDispose<int>((ref) => kActivityFeedInitialVisible);

final profileActivityVisibleLimitProvider =
    StateProvider.autoDispose.family<int, String>(
  (ref, _) => kActivityFeedInitialVisible,
);

/// Next visible row cap after a load-more gesture.
int nextActivityVisibleLimit(int current) => math.min(
      current + kActivityFeedVisibleStep,
      kActivityFeedMaxVisible,
    );

/// Whether the UI should offer / accept another load-more (scroll sentinel).
bool activityFeedLikelyHasMore({
  required int visibleLimit,
  required int loadedCount,
  required bool relayHasMore,
  bool isLoadingMore = false,
}) {
  if (visibleLimit < loadedCount) return true;
  if (visibleLimit >= kActivityFeedMaxVisible) {
    return relayHasMore || isLoadingMore;
  }
  return relayHasMore || isLoadingMore;
}

/// When the user nears the end of rendered rows, fetch older events from relay.
bool shouldFetchOlderActivityPage({
  required int visibleLimit,
  required int loadedCount,
  required bool relayHasMore,
  required bool isLoadingMore,
}) {
  if (!relayHasMore || isLoadingMore) return false;
  if (loadedCount == 0) return false;
  return visibleLimit >= loadedCount - kActivityFeedRelayPrefetchMargin;
}

/// Unified load-more: reveal more rows, then backfill from relay when needed.
Future<void> handleActivityFeedLoadMore({
  required WidgetRef ref,
  required PagedState<Comment> paged,
  required void Function(int) setVisibleLimit,
  required int currentVisible,
  required Future<void> Function() fetchOlderPage,
}) async {
  final nextVisible = nextActivityVisibleLimit(currentVisible);
  if (nextVisible != currentVisible) {
    setVisibleLimit(nextVisible);
  }

  final loaded = paged.combined.length;
  final probeLimit =
      nextVisible > currentVisible ? nextVisible : currentVisible;

  if (shouldFetchOlderActivityPage(
    visibleLimit: probeLimit,
    loadedCount: loaded,
    relayHasMore: paged.hasMore,
    isLoadingMore: paged.isLoadingMore,
  )) {
    await fetchOlderPage();
  }
}

/// Batched NIP-22 root entities for visible activity rows — one relay subscription.
class ActivityFeedRoots {
  const ActivityFeedRoots({
    required this.loading,
    required this.byQueryId,
  });

  final bool loading;
  final Map<String, Model> byQueryId;

  Model? modelFor(String? queryId) =>
      queryId == null ? null : byQueryId[queryId];
}

final activityFeedRootsProvider =
    Provider.autoDispose<ActivityFeedRoots>((ref) {
  try {
    final paged = ref.watch(communityActivityFeedProvider);
    final visibleLimit = ref.watch(communityActivityVisibleLimitProvider);
    final comments = List<Comment>.from(paged.combined)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final visible = comments.take(visibleLimit);

    final rootIds = <String>{};
    for (final c in visible) {
      final id = commentCardRootQueryId(c.event);
      if (id != null) rootIds.add(id);
    }

    if (rootIds.isEmpty) {
      return const ActivityFeedRoots(loading: false, byQueryId: {});
    }

    final state = ref.watch(
      queryKinds(
        ids: rootIds,
        limit: rootIds.length,
        source: kCommentCardRootSource,
        subscriptionPrefix: 'activity-feed-roots-batch',
      ),
    );

    final map = <String, Model>{};
    for (final raw in state.models) {
      if (raw is! Model) continue;
      map[raw.id] = raw;
      map[raw.event.id] = raw;
    }

    final loading = state is StorageLoading &&
        map.keys.toSet().intersection(rootIds).length < rootIds.length;

    return ActivityFeedRoots(loading: loading, byQueryId: map);
  } catch (e, stack) {
    debugPrint('activityFeedRootsProvider failed: $e\n$stack');
    return const ActivityFeedRoots(loading: false, byQueryId: {});
  }
});
