import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/screens/inbox_screen.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/profile_name_widget.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';

import '../providers/comment_activity_feed_provider.dart';
import '../widgets/community/comment_activity_feed.dart';
import '../widgets/community/community_feed_switcher.dart';
import '../widgets/common/relay_loading_bar.dart';
import '../widgets/app_stack_container.dart';
import '../widgets/common/dropdown_menu.dart';
import '../widgets/common/label.dart';
import '../widgets/common/shimmer.dart';
import '../widgets/common/section_header.dart';
import '../widgets/forum/forum_feed_container.dart';
import '../widgets/forum/forum_post_card.dart';
import '../widgets/latest_releases_container.dart';
import '../widgets/search_app_card.dart';
import '../utils/extensions.dart';
import '../main.dart';
import '../services/package_manager/package_manager.dart';
import '../services/updates_service.dart';
import '../widgets/common/top_scroll_fader.dart';
import '../widgets/onboarding/welcome_panel.dart';

/// Horizontal padding shared by [_HomeTopBarState] chrome and pill alignment helpers.
const double _kHomeBarScreenPadding = 14;

/// Inset inside pill before [`LabIcons.search`] — matches [_HomeTopBarState._buildPill].
const double _kHomePillInsetBeforeSearchGlyph = 14;

/// Search glyph logical size ([_HomeTopBarState._buildPill] LabIcon extent).
const double _kHomePillSearchGlyphSize = 16;

/// Gap after search glyph before field — [_HomeTopBarState._buildPill] SizedBox(width: 8).
const double _kHomePillGapAfterSearchGlyph = 8;

/// Extra px added after [_kHomePillGapAfterSearchGlyph] for recent-row label vs pill TextField.
const double _kHomeRecentSearchExtraGapAfterGlyph = 1;

/// Recent-row glyph inset vs nominal pill left edge ([_kHomeAlignedSearchGlyphLeft]), optical px.
const double _kHomeRecentSearchGlyphLeadAdjust = 1;

/// Screen-x of pill search icon's left edge while searching ([_HomeTopBarState._buildPill]).
const double _kHomeAlignedSearchGlyphLeft =
    _kHomeBarScreenPadding + _kHomePillInsetBeforeSearchGlyph;

/// Dense recent-term row ([_HomeTopBarState._barHeight] is 42; list rows are tighter).
const double _kHomeRecentSearchRowHeight = 32;

/// Dummy inbox: thin tail under the main card (visual depth, not separate cards).
const double _kInboxTailMid = 11;

const double _kInboxTailBack = 9;

/// Opacity steps for the two tail segments under the main panel.
const double _kInboxTailOpacityFactor = 0.66;

/// Each tail tier narrows by this total amount vs the row above (centered).
const double _kInboxTailWidthStep = 24;

/// Placeholder height while the inbox preview waits out the loading shimmer delay.
const double _kInboxPreviewBlankHeight = 88;

class _InboxPreviewChevron extends StatelessWidget {
  const _InboxPreviewChevron();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: LabIcon(LabIcons.chevronRight, size: 14, color: c.white33),
    );
  }
}

const List<String> _kDummyRecentSearches = [
  'Damus',
  'Zapstore',
  'Primal',
  'Amethyst',
];

