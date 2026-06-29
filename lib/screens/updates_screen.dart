import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/services/updates_service.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/batch_progress_banner.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'package:zapstore/widgets/common/top_scroll_fader.dart';
import 'package:zapstore/widgets/common/selector.dart';
import 'package:zapstore/widgets/community/community_feed_switcher.dart'
    show kCommunitySelectorHeight;
import 'package:zapstore/widgets/update_app_row.dart';

class UpdatesScreen extends HookConsumerWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorized = ref.watch(categorizedUpdatesProvider);
    final scrollController = useScrollController();
    final tabIndex = useState(0);
    final topPad = MediaQuery.paddingOf(context).top;
    // 8px below safe area + 42px selector row + 10px bottom gap
    const headerContentHeight = 60.0;
    final headerHeight = topPad + headerContentHeight;
    final contentTopPad = headerHeight + 10.0;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 24.0;

    final inner = categorized.showSkeleton
        ? _LoadingSkeleton(
            controller: scrollController,
            contentTopPad: contentTopPad,
            bottomPad: bottomPad,
          )
        : _UpdatesList(
            categorized: categorized,
            controller: scrollController,
            contentTopPad: contentTopPad,
            bottomPad: bottomPad,
            tabIndex: tabIndex.value,
          );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TopScrollFader(
              scrollController: scrollController,
              fadeStart: headerHeight,
              child: inner,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _UpdatesHeader(
              tabIndex: tabIndex.value,
              onTabChanged: (index) => tabIndex.value = index,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdatesHeader extends ConsumerWidget {
  const _UpdatesHeader({
    required this.tabIndex,
    required this.onTabChanged,
  });

  final int tabIndex;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final topPad = MediaQuery.paddingOf(context).top;
    final categorized = ref.watch(categorizedUpdatesProvider);
    final newCount = categorized.automaticUpdates.length +
        categorized.manualUpdates.length;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: c.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: topPad + 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Updates',
                        style: LabTextStyles.semibold23.copyWith(color: c.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 168,
                      child: Selector(
                        initialIndex: tabIndex,
                        white8Selection: true,
                        containerRadius: kCommunitySelectorHeight / 2,
                        tabs: [
                          SelectorTab(
                            label: 'New',
                            count: newCount == 0 ? null : newCount,
                          ),
                          SelectorTab(
                            label: 'Installed',
                            count: categorized.upToDateApps.isEmpty
                                ? null
                                : categorized.upToDateApps.length,
                          ),
                        ],
                        onChanged: onTabChanged,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({
    required this.controller,
    required this.contentTopPad,
    required this.bottomPad,
  });

  final ScrollController controller;
  final double contentTopPad;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return ShimmerTheme(
      child: ListView(
        controller: controller,
        padding: EdgeInsets.only(top: contentTopPad, bottom: bottomPad),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: c.white33,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Checking for updates...',
                  style: LabTextStyles.reg13.copyWith(color: c.white33),
                ),
              ],
            ),
          ),
          const UpdateAppRowSkeleton(),
          const UpdateAppRowDivider(),
          const UpdateAppRowSkeleton(),
          const UpdateAppRowDivider(),
          const UpdateAppRowSkeleton(),
        ],
      ),
    );
  }
}

class _UpdatesList extends HookConsumerWidget {
  const _UpdatesList({
    required this.categorized,
    required this.controller,
    required this.contentTopPad,
    required this.bottomPad,
    required this.tabIndex,
  });

  final CategorizedUpdates categorized;
  final ScrollController controller;
  final double contentTopPad;
  final double bottomPad;
  final int tabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final automaticUpdates = categorized.automaticUpdates;
    final manualUpdates = categorized.manualUpdates;
    final upToDateApps = categorized.upToDateApps;
    final uncatalogedApps = categorized.uncatalogedApps;

    final operations = ref.watch(
      packageManagerProvider.select((s) => s.operations),
    );
    final activeAppIds = operations.entries
        .where((entry) => entry.value.isActive)
        .map((entry) => entry.key)
        .toSet();

    final updateAppIds = {
      ...automaticUpdates.map((a) => a.identifier),
      ...manualUpdates.map((a) => a.identifier),
    };

    final List<App> installingApps;
    if (activeAppIds.isEmpty) {
      installingApps = const [];
    } else {
      final installingAppsState = ref.watch(
        query<App>(
          tags: {'#d': activeAppIds},
          and: (app) => {app.latestRelease.query()},
          source: const LocalAndRemoteSource(relays: 'AppCatalog'),
          subscriptionPrefix: 'app-installing-apps',
        ),
      );
      installingApps = installingAppsState.models
          .where(
            (app) =>
                activeAppIds.contains(app.identifier) &&
                !updateAppIds.contains(app.identifier),
          )
          .toList();
    }

