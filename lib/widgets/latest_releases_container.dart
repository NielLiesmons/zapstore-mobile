import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/utils/app_query.dart';
import 'app_small_card.dart';
import 'common/shimmer.dart';

const _kPageSize = 8;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class LatestReleasesState {
  final List<Release> firstPage;
  final List<Release> olderPages;
  final Map<String, App> appsByIdentifier;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  const LatestReleasesState({
    required this.firstPage,
    required this.olderPages,
    required this.appsByIdentifier,
    required this.isLoadingMore,
    required this.hasMore,
    this.error,
  });

  factory LatestReleasesState.loading() => const LatestReleasesState(
    firstPage: [],
    olderPages: [],
    appsByIdentifier: {},
    isLoadingMore: false,
    hasMore: true,
  );

  bool get isLoading =>
      firstPage.isEmpty && olderPages.isEmpty && error == null;

  List<Release> get allReleases => [...firstPage, ...olderPages];

  LatestReleasesState copyWith({
    List<Release>? firstPage,
    List<Release>? olderPages,
    Map<String, App>? appsByIdentifier,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
  }) => LatestReleasesState(
    firstPage: firstPage ?? this.firstPage,
    olderPages: olderPages ?? this.olderPages,
    appsByIdentifier: appsByIdentifier ?? this.appsByIdentifier,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: error,
  );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class LatestReleasesNotifier extends StateNotifier<LatestReleasesState> {
  LatestReleasesNotifier(this.ref) : super(LatestReleasesState.loading()) {
    _subscribe();
  }

  final Ref ref;
  ProviderSubscription<StorageState<Release>>? _sub;

  void _subscribe() {
    _sub?.close();
    _sub = ref.listen(
      query<Release>(
        limit: _kPageSize,
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: true),
        subscriptionPrefix: 'app-latest-releases',
      ),
      (_, next) async {
        if (next is StorageData<Release>) {
          final liveIds = next.models.map((r) => r.id).toSet();
          final filteredOlder = state.olderPages
              .where((r) => !liveIds.contains(r.id))
              .toList();
          final unresolved = next.models
              .where(
                (r) => !state.appsByIdentifier.containsKey(r.appIdentifier),
              )
              .toList();
          final apps = await _resolveRelated(unresolved);
          if (mounted) {
            state = state.copyWith(
              firstPage: next.models,
              olderPages: filteredOlder,
              appsByIdentifier: {...state.appsByIdentifier, ...apps},
              error: null,
            );
          }
        } else if (next is StorageError<Release>) {
          state = state.copyWith(error: next.exception);
        }
      },
      fireImmediately: true,
    );
  }

  Future<void> loadMore() async {
    final all = state.allReleases;
    if (state.isLoadingMore || !state.hasMore || all.isEmpty) return;

    final oldest = all
        .map((r) => r.event.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b)
        .subtract(const Duration(milliseconds: 1));

    state = state.copyWith(isLoadingMore: true);

    try {
      final storage = ref.read(storageNotifierProvider.notifier);
      final releases = await storage.query(
        RequestFilter<Release>(until: oldest, limit: _kPageSize).toRequest(),
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: false),
        subscriptionPrefix: 'app-latest-releases-older',
      );

      if (releases.isEmpty) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      final apps = await _resolveRelated(releases);

      final existingIds = all.map((r) => r.id).toSet();
      final unique = releases
          .where((r) => !existingIds.contains(r.id))
          .toList();
      state = state.copyWith(
        olderPages: [...state.olderPages, ...unique],
        appsByIdentifier: {...state.appsByIdentifier, ...apps},
        isLoadingMore: false,
        hasMore: releases.length >= _kPageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Parallel fetch: assets by e-tag IDs + apps by i-tag identifiers.
  /// Returns resolved apps keyed by identifier.
  Future<Map<String, App>> _resolveRelated(List<Release> releases) async {
    if (releases.isEmpty) return const {};
    final storage = ref.read(storageNotifierProvider.notifier);

    final assetIds = releases
        .expand((r) => r.event.getTagSetValues('e'))
        .toSet();
    final appIds = releases
        .map((r) => r.appIdentifier)
        .where((id) => id.isNotEmpty)
        .toSet();

    await Future.wait([
      if (assetIds.isNotEmpty)
        storage.query(
          RequestFilter<SoftwareAsset>(
            ids: assetIds,
            tags: {
              '#f': {'android-arm64-v8a'},
            },
          ).toRequest(),
          source: const LocalAndRemoteSource(
            relays: 'AppCatalog',
            stream: false,
          ),
          subscriptionPrefix: 'app-latest-releases-assets',
        ),
      if (appIds.isNotEmpty)
        storage.query(
          RequestFilter<App>(tags: {'#d': appIds}).toRequest(),
          source: const LocalAndRemoteSource(
            relays: 'AppCatalog',
            stream: false,
          ),
          subscriptionPrefix: 'app-latest-releases-apps',
        ),
    ]);

    if (appIds.isEmpty) return const {};

    final apps = appIds
        .expand(
          (id) => storage.querySync(
            RequestFilter<App>(
              tags: {
                '#d': {id},
              },
              limit: 1,
            ).toRequest(),
          ),
        )
        .cast<App>()
        .toList();
    '${apps.map((a) => a.identifier).toList()}';
    await loadAuthors(storage, apps, 'app-latest-releases-authors');

    return {for (final app in apps) app.identifier: app};
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}

final latestReleasesProvider =
    StateNotifierProvider<LatestReleasesNotifier, LatestReleasesState>((ref) {
      return LatestReleasesNotifier(ref);
    });

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Apps per column in the horizontal scroll (matching webapp's 4-per-column).
const int _kAppsPerColumn = 4;

/// Height of each app row inside a column: 56px icon + 16px vertical padding.
const double _kAppRowHeight = 72;

/// Total height of the horizontal scroll area.
const double _kScrollHeight = _kAppRowHeight * _kAppsPerColumn;

class LatestReleasesContainer extends HookConsumerWidget {
  const LatestReleasesContainer({
    super.key,
    this.showSkeleton = false,
    required this.scrollController,
  });

  final bool showSkeleton;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = showSkeleton ? null : ref.watch(latestReleasesProvider);
    final releases = state?.allReleases ?? [];
    final appsById = state?.appsByIdentifier ?? const {};

    final seenAppIds = <String>{};
    final combinedApps = <App>[];
    for (final release in releases) {
      final app = appsById[release.appIdentifier];
      if (app != null && seenAppIds.add(app.identifier)) {
        combinedApps.add(app);
      }
    }

    // Infinite scroll: load more when the horizontal list nears the end
    final hScrollController = useScrollController();
    useEffect(() {
      if (state == null) return null;
      void onHScroll() {
        final s = ref.read(latestReleasesProvider);
        if (s.isLoadingMore || !s.hasMore) return;
        if (hScrollController.position.pixels >=
            hScrollController.position.maxScrollExtent - 400) {
          ref.read(latestReleasesProvider.notifier).loadMore();
        }
      }

      void checkInitialLoad() {
        if (!hScrollController.hasClients) return;
        final position = hScrollController.position;
        final s = ref.read(latestReleasesProvider);
        if (s.isLoadingMore || !s.hasMore) return;
        if (position.maxScrollExtent <= position.viewportDimension) {
          ref.read(latestReleasesProvider.notifier).loadMore();
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => checkInitialLoad());

      hScrollController.addListener(onHScroll);
      return () => hScrollController.removeListener(onHScroll);
    }, [hScrollController, state]);

    if (showSkeleton ||
        state == null ||
        (state.isLoading && combinedApps.isEmpty)) {
      return _buildSkeleton(context);
    }

    if (state.error != null && combinedApps.isEmpty) {
      return const SizedBox.shrink();
    }

    // Split apps into columns of _kAppsPerColumn
    final columns = <List<App>>[];
    for (var i = 0; i < combinedApps.length; i += _kAppsPerColumn) {
      columns.add(
        combinedApps.sublist(
          i,
          (i + _kAppsPerColumn).clamp(0, combinedApps.length),
        ),
      );
    }

    return SizedBox(
      height: _kScrollHeight,
      child: ListView.builder(
        controller: hScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 14, right: 4),
        itemCount: columns.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == columns.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            );
          }
          return _AppColumn(apps: columns[i]);
        },
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return SizedBox(
      height: _kScrollHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 14, right: 4),
        itemCount: 3,
        itemBuilder: (ctx, colIdx) => SizedBox(
          width: 290,
          child: Padding(
            padding: const EdgeInsets.only(right: 24),
              child: Column(
            children: List.generate(_kAppsPerColumn, (i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  // Must match AppSmallCard's crossAxisAlignment so the icon
                  // sits flush at y=0 — prevents extra visual gap at the top
                  // of the skeleton compared to the Stacks row.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer(width: 56, height: 56, radius: 14),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Shimmer(width: 120, height: 16),
                            const SizedBox(height: 6),
                            const Shimmer(width: 80, height: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single column of up to [_kAppsPerColumn] AppSmallCards in the horizontal scroll.
class _AppColumn extends StatelessWidget {
  const _AppColumn({required this.apps});

  final List<App> apps;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 290,
      child: Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          children: [
            for (final app in apps)
              Expanded(
                child: Padding(
                  // No top padding on first row → gap from SectionHeader = exactly
                  // the SectionHeader's 16px bottom padding.  Bottom padding creates
                  // uniform 8px breathing room between consecutive cards (same as
                  // symmetric(vertical:4) produced between cards, but without the
                  // extra 4px top that pushed the first card down).
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppSmallCard(app: app),
                ),
              ),
            // Fill remaining slots to keep even column height
            for (var i = apps.length; i < _kAppsPerColumn; i++)
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