/// Home screen: search/discovery + fixed top bar.
class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSearching = useState(false);
    final searchController = useTextEditingController();
    final scrollController = useScrollController();
    final searchFocusNode = useFocusNode();
    final searchQuery = useState<String>('');

    final storageState = ref.watch(storageReadyProvider);
    final initState = ref.watch(appInitializationProvider);
    final platform = ref.read(packageManagerProvider.notifier).platform;

    // ── Search lifecycle ─────────────────────────────────────────────────────
    void activateSearch() {
      isSearching.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchFocusNode.requestFocus();
      });
    }

    void deactivateSearch() {
      isSearching.value = false;
      searchController.clear();
      searchQuery.value = '';
      searchFocusNode.unfocus();
    }

    final performSearch = useCallback((String query) {
      final trimmed = query.trim();
      if (navigateToContent(context, trimmed, fallbackLaunch: false)) {
        deactivateSearch();
        return;
      }
      if (trimmed.length < 3) {
        searchFocusNode.requestFocus();
        return;
      }
      searchQuery.value = trimmed;
    }, [searchFocusNode]);

    final trimmedQuery = searchQuery.value.trim();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        // Back while searching → exit search, not the app.
        if (!didPop && isSearching.value) deactivateSearch();
      },
      child: Scaffold(
        // No backgroundColor override → inherits theme scaffoldBackgroundColor.
        body: Column(
          children: [
            // ── Fixed top bar ────────────────────────────────────────────────
            _HomeTopBar(
              isSearching: isSearching.value,
              onActivate: activateSearch,
              onCancel: deactivateSearch,
              searchController: searchController,
              searchFocusNode: searchFocusNode,
              onSearch: performSearch,
            ),

            // ── Content: switches between home feed and search UI ─────────────
            Expanded(
              child: TopScrollFader(
                scrollController: scrollController,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topLeft,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  ),
                  child: isSearching.value
                      ? _SearchPanel(
                          key: const ValueKey('search'),
                          searchQuery: trimmedQuery,
                          platform: platform,
                          scrollController: scrollController,
                          searchController: searchController,
                          searchFocusNode: searchFocusNode,
                          onSearch: performSearch,
                        )
                      : _HomeContent(
                          key: const ValueKey('home'),
                          scrollController: scrollController,
                          showSkeleton:
                              !storageState.hasValue && !storageState.hasError,
                          isSyncing: storageState.hasValue &&
                              !initState.hasValue &&
                              !initState.hasError,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home content (apps + stacks feed)
// ─────────────────────────────────────────────────────────────────────────────

class _HomeContent extends ConsumerWidget {
  const _HomeContent({
    super.key,
    required this.scrollController,
    required this.showSkeleton,
    required this.isSyncing,
  });

  final ScrollController scrollController;

  /// True while storage is still initializing — show skeletons.
  final bool showSkeleton;

  /// True while storage is ready but app services are still loading
  /// (installed packages, deep links, auto sign-in). Show sync spinners.
  final bool isSyncing;


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedInPubkey = ref.watch(Signer.activePubkeyProvider);
    final hasProfile = signedInPubkey != null;

    return ShimmerTheme(
      child: SingleChildScrollView(
        controller: scrollController,
        // Ensures Flutter's gesture arena resolves to vertical scroll
        // immediately on first touch — especially important when the view
        // contains nested horizontal lists that would otherwise win the
        // first-pointer competition.
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasProfile) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InboxStackPreview(pubkey: signedInPubkey),
              ),
            ] else ...[
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: WelcomePanel(),
              ),
            ],

            // ── Apps ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Apps',
                    linkText: 'See more',
                    onLinkTap: () => context.push('/updates'),
                    bottomPadding: 18,
                    isLoading: isSyncing,
                  ),
                  LatestReleasesContainer(
                    showSkeleton: showSkeleton,
                    scrollController: scrollController,
                  ),
                ],
              ),
            ),

            // ── Stacks ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Stacks',
                    linkText: 'See more',
                    onLinkTap: () => pushStacks(context),
                    bottomPadding: 17,
                    isLoading: isSyncing,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 6),
                    child: AppStackContainer(
                      showSkeleton: showSkeleton,
                    ),
                  ),
                ],
              ),
            ),

            // ── Forum ──────────────────────────────────────────────────────
            _ForumSection(
              scrollController: scrollController,
              showSkeleton: showSkeleton,
              isSyncing: isSyncing,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Inbox preview: latest kind-1111 comment that `p`-tags you on the Zapstore relay only (same subscription as [InboxScreen]).
class _InboxStackPreview extends HookConsumerWidget {
  const _InboxStackPreview({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final commentsState = ref.watch(inboxRepliesProvider(pubkey));
    final comments = List<Comment>.from(commentsState.models)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = comments.firstOrNull;

    final loadingGate = useState(false);
    useEffect(() {
      final timer = Timer(const Duration(milliseconds: 100), () {
        loadingGate.value = true;
      });
      return timer.cancel;
    }, const []);

    final tailColor1 = c.gray66.withValues(
      alpha: c.gray66.a * _kInboxTailOpacityFactor,
    );
    final tailColor2 = c.gray66.withValues(
      alpha:
          c.gray66.a *
          _kInboxTailOpacityFactor *
          _kInboxTailOpacityFactor,
    );

    const mainPanelRadius = BorderRadius.all(Radius.circular(LabRadius.r16));
    const midTailBottomRadius = BorderRadius.vertical(
      bottom: Radius.circular(LabRadius.r16),
    );
    const backTailBottomRadius = BorderRadius.vertical(
      bottom: Radius.circular(LabRadius.r16),
    );

    final mainPanel = () {
      if (!loadingGate.value) {
        return SizedBox(
          height: _kInboxPreviewBlankHeight,
          child: ClipRRect(
            borderRadius: mainPanelRadius,
            child: ColoredBox(color: c.gray66),
          ),
        );
      }

      if (commentsState is StorageError) {
        return ClipRRect(
          borderRadius: mainPanelRadius,
          child: Material(
            color: c.gray66,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.gray33,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: LabIcon(LabIcons.inbox, size: 18, color: c.white33),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Could not load inbox. Tap to retry in full view.',
                      style: LabTextStyles.reg13.copyWith(color: c.white66),
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _InboxPreviewChevron(),
                ],
              ),
            ),
          ),
        );
      }

      if (commentsState is StorageLoading && comments.isEmpty) {
        return ClipRRect(
          borderRadius: mainPanelRadius,
          child: Material(
            color: c.gray66,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Shimmer(width: 36, height: 36, isCircle: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Shimmer(
                          width: double.infinity,
                          height: 14,
                          radius: LabRadius.r8,
                        ),
                        SizedBox(height: 8),
                        Shimmer(
                          width: 160,
                          height: 14,
                          radius: LabRadius.r8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _InboxPreviewChevron(),
                ],
              ),
            ),
          ),
        );
      }

      if (latest == null) {
        return ClipRRect(
          borderRadius: mainPanelRadius,
          child: Material(
            color: c.gray66,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.gray33,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: LabIcon(LabIcons.inbox, size: 18, color: c.white33),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No comments yet',
                      style: LabTextStyles.reg13.copyWith(color: c.white66),
                    ),
                  ),
                  const _InboxPreviewChevron(),
                ],
              ),
            ),
          ),
        );
      }

      final authorPk = latest.event.pubkey;
      final authorState = ref.watch(
        query<Profile>(
          authors: {authorPk},
          source: const LocalAndRemoteSource(
            relays: {'social', 'vertex'},
            stream: false,
            cachedFor: Duration(hours: 2),
          ),
          subscriptionPrefix: 'inbox-preview-a-${authorPk.hashCode}',
        ),
      );
      final author = authorState.models.firstOrNull;
      final authorLoading =
          authorState is StorageLoading && author == null;
      final nameColor = profileTextColor(hexToColor(authorPk));
      final body = latest.content.trim();

      return ClipRRect(
        borderRadius: mainPanelRadius,
        child: Material(
          color: c.gray66,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ProfilePic(
                      pubkey: authorPk,
                      profile: author,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: LabTextStyles.reg13,
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: ProfileNameWidget(
                                  pubkey: authorPk,
                                  profile: author,
                                  isLoading: authorLoading,
                                  style: LabTextStyles.semibold13.copyWith(
                                    color: nameColor,
                                  ),
                                  skeletonWidth: 72,
                                ),
                              ),
                              TextSpan(
                                text: ' commented',
                                style: LabTextStyles.reg13.copyWith(
                                  color: c.white33,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: LabTextStyles.reg13.copyWith(
                              color: c.white66,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _InboxPreviewChevron(),
                ],
              ),
            ),
          ),
        ),
      );
    }();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GestureDetector(
        onTap: () => context.push('/inbox'),
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final midW = math.max(0.0, w - _kInboxTailWidthStep);
            final backW = math.max(0.0, w - 2 * _kInboxTailWidthStep);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                mainPanel,
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: midW,
                    height: _kInboxTailMid,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tailColor1,
                        borderRadius: midTailBottomRadius,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: backW,
                    height: _kInboxTailBack,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tailColor2,
                        borderRadius: backTailBottomRadius,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Forum section — "Forum" header + labels filter row + sort dropdown
// ─────────────────────────────────────────────────────────────────────────────

enum _SortOrder { latest, mostZapped }

const _kForumCategories = [
  'General',
  'Dev Support',
  'User Support',
  'Feature Request',
  'Ideas',
  'Bugs',
  'Announcements',
  'News',
  'Showcase',
  'Off-Topic',
];

class _ForumSection extends HookConsumerWidget {
  const _ForumSection({
    required this.scrollController,
    required this.showSkeleton,
    required this.isSyncing,
  });

  final ScrollController scrollController;

  /// True while storage is not yet ready — show shimmer, do not mount ForumFeedContainer.
  final bool showSkeleton;
  final bool isSyncing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = useState<String?>(null);
    final sortOrder = useState(_SortOrder.latest);
    final feedMode = useState(CommunityFeedMode.forum);
    final visited = useState(<CommunityFeedMode>{CommunityFeedMode.forum});

    void selectMode(CommunityFeedMode mode) {
      feedMode.value = mode;
      visited.value = {...visited.value, mode};
    }

    final activitySubscribed = visited.value.contains(CommunityFeedMode.activity);

    final headerLoading = feedMode.value == CommunityFeedMode.forum
        ? isSyncing
        : activitySubscribed &&
            ref.watch(communityActivityCommentsProvider) is StorageLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommunityFeedHeader(
          mode: feedMode.value,
          onModeChanged: selectMode,
          isLoading: headerLoading,
        ),

        if (feedMode.value == CommunityFeedMode.forum)
          _ForumFilterRow(
            selectedCategory: selectedCategory.value,
            sortOrder: sortOrder.value,
            onCategoryTap: (cat) {
              selectedCategory.value =
                  selectedCategory.value == cat ? null : cat;
            },
            onSortOrderChange: (order) => sortOrder.value = order,
          ),

        if (feedMode.value == CommunityFeedMode.activity && activitySubscribed)
          _CommunityActivitySyncBar(),

        if (visited.value.contains(CommunityFeedMode.forum))
          Offstage(
            offstage: feedMode.value != CommunityFeedMode.forum,
            child: _KeepAliveFeed(
              child: showSkeleton
                  ? ShimmerTheme(
                      child: Column(
                        children: List.generate(
                          5,
                          (_) => const ForumPostCardSkeleton(),
                        ),
                      ),
                    )
                  : ForumFeedContainer(scrollController: scrollController),
            ),
          ),

        if (visited.value.contains(CommunityFeedMode.activity))
          Offstage(
            offstage: feedMode.value != CommunityFeedMode.activity,
            child: _KeepAliveFeed(
              child: _CommunityActivityFeedPane(
                scrollController: scrollController,
              ),
            ),
          ),
      ],
    );
  }
}

