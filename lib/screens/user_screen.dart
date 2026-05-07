import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zapstore/widgets/common/stack_link_card.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import '../theme.dart';
import '../widgets/common/note_parser.dart';
import '../widgets/common/profile_identity_row.dart';
import '../widgets/app_card.dart';
import '../widgets/zap_widgets.dart';
import '../widgets/common/top_scroll_fader.dart';

/// User profile screen - shows any user/developer profile
class UserScreen extends HookConsumerWidget {
  const UserScreen({super.key, required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final topPad = MediaQuery.paddingOf(context).top;
    final headerHeight = topPad + 48.0;

    // Load user profile
    final profileState = ref.watch(
      query<Profile>(
        authors: {pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'app-user-profile',
      ),
    );
    final profile = profileState.models.firstOrNull;

    // Query user's apps
    final userAppsState = ref.watch(
      query<App>(
        authors: {pubkey},
        tags: {
          '#f': {'android-arm64-v8a'},
        },
        limit: 20,
        and: (app) => {
          app.latestAsset.query(),
          app.latestRelease.query(
            and: (release) => {
              release.latestMetadata.query(),
              release.latestAsset.query(),
            },
          ),
        },
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: false),
        subscriptionPrefix: 'app-user-apps',
      ),
    );

    // For trusted relay pubkeys, only show Zapstore's own apps (not relay-signed ones)
    final apps = kTrustedRelayPubkeys.contains(pubkey)
        ? userAppsState.models.where((a) => a.isZapstoreApp).toList()
        : userAppsState.models;

    // Query user's app stacks
    final appStacksState = ref.watch(
      query<AppStack>(
        authors: {pubkey},
        limit: 20,
        and: (pack) => {
          pack.apps.query(
            source: const LocalAndRemoteSource(stream: false),
            subscriptionPrefix: 'app-user-screen-stack-apps',
          ),
        },
        source: LocalAndRemoteSource(stream: false, relays: 'AppCatalog'),
        subscriptionPrefix: 'app-user-stacks',
        schemaFilter: appStackEventFilter,
      ),
    );
    final stacks = appStacksState.models.toList()
      ..sort((a, b) => b.event.createdAt.compareTo(a.event.createdAt));

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-body scrollable content (behind the floating header) ─────
          Positioned.fill(
            child: TopScrollFader(
              scrollController: scrollController,
              fadeStart: headerHeight,
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: headerHeight + 10,
                  bottom: MediaQuery.paddingOf(context).bottom + 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with avatar and name
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _UserHeader(
                        profile: profile,
                        pubkey: pubkey,
                        isLoading:
                            profileState is StorageLoading && profile == null,
                      ),
                    ),

                    // Zaps widget
                    _UserZapsList(apps: apps),

                    // Bio section with max height
                    if (profile?.about != null && profile!.about!.isNotEmpty)
                      _UserBio(profile: profile),

                    // Apps section - only show if apps exist
                    if (apps.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text(
                          'Published Apps',
                          style: context.textTheme.titleLarge,
                        ),
                      ),
                      ...apps.map((app) => AppCard(app: app, showSignedBy: false)),
                    ],

                    // App stacks section - only show if stacks exist
                    if (stacks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                        child: Text(
                          'App Stacks',
                          style: context.textTheme.headlineMedium,
                        ),
                      ),
                      ...stacks.map(
                        (stack) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: StackLinkCard(stack: stack),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Floating blurred header (on top) ──────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _UserDetailHeader(pubkey: pubkey),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating blurred detail header
// ─────────────────────────────────────────────────────────────────────────────

class _UserDetailHeader extends StatelessWidget {
  const _UserDetailHeader({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final topPad = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: c.black.withValues(alpha: 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: topPad + 9),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 9),
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
                          color: c.gray33,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: LabIcon(
                              LabIcons.chevronLeft,
                              size: 14,
                              color: c.white33,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Title
                    Expanded(
                      child: Text(
                        'Profile',
                        style: LabTextStyles.semibold23.copyWith(color: c.white),
                      ),
                    ),

                    // Share button
                    GestureDetector(
                      onTap: () {
                        final npub = Utils.encodeShareableFromString(
                          pubkey,
                          type: 'npub',
                        );
                        SharePlus.instance
                            .share(ShareParams(text: 'nostr:$npub'));
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: c.gray33,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: LabIcon(
                            LabIcons.shareFill,
                            size: 14,
                            color: c.white33,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile identity row (avatar + name + npub)
// ─────────────────────────────────────────────────────────────────────────────

class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.profile,
    required this.pubkey,
    this.isLoading = false,
  });

  final Profile? profile;
  final String pubkey;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ProfileIdentityRow(
        pubkey: pubkey,
        profile: profile,
        isLoading: isLoading,
        avatarRadius: 40,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Zaps list
// ─────────────────────────────────────────────────────────────────────────────

class _UserZapsList extends HookConsumerWidget {
  const _UserZapsList({required this.apps});

  final List<App> apps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Don't query zaps if user has no apps
    if (apps.isEmpty) {
      return const SizedBox.shrink();
    }

    // Collect addressable tags for apps and metadata IDs
    final allAppTags = <String, Set<String>>{};
    final metadataIds = <String>{};
    for (final app in apps) {
      final appTags = app.event.addressableIdTagMap;
      for (final entry in appTags.entries) {
        allAppTags[entry.key] = {...?allAppTags[entry.key], ...entry.value};
      }
      final metadata = app.installable;
      if (metadata != null) {
        metadataIds.add(metadata.id);
      }
    }

    // Query zaps on apps (via #a tag)
    final appZapsState = ref.watch(
      query<Zap>(
        tags: allAppTags,
        source: const LocalAndRemoteSource(relays: 'AppCatalog'),
        subscriptionPrefix: 'app-user-app-zaps',
      ),
    );

    // Query zaps on metadata (via #e tag) - for legacy compatibility
    final metadataZapsState = metadataIds.isNotEmpty
        ? ref.watch(
            query<Zap>(
              tags: {'#e': metadataIds},
              source: const LocalAndRemoteSource(relays: 'AppCatalog'),
              subscriptionPrefix: 'app-user-metadata-zaps',
            ),
          )
        : null;

    // Combine zaps from both queries
    final allZaps = {
      ...appZapsState.models,
      if (metadataZapsState != null) ...metadataZapsState.models,
    };

    if (allZaps.isEmpty) {
      return const SizedBox.shrink();
    }

    // Collect zapper pubkeys from metadata (already extracted from description tag)
    final zapperPubkeys = <String>{};
    for (final zap in allZaps) {
      final zapperPubkey = zap.event.metadata['author'] as String?;
      if (zapperPubkey != null) {
        zapperPubkeys.add(zapperPubkey);
      }
    }

    // Query profiles separately with cachedFor
    final profilesState = ref.watch(
      query<Profile>(
        authors: zapperPubkeys,
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'app-user-profiles',
      ),
    );
    final profilesMap = {for (final p in profilesState.models) p.pubkey: p};

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ZappersHorizontalList(
        zaps: allZaps.toList(),
        profilesMap: profilesMap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bio section
// ─────────────────────────────────────────────────────────────────────────────

class _UserBio extends HookWidget {
  const _UserBio({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final expanded = useState(false);
    const maxHeight = 120.0;

    bool isLikelyLong(String text) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) return false;

      final wordCount = trimmed.split(RegExp(r'\s+')).length;
      final newlineCount = '\n'.allMatches(trimmed).length;
      final charCount = trimmed.length;

      return wordCount > 50 || newlineCount > 4 || charCount > 350;
    }

    final about = profile.about ?? '';
    final shouldCollapse = !expanded.value && isLikelyLong(about);

    final bioContent = NoteParser.parse(
      context,
      about,
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        height: 1.5,
        color: LabColors.darkOnSurfaceSecondary,
      ),
      linkStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        height: 1.5,
        color: Theme.of(context).colorScheme.primary,
      ),
      onNostrEntity: (entity) => NostrEntityWidget(
        entity: entity,
        colorPair: [
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.secondary,
        ],
      ),
    );

    if (!shouldCollapse) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: bioContent,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: maxHeight),
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0.0, 0.7, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: bioContent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => expanded.value = true,
              child: Text(
                'Read more',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
