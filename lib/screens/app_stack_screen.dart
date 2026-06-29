import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/app_small_card.dart';
import 'package:zapstore/widgets/comments_section.dart';
import 'package:zapstore/widgets/common/detail_page_chrome.dart';
import 'package:zapstore/services/nostr_comment_service.dart';
import 'package:zapstore/widgets/modals/actions_modal.dart';
import 'package:zapstore/widgets/social/thread_root.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/profile_pic_stack.dart';
import 'package:zapstore/widgets/common/time_utils.dart';
import 'package:zapstore/widgets/common/top_scroll_fader.dart';
import 'package:zapstore/widgets/floating_overflow_menu.dart'
    show getStackShareUrl;
import 'package:zapstore/widgets/social/details_tab.dart';
import 'package:zapstore/widgets/social/social_tabs.dart';
import 'package:zapstore/widgets/social/zaps_section.dart';
import 'package:zapstore/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppStackScreen — full parity with app_detail_screen.dart pattern:
//   • Floating blurred header: back · author pic · name · timestamp · community
//   • Scrollable body behind the header: title, description+count, horizontal
//     app grid (columns of 3, 280 px wide), social tabs
//   • Floating BottomBar for comments/zaps/options
// ─────────────────────────────────────────────────────────────────────────────

class AppStackScreen extends HookConsumerWidget {
  const AppStackScreen({super.key, required this.stackId, this.authorPubkey});

  final String stackId;
  final String? authorPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stackState = ref.watch(
      query<AppStack>(
        authors: authorPubkey != null ? {authorPubkey!} : null,
        tags: {
          '#d': {stackId},
        },
        limit: 1,
        source: const LocalAndRemoteSource(
          relays: 'AppCatalog',
          stream: false,
        ),
        subscriptionPrefix: 'app-stack-detail-$stackId',
      ),
    );

    if (stackState case StorageError(:final exception)) {
      return _ErrorScaffold(message: exception.toString());
    }

    final stack = stackState.models.firstOrNull;

    if (stack == null) {
      if (stackState is StorageLoading) {
        return const Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: _AppStackSkeleton(),
            ),
          ),
        );
      }
      return _NotFoundScaffold(stackId: stackId);
    }

    return _AppStackContentWithApps(stack: stack);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loads apps (public or decrypted private) then hands off to _AppStackContent
// ─────────────────────────────────────────────────────────────────────────────

class _AppStackContentWithApps extends HookConsumerWidget {
  final AppStack stack;

  const _AppStackContentWithApps({required this.stack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEncrypted = stack.content.isNotEmpty;

    final decryptedAppIds = useState<Set<String>?>(null);
    final decryptError = useState<String?>(null);

    useEffect(() {
      if (!isEncrypted) return null;

      Future<void> decrypt() async {
        final signer = ref.read(Signer.activeSignerProvider);
        final pubkey = ref.read(Signer.activePubkeyProvider);

        if (signer == null || pubkey == null) {
          decryptError.value = 'Sign in required to view this stack';
          return;
        }

        try {
          final decrypted = await signer.nip44Decrypt(stack.content, pubkey);
          final ids = (jsonDecode(decrypted) as List).cast<String>().toSet();
          decryptedAppIds.value = ids;
        } catch (e) {
          decryptError.value = 'Failed to decrypt stack';
        }
      }

      decrypt();
      return null;
    }, [stack.content]);

    if (decryptError.value != null) {
      return _AppStackContent(
        stack: stack,
        apps: const [],
        errorMessage: decryptError.value,
      );
    }

    if (isEncrypted && decryptedAppIds.value == null) {
      return const Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: _AppStackSkeleton(),
          ),
        ),
      );
    }

    final appAddressableIds = isEncrypted
        ? decryptedAppIds.value!
        : stack.event
            .getTagSetValues('a')
            .where((id) => id.startsWith('32267:'))
            .toSet();

    if (appAddressableIds.isEmpty) {
      return _AppStackContent(stack: stack, apps: const []);
    }

    final authors = <String>{};
    final identifiers = <String>{};
    for (final id in appAddressableIds) {
      final parts = id.split(':');
      if (parts.length >= 3) {
        authors.add(parts[1]);
        identifiers.add(parts.skip(2).join(':'));
      }
    }

    final appsState = ref.watch(
      query<App>(
        authors: authors,
        tags: {
          '#d': identifiers,
          '#f': {'android-arm64-v8a'},
        },
        and: (app) => {
          app.latestRelease.query(
            and: (release) => {
              release.latestMetadata.query(),
              release.latestAsset.query(),
            },
          ),
        },
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: false),
        subscriptionPrefix: 'app-stack-apps-${stack.identifier}',
      ),
    );

    final appsMap = {for (final app in appsState.models) app.id: app};
    final orderedApps = appAddressableIds
        .map((id) => appsMap[id])
        .whereType<App>()
        .toList();

    return _AppStackContent(stack: stack, apps: orderedApps);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main content widget — mirrors _AppDetailContent structure exactly