class _KeepAliveFeed extends StatefulWidget {
  const _KeepAliveFeed({required this.child});

  final Widget child;

  @override
  State<_KeepAliveFeed> createState() => _KeepAliveFeedState();
}

class _KeepAliveFeedState extends State<_KeepAliveFeed>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _CommunityActivityFeedPane extends ConsumerWidget {
  const _CommunityActivityFeedPane({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityState = ref.watch(communityActivityCommentsProvider);
    final activityVisible = ref.watch(communityActivityVisibleLimitProvider);

    return CommentActivityFeed(
      scrollController: scrollController,
      commentsState: activityState,
      visibleLimit: activityVisible,
      onLoadMore: () => ref
          .read(communityActivityVisibleLimitProvider.notifier)
          .update(
            (v) => v + kActivityFeedVisibleStep > kActivityFeedMaxVisible
                ? kActivityFeedMaxVisible
                : v + kActivityFeedVisibleStep,
          ),
    );
  }
}

class _CommunityActivitySyncBar extends ConsumerWidget {
  const _CommunityActivitySyncBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityState = ref.watch(communityActivityCommentsProvider);
    final syncing =
        activityState is StorageLoading && activityState.models.isNotEmpty;
    if (!syncing) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RelayLoadingBar(loading: syncing),
    );
  }
}

