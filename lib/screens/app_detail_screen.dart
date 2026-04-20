import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/debug_utils.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/widgets/app_detail_widgets.dart';
import 'package:zapstore/widgets/app_header.dart';
import 'package:zapstore/widgets/comments_section.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/profile_pic_stack.dart';
import 'package:zapstore/widgets/expandable_markdown.dart';
import 'package:zapstore/widgets/screenshots_gallery.dart';
import 'package:zapstore/widgets/social/details_tab.dart';
import 'package:zapstore/widgets/social/social_tabs.dart';

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

    // Security panel: matches webapp's publishedByDeveloper / hasRepository logic.
    // isRelaySigned == published by indexer (not the developer)
    final publishedByDeveloper = !app.isRelaySigned;
    final hasRepository = app.repository?.isNotEmpty == true;

    // Use a Stack so the scroll view sits *behind* the header. This lets the
    // ShaderMask fade on the header's bottom actually reveal scrolling content
    // rather than just the Scaffold background.
    final topPad = MediaQuery.paddingOf(context).top;
    final scrollTopPad = topPad + 50.0; // safe-area + header row (≈38px) + fade zone (12px)

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-body scrollable content (behind the floating header) ────
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                top: scrollTopPad,
                bottom: MediaQuery.paddingOf(context).bottom + 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App header (pic + name + platform pill + install button)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: AppHeader(app: app),
                  ),

                  // Screenshots gallery
                  if (app.images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                          p: AppTextStyles.reg15.copyWith(
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
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    child: _InfoPanels(
                      publishedByDeveloper: publishedByDeveloper,
                      hasRepository: hasRepository,
                      latestRelease: latestRelease,
                      latestMetadata: latestMetadata,
                    ),
                  ),

                  // Social tabs: Comments · Zaps · Labels · Details
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
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: DebugVersionsSection(app: app),
                    ),
                ],
              ),
            ),
          ),

          // ── Floating blurred header (on top, fades into content below) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _DetailHeader(
              app: app,
              author: author,
              catalogProfile: catalogProfile,
              latestMetadata: latestMetadata,
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

    // Build community stack — one item for Zapstore catalog, extensible later.
    final communityItems = [
      if (catalogProfile != null)
        ProfilePicItem(profile: catalogProfile),
    ];

    // Wrap the blurred header in a ShaderMask that fades the bottom 12 px to
    // transparent, creating a gradient transition into the scrollable content.
    return ShaderMask(
      shaderCallback: (rect) {
        final fadeStart = (rect.height - 12) / rect.height;
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, fadeStart.clamp(0.0, 1.0), 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            color: c.black.withValues(alpha: 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Safe-area inset + reduced top padding (max 8px above content).
                SizedBox(height: topPad + 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Back button — gray33 bg, white33 chevron
                      GestureDetector(
                        onTap: () => context.pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: c.gray33,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: AppIcon(
                                AppIcons.chevronLeft,
                                size: 14,
                                outlineColor: c.white33,
                                outlineThickness: 1.4,
                              ),
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

                      // Release timestamp — webapp Timestamp.svelte format
                      if (latestMetadata != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(latestMetadata!.createdAt),
                          style: AppTextStyles.reg13.copyWith(color: c.white33),
                        ),
                      ],

                      // Community stack: overlapping avatars + count pill
                      // (same pill style as ProfilePicStack in root_comment.dart)
                      if (communityItems.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        ProfilePicStack(
                          profiles: communityItems,
                          avatarSize: 22,
                          suffix: '${communityItems.length}',
                        ),
                      ],
                    ],
                  ),
                ),
                // 12 px space that the ShaderMask fades out — zero explicit padding.
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _shortenPubkey(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 6)}…${pubkey.substring(pubkey.length - 4)}';
  }

  static String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just Now';

    final today = DateTime(now.year, now.month, now.day);
    final dtDay = DateTime(dt.year, dt.month, dt.day);

    if (dtDay == today) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Today $h:$m';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (dtDay == yesterday) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final base = '${months[dt.month - 1]} ${dt.day}';
    return dt.year != now.year ? '$base ${dt.year}' : base;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info panels row: Security (golden-ratio wider) + Releases
// ─────────────────────────────────────────────────────────────────────────────

class _InfoPanels extends StatelessWidget {
  const _InfoPanels({
    required this.publishedByDeveloper,
    required this.hasRepository,
    this.latestRelease,
    this.latestMetadata,
  });

  final bool publishedByDeveloper;
  final bool hasRepository;
  final dynamic latestRelease;
  final Installable? latestMetadata;

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
            ),
          ),
          const SizedBox(width: 12),
          // Releases panel: flex 5 ≈ 38.5%
          Expanded(
            flex: 5,
            child: _ReleasesPanel(
              latestRelease: latestRelease,
              latestMetadata: latestMetadata,
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
  });

  final bool publishedByDeveloper;
  final bool hasRepository;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

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
      onTap: () {}, // TODO: open security modal
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        decoration: BoxDecoration(
          color: c.white8,
          borderRadius: BorderRadius.circular(AppRadius.r16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security',
              style: AppTextStyles.semibold15.copyWith(color: c.white),
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
                              ? AppIcon(
                                  AppIcons.check,
                                  size: 13,
                                  outlineColor: c.blurpleColor,
                                  outlineThickness: 2.8,
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
                            style: AppTextStyles.reg13.copyWith(
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
  const _ReleasesPanel({this.latestRelease, this.latestMetadata});

  final dynamic latestRelease;
  final Installable? latestMetadata;

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
    final c = Theme.of(context).extension<AppColors>()!;

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
      onTap: () {}, // TODO: open releases modal
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        decoration: BoxDecoration(
          color: c.white8,
          borderRadius: BorderRadius.circular(AppRadius.r16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Releases',
              style: AppTextStyles.semibold15.copyWith(color: c.white),
            ),
            const SizedBox(height: 4),
            if (rows.isEmpty)
              Text(
                'No releases found.',
                style: AppTextStyles.reg13.copyWith(color: c.white33),
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
                            style: AppTextStyles.med13.copyWith(
                              color: c.white33,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              rows[i].preview.isEmpty ? 'No notes' : rows[i].preview,
                              style: AppTextStyles.reg13.copyWith(
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

