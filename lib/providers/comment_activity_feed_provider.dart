import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';

/// How many [CommentCard] rows to paint at once — keeps heavy cards off-screen.
const int kActivityFeedInitialVisible = 15;
const int kActivityFeedVisibleStep = 15;
const int kActivityFeedMaxVisible = 80;

/// Community-wide kind-1111 feed (Zapstore relay). Pool is capped; UI slices by
/// [communityActivityVisibleLimitProvider].
final communityActivityCommentsProvider = query<Comment>(
  limit: 150,
  source: const LocalAndRemoteSource(
    relays: kDefaultRelay,
    stream: true,
  ),
  subscriptionPrefix: 'community-activity-comments',
);

final communityActivityVisibleLimitProvider =
    StateProvider.autoDispose<int>((ref) => kActivityFeedInitialVisible);

/// Per-profile kind-1111 comments authored by [pubkey].
AutoDisposeStateNotifierProvider<RequestNotifier<Comment>, StorageState<Comment>>
    profileActivityCommentsProvider(String pubkey) {
  return query<Comment>(
    authors: {pubkey},
    limit: 150,
    source: const LocalAndRemoteSource(
      relays: kDefaultRelay,
      stream: true,
    ),
    subscriptionPrefix: 'profile-activity-$pubkey',
  );
}

final profileActivityVisibleLimitProvider =
    StateProvider.autoDispose.family<int, String>(
  (ref, _) => kActivityFeedInitialVisible,
);

bool activityFeedLikelyHasMore({
  required int visibleLimit,
  required int loadedCount,
  bool isSyncing = false,
}) {
  if (visibleLimit >= kActivityFeedMaxVisible) return false;
  if (visibleLimit < loadedCount) return true;
  if (loadedCount >= 150) return false;
  return isSyncing;
}
