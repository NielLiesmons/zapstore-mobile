import 'package:flutter_test/flutter_test.dart';
import 'package:zapstore/providers/comment_activity_feed_provider.dart';
import 'package:zapstore/widgets/community/comment_activity_feed.dart';

void main() {
  group('activityFeedLikelyHasMore', () {
    test('true when hidden rows remain in loaded pool', () {
      expect(
        activityFeedLikelyHasMore(
          visibleLimit: 15,
          loadedCount: 60,
          relayHasMore: false,
        ),
        isTrue,
      );
    });

    test('true when relay still has older pages', () {
      expect(
        activityFeedLikelyHasMore(
          visibleLimit: 60,
          loadedCount: 60,
          relayHasMore: true,
        ),
        isTrue,
      );
    });

    test('false when everything is shown and relay exhausted', () {
      expect(
        activityFeedLikelyHasMore(
          visibleLimit: 60,
          loadedCount: 60,
          relayHasMore: false,
        ),
        isFalse,
      );
    });

    test('true while loading more from relay', () {
      expect(
        activityFeedLikelyHasMore(
          visibleLimit: 2500,
          loadedCount: 2500,
          relayHasMore: false,
          isLoadingMore: true,
        ),
        isTrue,
      );
    });
  });

  group('shouldFetchOlderActivityPage', () {
    test('triggers near end of loaded pool', () {
      expect(
        shouldFetchOlderActivityPage(
          visibleLimit: 58,
          loadedCount: 60,
          relayHasMore: true,
          isLoadingMore: false,
        ),
        isTrue,
      );
    });

    test('does not trigger when plenty of buffered rows remain', () {
      expect(
        shouldFetchOlderActivityPage(
          visibleLimit: 15,
          loadedCount: 60,
          relayHasMore: true,
          isLoadingMore: false,
        ),
        isFalse,
      );
    });

    test('does not trigger when relay exhausted', () {
      expect(
        shouldFetchOlderActivityPage(
          visibleLimit: 60,
          loadedCount: 60,
          relayHasMore: false,
          isLoadingMore: false,
        ),
        isFalse,
      );
    });
  });

  group('nextActivityVisibleLimit', () {
    test('steps by 15 up to max', () {
      expect(nextActivityVisibleLimit(15), 30);
      expect(nextActivityVisibleLimit(kActivityFeedMaxVisible - 5), kActivityFeedMaxVisible);
    });
  });

  group('activityFeedScrollNearBottom', () {
    test('true within threshold', () {
      expect(
        activityFeedScrollNearBottom(
          scrollOffset: 700,
          maxScrollExtent: 1000,
        ),
        isTrue,
      );
    });

    test('false when far from bottom', () {
      expect(
        activityFeedScrollNearBottom(
          scrollOffset: 100,
          maxScrollExtent: 1000,
        ),
        isFalse,
      );
    });

    test('true when content fits without scrolling', () {
      expect(
        activityFeedScrollNearBottom(
          scrollOffset: 0,
          maxScrollExtent: 0,
        ),
        isTrue,
      );
    });
  });
}
