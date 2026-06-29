import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/utils/paged_subscription_notifier.dart';

/// Relay page size for activity feeds (webapp ACTIVITY_INITIAL_SEED_LIMIT ≈ 60).
const int kActivityFeedPageSize = 60;

/// Community-wide kind-1111 activity on the Zapstore relay.
class CommunityActivityFeedNotifier extends PagedSubscriptionNotifier<Comment> {
  CommunityActivityFeedNotifier(super.ref);

  ProviderSubscription<StorageState<Comment>>? _sub;

  @override
  int get pageSize => kActivityFeedPageSize;

  @override
  void startSubscription() {
    _sub?.close();
    _sub = ref.listen(
      query<Comment>(
        until: DateTime.now(),
        limit: pageSize,
        source: const LocalAndRemoteSource(
          relays: kDefaultRelay,
          stream: true,
        ),
        subscriptionPrefix: 'community-activity-comments',
      ),
      (_, next) => updateFirstPage(next),
      fireImmediately: true,
    );
  }

  @override
  Future<({List<Comment> items, int count})> fetchOlderPage(
    DateTime until,
  ) async {
    final storage = ref.read(storageNotifierProvider.notifier);
    final items = await storage.query(
      RequestFilter<Comment>(
        until: until,
        limit: pageSize,
      ).toRequest(),
      source: const LocalAndRemoteSource(relays: kDefaultRelay, stream: false),
      subscriptionPrefix: 'community-activity-comments-older',
    );
    return (items: items, count: items.length);
  }

  @override
  String getId(Comment item) => item.id;

  @override
  DateTime getCreatedAt(Comment item) => item.createdAt;

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}

final communityActivityFeedProvider = StateNotifierProvider.autoDispose<
    CommunityActivityFeedNotifier, PagedState<Comment>>(
  (ref) => CommunityActivityFeedNotifier(ref),
);

/// Per-profile kind-1111 comments authored by [pubkey].
class ProfileActivityFeedNotifier extends PagedSubscriptionNotifier<Comment> {
  ProfileActivityFeedNotifier(super.ref, this.pubkey);

  final String pubkey;
  ProviderSubscription<StorageState<Comment>>? _sub;

  @override
  int get pageSize => kActivityFeedPageSize;

  @override
  void startSubscription() {
    _sub?.close();
    _sub = ref.listen(
      query<Comment>(
        authors: {pubkey},
        until: DateTime.now(),
        limit: pageSize,
        source: const LocalAndRemoteSource(
          relays: kDefaultRelay,
          stream: true,
        ),
        subscriptionPrefix: 'profile-activity-$pubkey',
      ),
      (_, next) => updateFirstPage(next),
      fireImmediately: true,
    );
  }

  @override
  Future<({List<Comment> items, int count})> fetchOlderPage(
    DateTime until,
  ) async {
    final storage = ref.read(storageNotifierProvider.notifier);
    final items = await storage.query(
      RequestFilter<Comment>(
        authors: {pubkey},
        until: until,
        limit: pageSize,
      ).toRequest(),
      source: const LocalAndRemoteSource(relays: kDefaultRelay, stream: false),
      subscriptionPrefix: 'profile-activity-older-$pubkey',
    );
    return (items: items, count: items.length);
  }

  @override
  String getId(Comment item) => item.id;

  @override
  DateTime getCreatedAt(Comment item) => item.createdAt;

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}

final profileActivityFeedProvider = StateNotifierProvider.autoDispose
    .family<ProfileActivityFeedNotifier, PagedState<Comment>, String>(
  (ref, pubkey) => ProfileActivityFeedNotifier(ref, pubkey),
);

/// Inbox: kind-1111 comments that `p`-tag [pubkey] on the Zapstore relay.
class InboxFeedNotifier extends PagedSubscriptionNotifier<Comment> {
  InboxFeedNotifier(super.ref, this.pubkey);

  final String pubkey;
  ProviderSubscription<StorageState<Comment>>? _sub;

  @override
  int get pageSize => kActivityFeedPageSize;

  @override
  void startSubscription() {
    _sub?.close();
    _sub = ref.listen(
      query<Comment>(
        tags: {'#p': {pubkey}},
        until: DateTime.now(),
        limit: pageSize,
        where: (comment) =>
            comment.event.getTagSetValues('p').contains(pubkey),
        source: const LocalAndRemoteSource(
          relays: kDefaultRelay,
          stream: true,
        ),
        subscriptionPrefix: 'app-inbox-zapstore-relay-$pubkey',
      ),
      (_, next) => updateFirstPage(next),
      fireImmediately: true,
    );
  }

  @override
  Future<({List<Comment> items, int count})> fetchOlderPage(
    DateTime until,
  ) async {
    final storage = ref.read(storageNotifierProvider.notifier);
    final items = await storage.query(
      RequestFilter<Comment>(
        tags: {'#p': {pubkey}},
        until: until,
        limit: pageSize,
        where: (comment) =>
            comment.event.getTagSetValues('p').contains(pubkey),
      ).toRequest(),
      source: const LocalAndRemoteSource(relays: kDefaultRelay, stream: false),
      subscriptionPrefix: 'app-inbox-older-$pubkey',
    );
    return (items: items, count: items.length);
  }

  @override
  String getId(Comment item) => item.id;

  @override
  DateTime getCreatedAt(Comment item) => item.createdAt;

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}

final inboxFeedProvider = StateNotifierProvider.autoDispose
    .family<InboxFeedNotifier, PagedState<Comment>, String>(
  (ref, pubkey) => InboxFeedNotifier(ref, pubkey),
);
