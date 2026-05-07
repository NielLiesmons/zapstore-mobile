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
import '../widgets/common/dropdown_menu.dart';
import '../widgets/common/label.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/shimmer.dart';
import '../widgets/forum/forum_feed_container.dart';
import '../widgets/forum/forum_post_card.dart';
import '../widgets/latest_releases_container.dart';
import '../widgets/search_app_card.dart';
import '../utils/extensions.dart';
import '../main.dart';
import '../services/package_manager/package_manager.dart';
import '../services/updates_service.dart';
import '../widgets/common/top_scroll_fader.dart';

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
          const SizedBox(height: 14),

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
                  bottomPadding: 18,
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
            padding: const EdgeInsets.only(bottom: 19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Stacks',
                  linkText: 'See more',
                  onLinkTap: () => pushStacks(context),
                  bottomPadding: 17,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 6),
                  child: AppStackContainer(
                    showSkeleton: !(initState.hasValue || initState.hasError),
                  ),
                ),
              ],
            ),
          ),

          // ── Forum ────────────────────────────────────────────────────────
          _ForumSection(
            scrollController: scrollController,
            initDone: initState.hasValue || initState.hasError,
          ),
          const SizedBox(height: 32),
        ],
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
    required this.initDone,
  });

  final ScrollController scrollController;
  final bool initDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = useState<String?>(null);
    final sortOrder = useState(_SortOrder.latest);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Forum',
          linkText: 'Our Community',
          onLinkTap: () => context.push('/community'),
          bottomPadding: 17,
        ),

        _ForumFilterRow(
          selectedCategory: selectedCategory.value,
          sortOrder: sortOrder.value,
          onCategoryTap: (cat) {
            selectedCategory.value =
                selectedCategory.value == cat ? null : cat;
          },
          onSortOrderChange: (order) => sortOrder.value = order,
        ),

        if (initDone)
          ForumFeedContainer(scrollController: scrollController)
        else
          ShimmerTheme(
            child: Column(
              children: List.generate(5, (_) => const ForumPostCardSkeleton()),
            ),
          ),
      ],
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
// When query is empty: blank placeholder (categories / suggestions to come).
// When query is submitted: shows search results.

class _SearchPanel extends HookWidget {
  const _SearchPanel({
    super.key,
    required this.searchQuery,
    required this.platform,
    required this.scrollController,
  });

  final String searchQuery;
  final String platform;
  // Kept for API compatibility but not attached to any ScrollView here —
  // the panel owns its own controller to avoid a double-attach crash when
  // AnimatedSwitcher keeps both panels alive during the 200ms transition.
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final panelScrollController = useScrollController();

    if (searchQuery.isEmpty) {
      // Placeholder — will hold categories/suggestions in a future iteration.
      return const SizedBox.expand();
    }
    return SingleChildScrollView(
      controller: panelScrollController,
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
        color: c.gray33,
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