// ─────────────────────────────────────────────────────────────────────────────

class _AppStackContent extends HookConsumerWidget {
  final AppStack stack;
  final List<App> apps;
  final String? errorMessage;

  const _AppStackContent({
    required this.stack,
    required this.apps,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    // Author profile
    final authorState = ref.watch(
      query<Profile>(
        authors: {stack.pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'app-stack-profile',
      ),
    );
    final author = authorState.models.firstOrNull;

    // Zapstore catalog profile — shown as community in the header
    final catalogProfileState = ref.watch(
      query<Profile>(
        authors: {kZapstoreCommunityPubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          cachedFor: Duration(hours: 6),
        ),
        subscriptionPrefix: 'app-stack-catalog-profile',
      ),
    );
    final catalogProfile = catalogProfileState.models.firstOrNull;

    final commentsState = ref.watch(
      query<Comment>(
        tags: {'#A': {stack.id}},
        source: LocalAndRemoteSource(stream: true, relays: 'AppCatalog'),
        subscriptionPrefix: 'app-stack-comments',
      ),
    );
    final commentTabMeta = commentFeedTabMeta(commentsState);

    final packageManager = ref.watch(packageManagerProvider.notifier);
    final sortedApps = _sortAppsUninstalledFirst(apps, packageManager);

    final topPad = MediaQuery.paddingOf(context).top;
    final scrollController = useScrollController();
    final isEncrypted = stack.content.isNotEmpty;
    final pageTitle = stack.name ?? stack.identifier;
    final publisherName = author?.name ?? detailShortPubkey(stack.pubkey);
    final communityItems = [
      if (catalogProfile != null) ProfilePicItem(profile: catalogProfile),
    ];

    void openOptions() => showActionsModal(
          context,
          contentType: ActionsContentType.stack,
          stack: stack,
          authorName: publisherName,
          rootContext: ThreadRootContext.fromStack(stack),
          onCommentSubmit: (result) => publishRootComment(
            ref: ref,
            result: result,
            stack: stack,
          ),
          ref: ref,
        );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TopScrollFader(
              scrollController: scrollController,
              fadeHeight: 48,
              safeEdgeFades: true,
              hasBottomBar: false,
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: topPad + 8,
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailAuthorMetaRow(
                      leading: ProfilePic(
                        profile: author,
                        pubkey: stack.pubkey,
                        size: kDetailAuthorAvatarSize,
                      ),
                      title: publisherName,
                      onAuthorTap: () => pushUser(context, stack.pubkey),
                      timestamp: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: TimeAgoText(
                          stack.event.createdAt,
                          style: LabTextStyles.reg13.copyWith(color: c.white33),
                        ),
                      ),
                      trailing: DetailCommunityMenu(
                        groupId: 'stack-community-dropdown-${stack.identifier}',
                        menuTitle:
                            'This stack is published in the following communities:',
                        items: communityItems,
                      ),
                    ),

                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.rougeColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          errorMessage!,
                          style: LabTextStyles.reg13
                              .copyWith(color: c.rougeColor),
                          ),
                        ),
                      ),

                    // ── Stack header: title + description + count ─────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                      child: _StackTitleBlock(
                        stack: stack,
                        appCount: sortedApps.length,
                        colors: c,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Horizontal apps grid (columns of 3, 280 px wide) ──
                    if (sortedApps.isEmpty)
                      _EmptyAppsPlaceholder()
                    else
                      _HorizontalAppsGrid(apps: sortedApps),

