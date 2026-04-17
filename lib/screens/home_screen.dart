import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';

import '../widgets/app_stack_container.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/shimmer.dart';
import '../widgets/latest_releases_container.dart';
import '../widgets/search_app_card.dart';
import '../utils/extensions.dart';
import '../main.dart';
import '../services/package_manager/package_manager.dart';
import '../services/updates_service.dart';

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
            // IMPORTANT: the builder ALWAYS returns ShaderMask so the widget
            // type at this tree position never changes.  Previously the builder
            // returned `child!` at t=0 and `ShaderMask(child)` at t>0 — on the
            // very first scroll pixel Flutter destroyed + recreated the
            // AnimatedSwitcher subtree (type mismatch), which detached the
            // ScrollPosition from scrollController, reset the offset to 0 and
            // cancelled the in-progress gesture (the "first scroll blocked" bug).
            // By always returning ShaderMask we only vary gradient colours, not
            // the widget structure, keeping the scroll gesture uninterrupted.
            //
            // Fade: t=0 at scroll=0 (top color = opaque black = no fade),
            //       t=1 at scroll=16px (top color = transparent = full fade).
            Expanded(
              child: ListenableBuilder(
                listenable: scrollController,
                builder: (context, child) {
                  final t = scrollController.hasClients
                      ? (scrollController.offset / 16.0).clamp(0.0, 1.0)
                      : 0.0;
                  return ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        // alpha=1 → no fade; alpha=0 → full fade
                        Colors.black.withValues(alpha: 1.0 - t),
                        Colors.black,
                      ],
                    ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, 28)),
                    blendMode: BlendMode.dstIn,
                    child: child,
                  );
                },
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
                        )
                      : _HomeContent(
                          key: const ValueKey('home'),
                          scrollController: scrollController,
                          initState: initState,
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
    required this.initState,
  });

  final ScrollController scrollController;
  final AsyncValue<void> initState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // Space below the top bar
          const SizedBox(height: 10),

          // ── Apps ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Apps',
                  linkText: 'See more',
                  onLinkTap: () => context.push('/updates'),
                ),
                LatestReleasesContainer(
                  showSkeleton: !(initState.hasValue || initState.hasError),
                  scrollController: scrollController,
                ),
              ],
            ),
          ),

          // ── Stacks ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Stacks',
                  linkText: 'See more',
                  onLinkTap: () => pushStacks(context),
                ),
                AppStackContainer(
                  showSkeleton: !(initState.hasValue || initState.hasError),
                ),
              ],
            ),
          ),

          // ── Scroll-test panel ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
            child: Builder(builder: (context) {
              final c = Theme.of(context).extension<AppColors>()!;
              return Container(
                height: 800,
                decoration: BoxDecoration(
                  color: c.white8,
                  borderRadius: BorderRadius.circular(AppRadius.r16),
                ),
              );
            }),
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
// When query is empty: blank placeholder (categories / suggestions to come).
// When query is submitted: shows search results.

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    super.key,
    required this.searchQuery,
    required this.platform,
    required this.scrollController,
  });

  final String searchQuery;
  final String platform;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isEmpty) {
      // Placeholder — will hold categories/suggestions in a future iteration.
      return const SizedBox.expand();
    }
    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchResultsSection(
            searchQuery: searchQuery,
            platform: platform,
            scrollController: scrollController,
          ),
        ],
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
    final c = Theme.of(context).extension<AppColors>()!;
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
                              color: c.gray33,
                              border: AppBorder.all(
                                color: c.white16,
                                width: AppStroke.thin,
                              ),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              size: 20,
                              color: c.white33,
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
    AppColors c,
    bool searching,
    bool isFirstSync,
    int updateCount,
  ) {
    final pillContent = Container(
      height: _barHeight,
      decoration: BoxDecoration(
        color: c.gray33,
        borderRadius: BorderRadius.circular(_barRadius),
        // Solid border when searching; gradient painter used when idle.
        border: searching
            ? AppBorder.all(color: c.white16, width: AppStroke.medium)
            : null,
      ),
      child: Row(
        children: [
          // ── Search icon ────────────────────────────────────────────────
          const SizedBox(width: 14),
          AppIcon(
            AppIcons.search,
            size: 16,
            outlineColor: c.white33,
            outlineThickness: 1.5,
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
                      style: AppTextStyles.med15.copyWith(color: c.white),
                      cursorColor: c.white,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Search',
                        hintStyle: AppTextStyles.med15.copyWith(color: c.white33),
                      ),
                    ),
                  )
                : Text(
                    'Search',
                    style: AppTextStyles.med15.copyWith(color: c.white33),
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
                    child: AppIcon(
                      AppIcons.cross,
                      size: 12,
                      outlineColor: c.white66,
                      outlineThickness: 1.6,
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
                        width: AppStroke.thin,
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
                                        style: AppTextStyles.med13.copyWith(
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
        strokeWidth: AppStroke.medium,
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
    final c = Theme.of(context).extension<AppColors>()!;
    final display = count > 99 ? '99+' : count.toString();
    const double h = 18;

    return Container(
      height: h,
      constraints: const BoxConstraints(minWidth: h),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        gradient: c.rouge,
        borderRadius: BorderRadius.circular(h / 2),
        border: AppBorder.all(
          color: Colors.black.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          display,
          style: AppTextStyles.med11.copyWith(
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