// ── Filter row: scrollable labels + right-anchored sort dropdown ─────────────
//
// Manages its own overlay state so _ForumSection stays clean.

class _ForumFilterRow extends HookWidget {
  const _ForumFilterRow({
    required this.selectedCategory,
    required this.sortOrder,
    required this.onCategoryTap,
    required this.onSortOrderChange,
  });

  final String? selectedCategory;
  final _SortOrder sortOrder;
  final void Function(String) onCategoryTap;
  final void Function(_SortOrder) onSortOrderChange;

  @override
  Widget build(BuildContext context) {
    final overlayController = useMemoized(() => OverlayPortalController());
    final layerLink = useMemoized(() => LayerLink());
    final isOpen = useState(false);

    // Use our own isOpen state (not overlayController.isShowing) so the toggle
    // is reliable even when onTapOutside fires just before the button onTap.
    void toggle() {
      if (isOpen.value) {
        overlayController.hide();
        isOpen.value = false;
      } else {
        overlayController.show();
        isOpen.value = true;
      }
    }

    void dismiss() {
      overlayController.hide();
      isOpen.value = false;
    }

    // groupId ensures the button's own tap is NOT treated as "outside" the
    // dropdown region — prevents the dismiss→reopen race on button press.
    const groupId = 'forum-sort-dropdown';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Horizontally scrollable label chips with a right-edge fade
        Expanded(
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                0.0,
                bounds.width > 17 ? (bounds.width - 17) / bounds.width : 0.0,
                1.0,
              ],
              colors: const [Colors.white, Colors.white, Colors.transparent],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 0, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _kForumCategories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: LabLabel(
                      cat,
                      size: LabLabelSize.defaultSize,
                      isSelected: selectedCategory == cat,
                      onTap: () => onCategoryTap(cat),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Sort button + dropdown — pinned to the right outside the scroll
        Padding(
          padding: const EdgeInsets.only(right: 14, bottom: 0),
          child: OverlayPortal(
            controller: overlayController,
            overlayChildBuilder: (ctx) => CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 4),
              child: Align(
                alignment: Alignment.topRight,
                child: TapRegion(
                  groupId: groupId,
                  onTapOutside: (_) => dismiss(),
                  child: LabDropdownMenu(
                    constraints: const BoxConstraints(minWidth: 160),
                    children: [
                      LabDropdownItem(
                        isFirst: true,
                        isActive: sortOrder == _SortOrder.latest,
                        onTap: () {
                          onSortOrderChange(_SortOrder.latest);
                          dismiss();
                        },
                        child: const Text('Latest'),
                      ),
                      LabDropdownItem(
                        isActive: sortOrder == _SortOrder.mostZapped,
                        onTap: () {
                          onSortOrderChange(_SortOrder.mostZapped);
                          dismiss();
                        },
                        child: const Text('Most Zapped'),
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
                child: _SortButton(
                  label: sortOrder == _SortOrder.latest ? 'Latest' : 'Most Zapped',
                  isOpen: isOpen.value,
                  onTap: toggle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sort button: secondarySmall (34px pill) with label + rotating chevron ────

class _SortButton extends StatefulWidget {
  const _SortButton({
    required this.label,
    required this.isOpen,
    required this.onTap,
  });

  final String label;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  State<_SortButton> createState() => _SortButtonState();
}

class _SortButtonState extends State<_SortButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        // 34px matches LabButton.secondarySmall / tab standardized height
        height: 34,
        padding: const EdgeInsets.only(left: 16, right: 12),
        decoration: BoxDecoration(
          color: _pressed ? c.gray66.withValues(alpha: 0.75) : c.gray66,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.label,
              style: LabTextStyles.med13.copyWith(color: c.white),
            ),
            const SizedBox(width: 6),
            Transform.rotate(
              angle: widget.isOpen ? 3.14159 : 0.0,
              child: LabIcon(LabIcons.chevronDown, size: 6, color: c.white33),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search panel (shown while isSearching = true)
// ─────────────────────────────────────────────────────────────────────────────
//
// Empty active query + empty draft: recent dummy rows + Scan FAB.
// Submitted query: search results (+ Scan FAB).

class _SearchPanel extends HookWidget {
  const _SearchPanel({
    super.key,
    required this.searchQuery,
    required this.platform,
    required this.scrollController,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearch,
  });

  final String searchQuery;
  final String platform;
  // Kept for API compatibility but not attached to any ScrollView here —
  // the panel owns its own controller to avoid a double-attach crash when
  // AnimatedSwitcher keeps both panels alive during the 200ms transition.
  final ScrollController scrollController;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final void Function(String query) onSearch;

  @override
  Widget build(BuildContext context) {
    final panelScrollController = useScrollController();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final body = searchQuery.isEmpty
        ? ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, draft, _) {
              if (draft.text.trim().isNotEmpty) {
                return const SizedBox.expand();
              }

              return SingleChildScrollView(
                controller: panelScrollController,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset + 88),
                  child: Transform.translate(
                    offset: const Offset(0, -2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final term in _kDummyRecentSearches)
                          _HomeRecentSearchRow(
                            term: term,
                            onSelected: () {
                              searchController.text = term;
                              searchFocusNode.requestFocus();
                              onSearch(term);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        : SingleChildScrollView(
            controller: panelScrollController,
            padding: EdgeInsets.only(bottom: bottomInset + 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchResultsSection(
                  searchQuery: searchQuery,
                  platform: platform,
                  scrollController: panelScrollController,
                ),
              ],
            ),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: body),
        Positioned(
          right: 14,
          bottom: bottomInset + 14,
          child: const _HomeSearchScanFab(),
        ),
      ],
    );
  }
}

class _HomeRecentSearchRow extends StatelessWidget {
  const _HomeRecentSearchRow({
    required this.term,
    required this.onSelected,
  });

  final String term;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        child: SizedBox(
          height: _kHomeRecentSearchRowHeight,
          child: Padding(
            padding: const EdgeInsets.only(
              left:
                  _kHomeAlignedSearchGlyphLeft +
                      _kHomeRecentSearchGlyphLeadAdjust,
              right: 14,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                LabIcon(
                  LabIcons.search,
                  size: _kHomePillSearchGlyphSize,
                  color: c.white16,
                ),
                const SizedBox(
                  width:
                      _kHomePillGapAfterSearchGlyph +
                      _kHomeRecentSearchExtraGapAfterGlyph,
                ),
                Expanded(
                  child: Text(
                    term,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LabTextStyles.reg15.copyWith(color: c.white33),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeSearchScanFab extends StatelessWidget {
  const _HomeSearchScanFab();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () {},
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: c.gray33,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LabIcon(LabIcons.profileQR, size: 26, color: c.white33),
                  const SizedBox(width: 10),
                  Text(
                    'Scan',
                    style: LabTextStyles.med15.copyWith(color: c.white66),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeTopBar
// ─────────────────────────────────────────────────────────────────────────────
//
// Idle state:
//   [ProfilePic 38px] [16px] [══ pill ══════════════════════════════════════]
//                            [ 🔍 Search...            | (Updates ●) ]
//
// Search state (animated):
//   [ProfilePic shrinks out] [══ expanded pill (TextField active) ══] [Cancel]
//
// Pill border: gradient left-to-right (white16 → blurple@4%) when idle.
//              solid white16 when searching.

class _HomeTopBar extends ConsumerStatefulWidget {
  const _HomeTopBar({
    required this.isSearching,
    required this.onActivate,
    required this.onCancel,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearch,
  });

  final bool isSearching;
  final VoidCallback onActivate;
  final VoidCallback onCancel;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final void Function(String) onSearch;

  @override
  ConsumerState<_HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends ConsumerState<_HomeTopBar> {
  bool _profilePressed = false;
  bool _updatesPressed = false;

  static const _kDur = Duration(milliseconds: 240);
  static const _kCurve = Curves.easeInOut;

  // ── Dimensions ──────────────────────────────────────────────────────────
  // Profile pic and outer pill share the same 42px height.
  // Outer pill height 42px with 5px all-sides padding around the 32px
  // Updates button: 42 − 2×5 = 32px ✓
  static const double _picSize = 42;
  static const double _barHeight = 42;
  static const double _barRadius = _barHeight / 2;
  static const double _updatesHeight = 30;
  static const double _updatesRadius = _updatesHeight / 2;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final topPad = MediaQuery.paddingOf(context).top;
    final searching = widget.isSearching;

    final pubkey = ref.watch(Signer.activePubkeyProvider);
    final profile = ref.watch(
      Signer.activeProfileProvider(
        const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          cachedFor: Duration(hours: 2),
        ),
      ),
    );
    final updateCount = ref.watch(updateCountProvider);
    final poller = ref.watch(updatePollerProvider);
    final categorized = ref.watch(categorizedUpdatesProvider);
    final isFirstSync =
        poller.lastCheckTime == null &&
        (categorized.showSkeleton || poller.isChecking);

    return Container(
      padding: EdgeInsets.fromLTRB(14, topPad + 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Profile pic — shrinks + fades out while searching ────────────
          AnimatedSize(
            duration: _kDur,
            curve: _kCurve,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: searching ? 0.0 : _picSize,
              child: AnimatedOpacity(
                opacity: searching ? 0.0 : 1.0,
                duration: _kDur,
                curve: _kCurve,
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _profilePressed = true),
                  onTapUp: (_) {
                    setState(() => _profilePressed = false);
                    context.push('/profile');
                  },
                  onTapCancel: () => setState(() => _profilePressed = false),
                  child: AnimatedScale(
                    scale: _profilePressed ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    child: pubkey != null
                        ? ProfilePic(
                            profile: profile,
                            pubkey: pubkey,
                            size: _picSize,
                          )
                        : Container(
                            width: _picSize,
                            height: _picSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.white8,
                              border: LabBorder.all(
                                color: c.white16,
                                width: LabStroke.thin,
                              ),
                            ),
                            child: Center(
                              child: LabIcon(
                                LabIcons.profile,
                                size: _picSize * 0.56,
                                color: c.white33,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),

          // ── Gap — also shrinks to 0 while searching ──────────────────────
          AnimatedSize(
            duration: _kDur,
            curve: _kCurve,
            child: SizedBox(width: searching ? 0.0 : 14.0),
          ),

          // ── Pill ─────────────────────────────────────────────────────────
          // Expanded so it fills whatever width the profile-pic + cancel leave.
          // Border: gradient when idle, solid white16 when searching.
          Expanded(
            child: GestureDetector(
              // Tapping anywhere on the pill (outside Updates) activates search.
              onTap: searching ? null : widget.onActivate,
              child: _buildPill(c, searching, isFirstSync, updateCount),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildPill(
    LabColors c,
    bool searching,
    bool isFirstSync,
    int updateCount,
  ) {
    final pillContent = Container(
      height: _barHeight,
      decoration: BoxDecoration(
        color: searching ? c.gray33 : null,
        gradient: searching
            ? null
            : LinearGradient(
                colors: [c.gray33, c.gray33.withValues(alpha: 0)],
              ),
        borderRadius: BorderRadius.circular(_barRadius),
        // Solid border when searching; gradient painter used when idle.
        border: searching
            ? LabBorder.all(color: c.white16, width: LabStroke.medium)
            : null,
      ),
      child: Row(
        children: [
          // ── Search icon ────────────────────────────────────────────────
          const SizedBox(width: 14),
          LabIcon(
            LabIcons.search,
            size: 16,
            color: c.white33,
          ),
          const SizedBox(width: 8),

          // ── Search text / TextField ────────────────────────────────────
          Expanded(
            child: searching
                ? Theme(
                    // Kill every possible Material border the global
                    // inputDecorationTheme could inject into this field.
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: const InputDecorationTheme(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    child: TextField(
                      controller: widget.searchController,
                      focusNode: widget.searchFocusNode,
                      onSubmitted: widget.onSearch,
                      style: LabTextStyles.med15.copyWith(color: c.white),
                      cursorColor: c.white,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Search',
                        hintStyle: LabTextStyles.med15.copyWith(color: c.white33),
                      ),
                    ),
                  )
                : Text(
                    'Search',
                    style: LabTextStyles.med15.copyWith(color: c.white33),
                  ),
          ),

          // ── Round X button (search mode only) — clears text + exits search ──
          if (searching) ...[
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.searchController.clear();
                  widget.onCancel();
                },
                child: Container(
                  width: _updatesHeight,
                  height: _updatesHeight,
                  decoration: BoxDecoration(
                    color: c.white8,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: LabIcon(
                      LabIcons.cross,
                      size: 12,
                      color: c.white66,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // ── Updates pill + divider (idle only, animates away) ─────────
          AnimatedSize(
            duration: _kDur,
            curve: _kCurve,
            clipBehavior: Clip.hardEdge,
            child: searching
                ? const SizedBox.shrink()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: LabStroke.thin,
                        height: 22,
                        color: c.white16,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) =>
                              setState(() => _updatesPressed = true),
                          onTapUp: (_) {
                            setState(() => _updatesPressed = false);
                            context.push('/updates');
                          },
                          onTapCancel: () =>
                              setState(() => _updatesPressed = false),
                          child: AnimatedScale(
                            scale: _updatesPressed ? 0.93 : 1.0,
                            duration: const Duration(milliseconds: 120),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  height: _updatesHeight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: c.blurple,
                                    borderRadius: BorderRadius.circular(
                                      _updatesRadius,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Updates',
                                        style: LabTextStyles.med13.copyWith(
                                          color: c.whiteEnforced,
                                        ),
                                      ),
                                      if (isFirstSync) ...[
                                        const SizedBox(width: 5),
                                        SizedBox(
                                          width: 9,
                                          height: 9,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: c.white66,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (updateCount > 0)
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: _RougeCountBadge(count: updateCount),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );

    // Gradient border is drawn as a foreground CustomPaint in idle mode.
    if (searching) return pillContent;

    return CustomPaint(
      foregroundPainter: _GradientBorderPainter(
        leftColor: c.white16,
        rightColor: c.blurpleColor.withValues(alpha: 0.04),
        radius: _barRadius,
        strokeWidth: LabStroke.medium,
      ),
      child: pillContent,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RougeCountBadge
// ─────────────────────────────────────────────────────────────────────────────
//
// • Single digit  → perfect circle (18×18)
// • Multiple digits → pill that hugs the text (height 18, min-width 18)
// • Positioned 6px above and to the right of the Updates button.

class _RougeCountBadge extends StatelessWidget {
  const _RougeCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final display = count > 99 ? '99+' : count.toString();
    const double h = 18;

    return Container(
      height: h,
      constraints: const BoxConstraints(minWidth: h),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        gradient: c.rouge,
        borderRadius: BorderRadius.circular(h / 2),
        border: LabBorder.all(
          color: Colors.black.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          display,
          style: LabTextStyles.med11.copyWith(
            color: c.whiteEnforced,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GradientBorderPainter
// ─────────────────────────────────────────────────────────────────────────────
//
// Draws a rounded-rect stroke with a left-to-right LinearGradient as the
// foregroundPainter of the pill, so the border sits on top of the background
// without consuming any inner height.

class _GradientBorderPainter extends CustomPainter {
  const _GradientBorderPainter({
    required this.leftColor,
    required this.rightColor,
    required this.radius,
    required this.strokeWidth,
  });

  final Color leftColor;
  final Color rightColor;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius - inset),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        colors: [leftColor, rightColor],
      ).createShader(Offset.zero & size);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter old) =>
      old.leftColor != leftColor ||
      old.rightColor != rightColor ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

// ─────────────────────────────────────────────────────────────────────────────
// Search results section
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultsSection extends HookConsumerWidget {
  const _SearchResultsSection({
    required this.searchQuery,
    required this.platform,
    required this.scrollController,
  });

  final String searchQuery;
  final String platform;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchResultsState = ref.watch(
      query<App>(
        search: searchQuery,
        limit: 10,
        tags: {
          '#f': {platform},
        },
        source: const RemoteSource(relays: 'AppCatalog', stream: false),
        subscriptionPrefix: 'app-search-results',
      ),
    );

    useEffect(() {
      if (searchResultsState is StorageData && scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOut,
          );
        });
      }
      return null;
    }, [searchResultsState]);

    final results = searchResultsState is StorageData
        ? (searchResultsState as StorageData<App>).models
        : <App>[];
    final isSearching = searchResultsState is StorageLoading;
    final error = searchResultsState is StorageError
        ? (searchResultsState as StorageError<App>).exception.toString()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSearching)
          Column(
            children: List.generate(
              2,
              (_) => const SearchAppCard(isLoading: true),
            ),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text('Search Error', style: context.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: context.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No results found',
                    style: context.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No apps found for "$searchQuery"',
                    style: context.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: results.map((app) => SearchAppCard(app: app)).toList(),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
