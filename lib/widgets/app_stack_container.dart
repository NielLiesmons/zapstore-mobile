import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/utils/nostr_route.dart';
import '../utils/extensions.dart';
import '../utils/text_styles.dart';
import '../utils/url_utils.dart';
import '../theme.dart';
import '../services/package_manager/package_manager.dart';
import 'common/app_pic.dart';
import 'common/profile_pic.dart';
import 'common/profile_name_widget.dart';
import 'common/shimmer.dart';

/// Get the raw `a` tag values from the stack's event (available immediately)
Set<String> getRawAppTagValues(AppStack stack) {
  return stack.event.getTagSetValues('a');
}

/// Helper to compute preview app addressable IDs for a stack (3 apps max).
/// Returns full addressable IDs (e.g. '32267:pubkey:identifier').
List<String> getPreviewAddressableIds(AppStack stack) {
  final rawTags =
      getRawAppTagValues(stack).where((id) => id.startsWith('32267:')).toList()
        ..shuffle(Random(stack.id.hashCode));
  return rawTags.take(4).toList();
}

/// Decompose addressable IDs (e.g. '32267:pubkey:identifier') into
/// the sets of authors and identifiers needed for a query filter.
({Set<String> authors, Set<String> identifiers}) decomposeAddressableIds(
  Iterable<String> addressableIds,
) {
  final authors = <String>{};
  final identifiers = <String>{};
  for (final id in addressableIds) {
    final parts = id.split(':');
    if (parts.length >= 3) {
      authors.add(parts[1]);
      identifiers.add(parts.skip(2).join(':'));
    }
  }
  return (authors: authors, identifiers: identifiers);
}

/// Seed generated once per app session for stable shuffle order
final int _sessionSeed = Random().nextInt(1 << 32);

/// Shuffle stacks with a per-session seed for variety
List<AppStack> _shuffleStacks(List<AppStack> stacks, {String? signedInPubkey}) {
  final userSeed = signedInPubkey?.hashCode ?? 0;
  return stacks.toList()..shuffle(Random(_sessionSeed ^ userSeed));
}

/// Fixed card width — matches the app-column width (290px) for visual consistency.
const double _kStackCardWidth = 290;

/// Row height — fits icon grid + text column without vertical overflow.
const double _kStackRowHeight = 104;

/// App Stack Container — horizontally scrolling row of fixed-width stack cards,
/// matching the webapp discover layout.
class AppStackContainer extends ConsumerWidget {
  const AppStackContainer({super.key, this.showSkeleton = false});

  final bool showSkeleton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (showSkeleton) {
      return _buildSkeleton(context);
    }

    final signedInPubkey = ref.watch(Signer.activePubkeyProvider);
    final platform = ref.read(packageManagerProvider.notifier).platform;

    final appStacksState = ref.watch(
      query<AppStack>(
        authors: {kZapstoreCommunityPubkey},
        limit: 20,
        tags: {'#f': {platform}},
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: false),
        subscriptionPrefix: 'app-stack',
        schemaFilter: appStackEventFilter,
      ),
    );

    final allStacks = appStacksState.models.toList();

    if (allStacks.isEmpty) {
      if (appStacksState is StorageLoading<AppStack>) return _buildSkeleton(context);
      return const SizedBox.shrink();
    }

    final sortedStacks = _shuffleStacks(allStacks, signedInPubkey: signedInPubkey);

    final allPreviewIds = <String>{};
    final stackPreviewIds = <String, List<String>>{};
    for (final stack in sortedStacks) {
      final ids = getPreviewAddressableIds(stack);
      stackPreviewIds[stack.id] = ids;
      allPreviewIds.addAll(ids);
    }

    final (:authors, :identifiers) = decomposeAddressableIds(allPreviewIds);

    final previewAppsState = allPreviewIds.isNotEmpty
        ? ref.watch(
            query<App>(
              authors: authors,
              tags: {'#d': identifiers},
              source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: false),
              subscriptionPrefix: 'app-stack-preview-apps',
            ),
          )
        : null;

    final appsMap = {
      for (final app in previewAppsState?.models ?? <App>[]) app.id: app,
    };

    return SizedBox(
      height: _kStackRowHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,  // allow centred border stroke to paint outside
        padding: const EdgeInsets.only(left: 14, right: 4),
        itemCount: sortedStacks.length + 1, // +1 for "see more"
        itemBuilder: (ctx, i) {
          if (i == sortedStacks.length) {
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: _kStackCardWidth,
                child: _SeeMoreCard(),
              ),
            );
          }
          final stack = sortedStacks[i];
          return SizedBox(
            width: _kStackCardWidth,
            child: StackCard(
              stack: stack,
              previewIdentifiers: stackPreviewIds[stack.id] ?? [],
              appsMap: appsMap,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return SizedBox(
      height: _kStackRowHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(left: 14, right: 4),
        itemCount: 4,
        itemBuilder: (ctx, i) =>
            const SizedBox(width: _kStackCardWidth, child: StackCardSkeleton()),
      ),
    );
  }
}

/// "See more" card that navigates to AllStacksScreen
class _SeeMoreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return GestureDetector(
      onTap: () => pushStacks(context),
      child: Center(
        child: Text(
          'See more',
          style: LabTextStyles.med15.copyWith(color: c.blurpleLightColor),
        ),
      ),
    );
  }
}

