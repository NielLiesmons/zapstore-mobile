import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/debug_utils.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/widgets/app_detail_widgets.dart';
import 'package:zapstore/widgets/app_header.dart';
import 'package:zapstore/widgets/comments_section.dart';
import 'package:zapstore/widgets/common/detail_page_chrome.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/profile_pic_stack.dart';
import 'package:zapstore/widgets/common/time_utils.dart';
import 'package:zapstore/widgets/expandable_markdown.dart';
import 'package:zapstore/services/nostr_comment_service.dart';
import 'package:zapstore/widgets/modals/actions_modal.dart';
import 'package:zapstore/widgets/modals/releases_modal.dart';
import 'package:zapstore/widgets/social/thread_root.dart';
import 'package:zapstore/widgets/modals/security_modal.dart';
import 'package:zapstore/widgets/screenshots_gallery.dart';
import 'package:zapstore/widgets/social/details_tab.dart';
import 'package:zapstore/widgets/social/social_tabs.dart';
import 'package:zapstore/widgets/social/zaps_section.dart';
import 'package:zapstore/widgets/common/top_scroll_fader.dart';
class AppDetailScreen extends HookConsumerWidget {
  const AppDetailScreen({super.key, required this.appId, this.authorPubkey});

  final String appId;
  final String? authorPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.read(packageManagerProvider.notifier).platform;

    // Query app with relationships including author profile
    final appState = ref.watch(
      query<App>(
        authors: authorPubkey != null ? {authorPubkey!} : null,
        tags: {
          '#d': {appId},
          '#f': {platform},
        },
        limit: 1,
        and: (a) => {
          a.latestAsset.query(),
          a.latestRelease.query(
            and: (release) => {release.latestMetadata.query()},
          ),
        },
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: false),
        subscriptionPrefix: 'app-detail-$appId',
      ),
    );

    // Listen for query completion with no results - app removed from relay
    ref.listen(
      query<App>(
        authors: authorPubkey != null ? {authorPubkey!} : null,
        tags: {
          '#d': {appId},
          '#f': {platform},
        },
        limit: 1,
        and: (a) => {
          a.latestAsset.query(),
          a.latestRelease.query(
            and: (release) => {release.latestMetadata.query()},
          ),
        },
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: false),
        subscriptionPrefix: 'app-detail-$appId',
      ),
      (previous, next) async {
        if (next is StorageData<App> && next.models.isEmpty) {
          await ref.storage.clear(
            RequestFilter<App>(
              tags: {
                '#d': {appId},
              },
            ).toRequest(),
          );
          if (context.mounted) {
            context.pop();
          }
        }
      },
    );

    final app = appState.models.firstOrNull;

    if (appState case StorageError(:final exception)) {
      return _ErrorScaffold(message: exception.toString());
    }

    if (app == null) {
      return const Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: AppDetailSkeleton(),
          ),
        ),
      );
    }

    return _AppDetailContent(app: app);
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Open App')),
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

// ─────────────────────────────────────────────────────────────────────────────
// Main detail content
// ─────────────────────────────────────────────────────────────────────────────

class _AppDetailContent extends HookConsumerWidget {
  final App app;

