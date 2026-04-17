import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/debug_utils.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/widgets/app_detail_widgets.dart';
import 'package:zapstore/widgets/app_header.dart';
import 'package:zapstore/widgets/app_info_table.dart';
import 'package:zapstore/widgets/author_container.dart';
import 'package:zapstore/widgets/comments_section.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/download_text_container.dart';
import 'package:zapstore/widgets/expandable_markdown.dart';
import 'package:zapstore/widgets/screenshots_gallery.dart';
import 'package:zapstore/widgets/social/details_tab.dart';
import 'package:zapstore/widgets/social/social_tabs.dart';
import 'package:zapstore/widgets/stacked_by_row.dart';

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
    final c = Theme.of(context).extension<AppColors>()!;
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

    return Scaffold(
      body: Column(
        children: [
          // Fixed blurred detail header
          _DetailHeader(
            app: app,
            author: author,
            catalogProfile: catalogProfile,
            latestMetadata: latestMetadata,
          ),

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App header (pic + name + platform pill + install button)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppHeader(app: app),
                  ),

                  // Published by / Released at + Stacked & zapped by
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (app.isRelaySigned && latestMetadata != null)
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: DownloadTextContainer(
                              url: latestMetadata.urls.first,
                              size: 14,
                              onTap: app.repository != null
                                  ? () => launchUrl(
                                      Uri.parse(app.repository!))
                                  : null,
                            ),
                          )
                        else if (author != null)
                          AuthorContainer(
                            profile: author,
                            beforeText: 'Published by',
                            oneLine: true,
                            size: 14,
                            app: app,
                            onTap: () => pushUser(context, author.pubkey),
                          )
                        else
                          const AuthorSkeleton(),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: StackedByRow(app: app),
                        ),
                      ],
                    ),
                  ),

                  // Screenshots gallery
                  if (app.images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ScreenshotsGallery(app: app),
                    ),

                  // App description
                  if (app.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 8,
                      ),
                      child: ExpandableMarkdown(
                        data: app.description,
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(
                              Theme.of(context),
                            ).copyWith(
                              p: context.textTheme.bodyLarge?.copyWith(
                                height: 1.6,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                      ),
                    ),

                  // Social action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        SocialActionsRow(app: app, author: author),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // Latest release panel
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'Latest Release',
                          style: AppTextStyles.h2.copyWith(color: c.white),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.gray33,
                            borderRadius: BorderRadius.circular(AppRadius.r16),
                          ),
                          child: latestMetadata != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Version',
                                          style: AppTextStyles.reg15.copyWith(
                                            color: c.white66,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          latestMetadata.version,
                                          style: AppTextStyles.semibold15
                                              .copyWith(color: c.white),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(${formatDate(latestMetadata.createdAt)})',
                                          style: AppTextStyles.reg13.copyWith(
                                            color: c.white33,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (latestRelease != null) ...[
                                      const SizedBox(height: 12),
                                      ReleaseNotes(release: latestRelease),
                                    ],
                                  ],
                                )
                              : const ReleaseNotesSkeleton(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppInfoTable(app: app, fileMetadata: latestMetadata),
                  ),

                  // Social tabs: Comments · Zaps · Labels · Details
                  const SizedBox(height: 16),
                  SocialTabs(
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
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No zaps yet')),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DebugVersionsSection(app: app),
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
// Fixed blurred detail header
// ─────────────────────────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.app,
    required this.author,
    required this.catalogProfile,
    required this.latestMetadata,
  });

  final App app;
  final Profile? author;
  final Profile? catalogProfile;
  final Installable? latestMetadata;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final topPad = MediaQuery.paddingOf(context).top;

    final publisherName = author?.name ?? _shortenPubkey(app.pubkey);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: c.black.withValues(alpha: 0.7),
          padding: EdgeInsets.fromLTRB(14, topPad + 10, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button
              GestureDetector(
                onTap: () => context.pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c.white8,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: AppIcon(
                      AppIcons.chevronLeft,
                      size: 16,
                      outlineColor: c.white66,
                      outlineThickness: 1.4,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Author avatar
              ProfilePic(profile: author, size: 28),

              const SizedBox(width: 8),

              // Publisher name
              Expanded(
                child: Text(
                  publisherName,
                  style: AppTextStyles.med15.copyWith(color: c.white66),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),

              // Release timestamp
              if (latestMetadata != null) ...[
                const SizedBox(width: 8),
                Text(
                  formatDate(latestMetadata!.createdAt),
                  style: AppTextStyles.reg13.copyWith(color: c.white33),
                ),
              ],

              // Zapstore catalog profile pic
              if (catalogProfile != null) ...[
                const SizedBox(width: 10),
                ProfilePic(profile: catalogProfile, size: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _shortenPubkey(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 6)}…${pubkey.substring(pubkey.length - 4)}';
  }
}