    if (automaticUpdates.isEmpty &&
        manualUpdates.isEmpty &&
        installingApps.isEmpty &&
        upToDateApps.isEmpty &&
        uncatalogedApps.isEmpty) {
      final c = Theme.of(context).extension<LabColors>()!;
      return CustomScrollView(
        controller: controller,
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: contentTopPad)),
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      'No apps installed yet',
                      style: LabTextStyles.semibold17.copyWith(color: c.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Install some apps to get started!',
                      style: LabTextStyles.reg15.copyWith(color: c.white33),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final onNewTab = tabIndex == 0;
    final hasNewContent = installingApps.isNotEmpty ||
        automaticUpdates.isNotEmpty ||
        manualUpdates.isNotEmpty;

    return RefreshIndicator(
      color: Colors.transparent,
      backgroundColor: Colors.transparent,
      elevation: 0,
      strokeWidth: 0,
      onRefresh: () => ref.read(updatePollerProvider.notifier).checkNow(),
      child: CustomScrollView(
        controller: controller,
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: contentTopPad)),
          if (onNewTab) ...[
            if (!hasNewContent)
              SliverToBoxAdapter(
                child: _UpdatesTabEmptyState(onNewReleasesTab: true),
              )
            else
              ..._buildNewTabSections(
                installingApps: installingApps,
                automaticUpdates: automaticUpdates,
                manualUpdates: manualUpdates,
              ),
          ] else ...[
            if (upToDateApps.isEmpty && uncatalogedApps.isEmpty)
              SliverToBoxAdapter(
                child: _UpdatesTabEmptyState(onNewReleasesTab: false),
              )
            else if (upToDateApps.isNotEmpty)
              _AppsSliver(apps: upToDateApps, keyPrefix: 'uptodate'),
          ],
          if (!onNewTab && uncatalogedApps.isNotEmpty) ...[
            if (upToDateApps.isNotEmpty) const SliverToBoxAdapter(child: UpdateAppRowDivider()),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) return const UpdateAppRowDivider();
                  return _UncatalogedAppRow(
                    key: ValueKey(
                      'uncataloged_${uncatalogedApps[index ~/ 2].appId}',
                    ),
                    packageInfo: uncatalogedApps[index ~/ 2],
                  );
                },
                childCount: uncatalogedApps.length * 2 - 1,
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
        ],
      ),
    );
  }
}

List<Widget> _buildNewTabSections({
  required List<App> installingApps,
  required List<App> automaticUpdates,
  required List<App> manualUpdates,
}) {
  final slivers = <Widget>[];
  var needsDivider = false;

  void addSection({
    required String title,
    required List<App> apps,
    required String keyPrefix,
    List<App> updateAllApps = const [],
  }) {
    if (apps.isEmpty) return;
    if (needsDivider) {
      slivers.add(const SliverToBoxAdapter(child: UpdateAppRowDivider()));
    }
    slivers.add(
      SliverToBoxAdapter(
        child: _UpdatesSectionHeader(
          title: title,
          updateAllApps: updateAllApps,
        ),
      ),
    );
    slivers.add(_AppsSliver(apps: apps, keyPrefix: keyPrefix));
    needsDivider = true;
  }

  addSection(
    title: 'Installing',
    apps: installingApps,
    keyPrefix: 'installing',
  );
  addSection(
    title: 'Updates',
    apps: automaticUpdates,
    keyPrefix: 'automatic',
    updateAllApps: automaticUpdates,
  );
  addSection(
    title: 'Manual Updates',
    apps: manualUpdates,
    keyPrefix: 'manual',
    updateAllApps: manualUpdates,
  );

  return slivers;
}

class _UpdatesSectionHeader extends ConsumerWidget {
  const _UpdatesSectionHeader({
    required this.title,
    this.updateAllApps = const [],
  });

  final String title;
  final List<App> updateAllApps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final showUpdateAll = updateAllApps.length >= 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: LabTextStyles.eyebrow13.copyWith(color: c.white33),
            ),
          ),
          if (showUpdateAll)
            GestureDetector(
              onTap: () => queueAllUpdates(ref, updateAllApps),
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Update All',
                style: LabTextStyles.reg13.copyWith(color: c.white33),
              ),
            ),
        ],
      ),
    );
  }
}

class _UpdatesTabEmptyState extends StatelessWidget {
  const _UpdatesTabEmptyState({required this.onNewReleasesTab});

  final bool onNewReleasesTab;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Text(
          onNewReleasesTab
              ? 'All installed apps are up to date'
              : 'No apps are fully up to date yet',
          style: LabTextStyles.reg15.copyWith(color: c.white33),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _AppsSliver extends StatelessWidget {
  const _AppsSliver({required this.apps, required this.keyPrefix});

  final List<App> apps;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index.isOdd) return const UpdateAppRowDivider();
          final app = apps[index ~/ 2];
          return UpdateAppRow(
            key: ValueKey('${keyPrefix}_${app.identifier}'),
            app: app,
          );
        },
        childCount: apps.length * 2 - 1,
      ),
    );
  }
}

class _UncatalogedAppRow extends StatelessWidget {
  const _UncatalogedAppRow({super.key, required this.packageInfo});

  final PackageInfo packageInfo;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UpdateAppRow.horizontalPadding,
        vertical: UpdateAppRow.verticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: UpdateAppRow.iconSize,
            height: UpdateAppRow.iconSize,
            decoration: BoxDecoration(
              color: c.gray33,
              borderRadius: BorderRadius.circular(LabRadius.r12),
              border: LabBorder.all(color: c.white16, width: LabStroke.thin),
            ),
            child: Center(
              child: Icon(
                Icons.android,
                size: 22,
                color: c.white33,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  packageInfo.name ?? packageInfo.appId,
                  style: LabTextStyles.semibold17.copyWith(color: c.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  packageInfo.version,
                  style: LabTextStyles.reg13.copyWith(color: c.white33),
                ),
                const SizedBox(height: 2),
                Text(
                  packageInfo.appId,
                  style: LabTextStyles.reg13.copyWith(color: c.white33),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