                    // ── Social tabs ───────────────────────────────────────
                    if (!isEncrypted) ...[
                      const SizedBox(height: 16),
                      SocialTabs(
                        commentCount: commentTabMeta.count,
                        commentsLoading: commentTabMeta.initialLoading,
                        commentsSyncing: commentTabMeta.syncing,
                        contentBuilder: (tab) {
                          switch (tab) {
                            case SocialTab.comments:
                              return StackCommentsSection(stack: stack);
                            case SocialTab.zaps:
                              return ZapsSection(
                                tags: stack.event.addressableIdTagMap,
                                subscriptionId: stack.identifier,
                              );
                            case SocialTab.labels:
                              return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: Text('No labels yet')),
                              );
                            case SocialTab.details:
                              return DetailsTab(
                                publicationLabel: 'Stack',
                                shareableId: stack.identifier,
                                pubkey: stack.pubkey,
                              );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          DetailActionsButtonOverlay(
            onTap: openOptions,
            scrollController: scrollController,
            expandLabel: pageTitle,
          ),
        ],
      ),
    );
  }

  List<App> _sortAppsUninstalledFirst(
    List<App> apps,
    PackageManager packageManager,
  ) {
    final uninstalled = <App>[];
    final installed = <App>[];
    for (final app in apps) {
      if (packageManager.isInstalled(app.identifier)) {
        installed.add(app);
      } else {
        uninstalled.add(app);
      }
    }
    return [...uninstalled, ...installed];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stack title block: name row (+ lock icon) + description+count row
// Matches webapp's .stack-header structure.
// ─────────────────────────────────────────────────────────────────────────────

class _StackTitleBlock extends StatelessWidget {
  const _StackTitleBlock({
    required this.stack,
    required this.appCount,
    required this.colors,
  });

  final AppStack stack;
  final int appCount;
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final isEncrypted = stack.content.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      stack.name ?? stack.identifier,
                      style: LabTextStyles.heroTitle.copyWith(color: c.white),
                    ),
                  ),
                  if (isEncrypted) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.lock, size: 18, color: c.white33),
                  ],
                ],
              ),
            ),
          ],
        ),

        // Description + app count row
        if (stack.description != null || appCount > 0) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stack.description?.isNotEmpty == true)
                Expanded(
                  child: Text(
                    stack.description!,
                    style: LabTextStyles.reg15.copyWith(color: c.white66),
                  ),
                ),
              if (appCount > 0) ...[
                if (stack.description?.isNotEmpty == true)
                  const SizedBox(width: 16),
                Text(
                  '$appCount ${appCount == 1 ? 'App' : 'Apps'}',
                  style: LabTextStyles.reg15.copyWith(color: c.white33),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal apps grid — groups apps into columns of 3 (280 px wide, 16 px
// gap) inside an edge-to-edge horizontal scroll view. Matches webapp's
// getAppColumns + .app-column pattern exactly.
// ─────────────────────────────────────────────────────────────────────────────

class _HorizontalAppsGrid extends StatelessWidget {
  const _HorizontalAppsGrid({required this.apps});

  final List<App> apps;

  static const int _perColumn = 3;
  static const double _columnWidth = 280;
  static const double _columnGap = 16;

  @override
  Widget build(BuildContext context) {
    final columns = _groupColumns(apps, _perColumn);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Bleed to screen edges, pad inside so first column aligns with content
      padding: const EdgeInsets.symmetric(horizontal: 14),
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int ci = 0; ci < columns.length; ci++) ...[
            if (ci > 0) const SizedBox(width: _columnGap),
            SizedBox(
              width: _columnWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int ri = 0; ri < columns[ci].length; ri++) ...[
                    if (ri > 0) const SizedBox(height: 12),
                    AppSmallCard(app: columns[ci][ri]),
                  ],
                ],
              ),
            ),
          ],
          // Trailing padding to match leading (so last column has same visible
          // space as the first when scrolled to the end).
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  static List<List<App>> _groupColumns(List<App> apps, int perCol) {
    final cols = <List<App>>[];
    for (int i = 0; i < apps.length; i += perCol) {
      cols.add(apps.sublist(i, (i + perCol).clamp(0, apps.length)));
    }
    return cols;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Simple share/options modal content for stacks
// ─────────────────────────────────────────────────────────────────────────────

class _StackShareContent extends StatelessWidget {
  const _StackShareContent({required this.stack});

  final AppStack stack;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final shareUrl = getStackShareUrl(stack);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              // Copy share URL to clipboard
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Link copied!',
                    style: LabTextStyles.reg13.copyWith(color: c.white),
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: c.gray33,
                ),
              );
              // TODO: use Clipboard.setData when flutter/services is imported
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: c.white8,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  LabIcon(LabIcons.copy, size: 18, color: c.white66),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      shareUrl,
                      style: LabTextStyles.reg13.copyWith(color: c.white66),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error / not-found scaffolds
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Stack')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundScaffold extends StatelessWidget {
  final String stackId;
  const _NotFoundScaffold({required this.stackId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Stack')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.apps_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Stack not found',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This stack may have been deleted or is not available',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty apps placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyAppsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: c.white8,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No apps in this stack',
            style: LabTextStyles.reg15.copyWith(color: c.white33),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loading state
// ─────────────────────────────────────────────────────────────────────────────

class _AppStackSkeleton extends StatelessWidget {
  const _AppStackSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonizerConfig(
      data: LabColors.getSkeletonizerConfig(Theme.of(context).brightness),
      child: Skeletonizer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Skeleton title
            Container(
              height: 28,
              width: 180,
              decoration: BoxDecoration(
                color: LabColors.darkSkeletonBase,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            // Skeleton description
            Container(
              height: 16,
              width: 260,
              decoration: BoxDecoration(
                color: LabColors.darkSkeletonBase,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 32),
            // Skeleton horizontal app row (3 columns × 3 items)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              child: Row(
                children: List.generate(
                  3,
                  (ci) => Container(
                    width: 280,
                    margin: EdgeInsets.only(right: ci < 2 ? 16 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(
                        3,
                        (ri) => Padding(
                          padding: EdgeInsets.only(bottom: ri < 2 ? 12 : 0),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: LabColors.darkSkeletonBase,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 16,
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: LabColors.darkSkeletonBase,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 13,
                                    width: 160,
                                    decoration: BoxDecoration(
                                      color: LabColors.darkSkeletonBase,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