/// Static skeleton bone — a flat, non-animated placeholder for secondary
/// content (descriptions, author names) per the design system rule that only
/// primary/title content should shimmer.
class _StaticBone extends StatelessWidget {
  const _StaticBone({
    required this.width,
    required this.height,
    this.isCircle = false,
  });

  final double width;
  final double height;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.white8,
        borderRadius: isCircle
            ? BorderRadius.circular(width / 2)
                : BorderRadius.circular(LabRadius.r17),
      ),
    );
  }
}

/// Skeleton for [StackCard] — shimmer placeholders matching the live layout.
class StackCardSkeleton extends StatelessWidget {
  const StackCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer(
            width: StackCard.gridExtent,
            height: StackCard.gridExtent,
            radius: LabRadius.r16,
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: StackCard.gridExtent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title: shimmer (important content)
                const Shimmer(width: 100, height: 15),
                const SizedBox(height: 6),
                // Description + author: static boxes (less important per design system)
                _StaticBone(width: 140, height: 12),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StaticBone(width: 24, height: 24, isCircle: true),
                    const SizedBox(width: 8),
                    _StaticBone(width: 60, height: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual stack card — direct port of LabAppPackCard:
///   Padding(horizontal:12) > Row(center) > [Container(95×95 icon grid), Gap(12), Expanded Column]
///   Column: bold17 name · Gap(2) · reg13 description(maxLines:2) · Gap(8) · author row
class StackCard extends ConsumerWidget {
  const StackCard({
    super.key,
    required this.stack,
    required this.previewIdentifiers,
    required this.appsMap,
    this.showAuthor = true,
    this.trailingPadding = 24,
  });

  final AppStack stack;
  final List<String> previewIdentifiers;
  final Map<String, App> appsMap;
  final bool showAuthor;

  /// Right padding between cards in horizontal discover lists. Use `0` in
  /// profile browse rows where [ListView] separators handle spacing.
  final double trailingPadding;

  static const double gridExtent = _gridExtent;

  static const double _iconSize = 32;
  static const double _gridGap = 6;
  static const double _gridPadding = 8;
  static const double _gridBorderWidth = 1.4;
  static const double _gridInnerExtent =
      _iconSize * 2 + _gridGap;
  static const double _gridExtent =
      _gridPadding * 2 + _gridInnerExtent + _gridBorderWidth;

  /// Renders one icon in the grid, or an empty placeholder tile.
  Widget _gridIcon(App? app, LabColors c) {
    if (app != null) {
      return AppPic(
        iconUrl: firstValidHttpUrl(app.icons),
        name: app.name,
        identifier: app.identifier,
        size: _iconSize,
      );
    }
    return Container(
      width: _iconSize,
      height: _iconSize,
      decoration: BoxDecoration(
        color: c.white8,
        borderRadius: BorderRadius.circular(LabRadius.r8),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    final authorState = showAuthor
        ? ref.watch(
            query<Profile>(
              authors: {stack.event.pubkey},
              source: const LocalAndRemoteSource(
                relays: {'social', 'vertex'},
                cachedFor: Duration(hours: 2),
              ),
              subscriptionPrefix: 'stack-author-${stack.id}',
            ),
          )
        : null;

    final author = authorState?.models.firstOrNull;
    final isAuthorLoading = authorState is StorageLoading;

    final previewApps = previewIdentifiers
        .map((id) => appsMap[id])
        .whereType<App>()
        .toList();

    // Pad to 4 entries for the 2×2 grid (null = empty placeholder tile)
    final gridApps = List<App?>.from(previewApps.take(4))
      ..addAll(List.filled((4 - previewApps.length).clamp(0, 4), null));

    final description = stack.description ?? '';

    return GestureDetector(
      onTap: () => pushStack(
        context,
        stack.identifier,
        author: stack.pubkey,
        kind: stack.event.kind,
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(right: trailingPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: _gridExtent,
              height: _gridExtent,
              decoration: BoxDecoration(
                color: c.gray33,
                borderRadius: BorderRadius.circular(LabRadius.r16),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LabRadius.r16),
                border: LabBorder.all(
                  color: c.white16,
                  width: _gridBorderWidth,
                ),
              ),
              padding: const EdgeInsets.all(_gridPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _gridIcon(gridApps[0], c),
                      const SizedBox(width: _gridGap),
                      _gridIcon(gridApps[1], c),
                    ],
                  ),
                  const SizedBox(height: _gridGap),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _gridIcon(gridApps[2], c),
                      const SizedBox(width: _gridGap),
                      _gridIcon(gridApps[3], c),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stack.name ?? stack.identifier,
                    style:
                        LabTextStyles.semibold17.copyWith(color: c.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description.isNotEmpty
                        ? description
                        : 'No description',
                    style: LabTextStyles.reg13.copyWith(
                      color: description.isNotEmpty
                          ? c.white66
                          : c.white33,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showAuthor) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => pushUser(context, stack.event.pubkey),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          ProfilePic(profile: author, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ProfileNameWidget(
                              pubkey: stack.event.pubkey,
                              profile: author,
                              isLoading: isAuthorLoading,
                              style: LabTextStyles.reg13
                                  .copyWith(color: c.white33),
                              skeletonWidth: 60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