  const _AppDetailContent({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final signedInPubkey = ref.watch(Signer.activePubkeyProvider);
    final showDebugSections = isDebugMode(signedInPubkey);

    // Author profile
    final authorState = ref.watch(
      query<Profile>(
        authors: {app.pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'app-detail-profile',
      ),
    );
    final author = authorState.models.firstOrNull;

    // Zapstore catalog profile (used in the detail header community stack)
    final catalogProfileState = ref.watch(
      query<Profile>(
        authors: {kZapstoreCommunityPubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          cachedFor: Duration(hours: 6),
        ),
        subscriptionPrefix: 'app-detail-catalog-profile',
      ),
    );
    final catalogProfile = catalogProfileState.models.firstOrNull;

    final latestRelease = app.latestRelease.value;
    final latestMetadata = app.installable;

    final commentsState = latestMetadata != null
        ? ref.watch(
            query<Comment>(
              tags: {'#A': {app.id}},
              source: LocalAndRemoteSource(stream: true, relays: 'AppCatalog'),
              subscriptionPrefix: 'app-comments',
            ),
          )
        : null;
    final commentTabMeta = commentsState != null
        ? commentFeedTabMeta(commentsState)
        : null;

    // Security panel: matches webapp's publishedByDeveloper / hasRepository logic.
    // isRelaySigned == published by indexer (not the developer)
    final publishedByDeveloper = !app.isRelaySigned;
    final hasRepository = app.repository?.isNotEmpty == true;

    final topPad = MediaQuery.paddingOf(context).top;
    final scrollController = useScrollController();
    final pageTitle = app.name ?? app.identifier;
    final publisherName = author?.name ?? detailShortPubkey(app.pubkey);
    final communityItems = [
      if (catalogProfile != null) ProfilePicItem(profile: catalogProfile),
    ];

    void openOptions() => showActionsModal(
          context,
          contentType: ActionsContentType.app,
          rootContext: ThreadRootContext.fromApp(
            app,
            version: latestMetadata?.version,
          ),
          version: latestMetadata?.version,
          onCommentSubmit: (result) => publishRootComment(
            ref: ref,
            result: result,
            app: app,
            version: latestMetadata?.version,
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
                    leading: app.isRelaySigned
                        ? LabIcon(
                            LabIcons.index,
                            size: 26,
                            color: c.white33,
                          )
                        : ProfilePic(
                            profile: author,
                            size: kDetailAuthorAvatarSize,
                          ),
                    title: app.isRelaySigned ? 'Indexer' : publisherName,
                    onAuthorTap: app.isRelaySigned
                        ? null
                        : () => pushUser(context, app.pubkey),
                    timestamp: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: TimeAgoText(
                        app.event.createdAt,
                        style: LabTextStyles.reg13.copyWith(color: c.white33),
                      ),
                    ),
                    trailing: DetailCommunityMenu(
                      groupId: 'app-community-dropdown-${app.identifier}',
                      menuTitle:
                          'This app is published in the following communities:',
                      items: communityItems,
                    ),
                  ),

                  // App header (pic + name + platform pill + install button)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: AppHeader(
                      app: app,
                      bottomSpacing: 16,
                    ),
                  ),

                  // Screenshots gallery
                  if (app.images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ScreenshotsGallery(app: app),
                    ),

                  // App description — webapp-matched: reg15, line-height 1.5,
                  // white85, collapses to 120px with gradient fade + Read More pill
                  if (app.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: ExpandableMarkdown(
                        data: app.description,
                        styleSheet: MarkdownStyleSheet.fromTheme(
                          Theme.of(context),
                        ).copyWith(
                          p: LabTextStyles.reg15.copyWith(
                            color: c.white.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                          blockquoteDecoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                  // Info panels: Security (golden-ratio wider) + Releases
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: _InfoPanels(
                      publishedByDeveloper: publishedByDeveloper,
                      hasRepository: hasRepository,
                      latestRelease: latestRelease,
                      latestMetadata: latestMetadata,
                      app: app,
                      author: author,
                      catalogProfile: catalogProfile,
                    ),
                  ),

                  // Social tabs: Comments · Tips · Labels · Details
                  SocialTabs(
                    commentCount: commentTabMeta?.count,
                    commentsLoading: commentTabMeta?.initialLoading ?? false,
                    commentsSyncing: commentTabMeta?.syncing ?? false,
                    contentBuilder: (tab) {
                      switch (tab) {
                        case SocialTab.comments:
                          if (latestMetadata != null) {
                            return CommentsSection(
                              app: app,
                              fileMetadata: latestMetadata,
                            );
                          }
                          return const SizedBox.shrink();
                        case SocialTab.zaps:
                          return ZapsSection(
                            tags: app.event.addressableIdTagMap,
                            subscriptionId: app.identifier,
                          );
                        case SocialTab.labels:
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No labels yet')),
                          );
                        case SocialTab.details:
                          return DetailsTab(
                            publicationLabel: 'App',
                            shareableId: app.identifier,
                            pubkey: app.pubkey,
                            repository: app.repository,
                          );
                      }
                    },
                  ),

                  if (showDebugSections)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: DebugVersionsSection(app: app),
                    ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Info panels row: Security (golden-ratio wider) + Releases
// ─────────────────────────────────────────────────────────────────────────────

class _InfoPanels extends StatelessWidget {
  const _InfoPanels({
    required this.publishedByDeveloper,
    required this.hasRepository,
    required this.app,
    this.latestRelease,
    this.latestMetadata,
    this.author,
    this.catalogProfile,
  });

  final bool publishedByDeveloper;
  final bool hasRepository;
  final App app;
  final dynamic latestRelease;
  final Installable? latestMetadata;
  final Profile? author;
  final Profile? catalogProfile;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Security panel: flex 8 ≈ 61.5% ≈ golden ratio
          Expanded(
            flex: 8,
            child: _SecurityPanel(
              publishedByDeveloper: publishedByDeveloper,
              hasRepository: hasRepository,
              app: app,
              author: author,
              catalogProfile: catalogProfile,
            ),
          ),
          const SizedBox(width: 12),
          // Releases panel: flex 5 ≈ 38.5%
          Expanded(
            flex: 5,
            child: _ReleasesPanel(
              latestRelease: latestRelease,
              latestMetadata: latestMetadata,
              app: app,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Security panel
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityPanel extends StatelessWidget {
  const _SecurityPanel({
    required this.publishedByDeveloper,
    required this.hasRepository,
    required this.app,
    this.author,
    this.catalogProfile,
  });

  final bool publishedByDeveloper;
  final bool hasRepository;
  final App app;
  final Profile? author;
  final Profile? catalogProfile;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    final items = [
      _PanelCheckData(
        isCheck: publishedByDeveloper,
        label: publishedByDeveloper ? 'Published by Developer' : 'Published by Indexer',
        opacity: 1.0,
        scale: 1.0,
      ),
      _PanelCheckData(
        isCheck: hasRepository,
        label: hasRepository ? 'Open source' : 'Closed-source',
        opacity: 0.78,
        scale: 0.96,
      ),
      _PanelCheckData(
        isCheck: true,
        label: 'Trusted Catalog',
        opacity: 0.56,
        scale: 0.92,
      ),
    ];

    return GestureDetector(
      onTap: () => SecurityModal.show(
        context,
        publishedByDeveloper: publishedByDeveloper,
        hasRepository: hasRepository,
        app: app,
        author: author,
        catalogProfile: catalogProfile,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        decoration: BoxDecoration(
          color: c.white8,
          borderRadius: BorderRadius.circular(LabRadius.r16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security',
              style: LabTextStyles.semibold15.copyWith(color: c.white),
            ),
            const SizedBox(height: 4),
            for (final item in items)
              Opacity(
                opacity: item.opacity,
                child: Transform.scale(
                  scale: item.scale,
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: item.isCheck
                              ? LabIcon(
                                  LabIcons.check,
                                  size: 13,
                                  color: c.blurpleColor,
                                  thick: true,
                                )
                              : Center(
                                  child: Container(
                                    width: 20,
                                    height: 2.8,
                                    decoration: BoxDecoration(
                                      color: c.white33,
                                      borderRadius: BorderRadius.circular(1.4),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.label,
                            style: LabTextStyles.reg13.copyWith(
                              color: c.white66,
                            ),
                          ),
                        ),
                      ],
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

class _PanelCheckData {
  const _PanelCheckData({
    required this.isCheck,
    required this.label,
    required this.opacity,
    required this.scale,
  });
  final bool isCheck;
  final String label;
  final double opacity;
  final double scale;
}

// ─────────────────────────────────────────────────────────────────────────────
// Releases panel
// ─────────────────────────────────────────────────────────────────────────────

class _ReleasesPanel extends StatelessWidget {
  const _ReleasesPanel({this.latestRelease, this.latestMetadata, required this.app});

  final dynamic latestRelease;
  final Installable? latestMetadata;
  final App app;

  static const int _maxItems = 3;

  /// Strips markdown and takes the first sentence / up to 50 chars.
  static String _notesPreview(String? notes) {
    if (notes == null || notes.isEmpty) return '';
    final stripped = notes
        .replaceAll(RegExp(r'[#*`>\[\]()]'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
    if (stripped.isEmpty) return '';
    final first = stripped.split(RegExp(r'[.!?]\s'))[0].trim();
    final preview = first.length > 50 ? '${first.substring(0, 50)}…' : first;
    return preview;
  }

  static String _trimVersion(String? version) {
    if (version == null) return '';
    const maxLen = 12;
    return version.length > maxLen ? '${version.substring(0, maxLen)}…' : version;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    // Build rows from whatever release data we have (just the latest for now)
    final rows = <_ReleaseRow>[];
    if (latestMetadata != null) {
      final version = _trimVersion(latestMetadata!.version);
      final notes = latestRelease != null
          ? _notesPreview(
              // latestRelease is dynamic; try to read .content or .notes
              _tryGetNotes(latestRelease),
            )
          : '';
      rows.add(_ReleaseRow(version: version, preview: notes));
    }

    return GestureDetector(
      onTap: () => ReleasesModal.show(context, app: app),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        decoration: BoxDecoration(
          color: c.white8,
          borderRadius: BorderRadius.circular(LabRadius.r16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Releases',
              style: LabTextStyles.semibold15.copyWith(color: c.white),
            ),
            const SizedBox(height: 4),
            if (rows.isEmpty)
              Text(
                'No releases found.',
                style: LabTextStyles.reg13.copyWith(color: c.white33),
              )
            else
              for (var i = 0; i < rows.length && i < _maxItems; i++)
                Opacity(
                  opacity: 1.0 - i * 0.22,
                  child: Transform.scale(
                    scale: 1.0 - i * 0.04,
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        children: [
                          Text(
                            rows[i].version,
                            style: LabTextStyles.med13.copyWith(
                              color: c.white33,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              rows[i].preview.isEmpty ? 'No notes' : rows[i].preview,
                              style: LabTextStyles.reg13.copyWith(
                                color: c.white66,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static String? _tryGetNotes(dynamic release) {
    if (release == null) return null;
    try {
      // Release model may expose notes via .content or .notes
      return (release as dynamic).content as String?;
    } catch (_) {}
    try {
      return (release as dynamic).notes as String?;
    } catch (_) {}
    return null;
  }
}

class _ReleaseRow {
  const _ReleaseRow({required this.version, required this.preview});
  final String version;
  final String preview;
}

