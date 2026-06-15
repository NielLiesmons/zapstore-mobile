import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/widgets/app_small_card.dart';
import 'package:zapstore/widgets/app_stack_container.dart';
import 'package:zapstore/widgets/common/section_header.dart';

const double _kProfileBrowseListInset = 14;
const double _kProfileBrowseCardGap = 12;

double profileBrowseCardWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width - (_kProfileBrowseListInset * 2);

/// Full-width [AppSmallCard] items in a simple horizontal list (no chevrons).
class ProfileAppsBrowseRow extends StatelessWidget {
  const ProfileAppsBrowseRow({
    super.key,
    required this.apps,
    this.title = 'Published Apps',
  });

  final List<App> apps;
  final String title;

  static const double _rowHeight = 56;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const SizedBox.shrink();

    final cardWidth = profileBrowseCardWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, bottomPadding: 14),
        SizedBox(
          height: _rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: _kProfileBrowseListInset,
            ),
            clipBehavior: Clip.none,
            itemCount: apps.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: _kProfileBrowseCardGap),
            itemBuilder: (context, i) => SizedBox(
              width: cardWidth,
              child: AppSmallCard(app: apps[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Full-width [StackCard] items matching webapp AppStackCard on profile pages.
class ProfileStacksBrowseRow extends ConsumerWidget {
  const ProfileStacksBrowseRow({
    super.key,
    required this.stacks,
    this.title = 'Stacks',
  });

  final List<AppStack> stacks;
  final String title;

  static const double _rowHeight = StackCard.gridExtent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stacks.isEmpty) return const SizedBox.shrink();

    final cardWidth = profileBrowseCardWidth(context);

    final allPreviewIds = <String>{};
    final stackPreviewIds = <String, List<String>>{};
    for (final stack in stacks) {
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
              source: const LocalAndRemoteSource(
                relays: 'AppCatalog',
                stream: false,
              ),
              subscriptionPrefix: 'profile-browse-stack-apps',
            ),
          )
        : null;

    final appsMap = {
      for (final app in previewAppsState?.models ?? <App>[]) app.id: app,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, bottomPadding: 14),
        SizedBox(
          height: _rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: _kProfileBrowseListInset,
            ),
            clipBehavior: Clip.none,
            itemCount: stacks.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: _kProfileBrowseCardGap),
            itemBuilder: (context, i) {
              final stack = stacks[i];
              return SizedBox(
                width: cardWidth,
                child: StackCard(
                  stack: stack,
                  previewIdentifiers: stackPreviewIds[stack.id] ?? [],
                  appsMap: appsMap,
                  trailingPadding: 0,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
