import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zapstore/providers/comment_activity_feed_provider.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/detail_page_chrome.dart';
import 'package:zapstore/widgets/common/note_parser.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/relay_loading_bar.dart';
import 'package:zapstore/widgets/common/section_header.dart';
import 'package:zapstore/widgets/common/top_scroll_fader.dart';
import 'package:zapstore/widgets/profile/profile_browse_rows.dart';
import 'package:zapstore/widgets/community/comment_activity_feed.dart';
import 'package:zapstore/widgets/community/comment_card.dart';
import 'package:zapstore/widgets/community/lazy_mount_on_scroll.dart';
import 'package:zapstore/widgets/social/details_tab.dart';
import 'package:zapstore/widgets/zap_widgets.dart';

/// Public profile — layout mirrors app/stack/forum detail pages + webapp profile.
class UserScreen extends HookConsumerWidget {
  const UserScreen({super.key, required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final topPad = MediaQuery.paddingOf(context).top;

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
    final profileLoading = profileState is StorageLoading && profile == null;

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

    final apps = kTrustedRelayPubkeys.contains(pubkey)
        ? userAppsState.models.where((a) => a.isZapstoreApp).toList()
        : userAppsState.models;

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

    final displayName = profile?.name?.trim().isNotEmpty == true
        ? profile!.name!.trim()
        : detailShortPubkey(pubkey);

    final activityState = ref.watch(profileActivityCommentsProvider(pubkey));
    final activityVisible = ref.watch(profileActivityVisibleLimitProvider(pubkey));
    final activitySyncing =
        activityState is StorageLoading && activityState.models.isNotEmpty;

    final npub = Utils.encodeShareableFromString(pubkey, type: 'npub');

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TopScrollFader(
              scrollController: scrollController,
              fadeHeight: 48,
              safeEdgeFades: true,
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: topPad + 8,
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DetailAuthorMetaRow(
                      leading: ProfilePic(
                        profile: profile,
                        pubkey: pubkey,
                        size: kDetailAuthorAvatarSize,
                      ),
                      title: displayName,
                    ),

                    if (profile?.about?.trim().isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: _ProfileAbout(about: profile!.about!),
                      ),

                    if (apps.isNotEmpty) ...[
                      _UserZapsList(apps: apps),
                      ProfileAppsBrowseRow(apps: apps),
                    ],

                    if (stacks.isNotEmpty)
                      ProfileStacksBrowseRow(stacks: stacks),

                    const SectionHeader(title: 'Activity'),
                    if (activitySyncing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RelayLoadingBar(loading: activitySyncing),
                      ),

                    LazyMountOnScroll(
                      scrollController: scrollController,
                      mountOffset: 320,
                      placeholder: const CommentCardSkeletonList(rowCount: 3),
                      child: CommentActivityFeed(
                        scrollController: scrollController,
                        commentsState: activityState,
                        visibleLimit: activityVisible,
                        emptyMessage: profileLoading
                            ? 'Loading activity…'
                            : 'No activity yet',
                        onLoadMore: () => ref
                            .read(
                              profileActivityVisibleLimitProvider(pubkey).notifier,
                            )
                            .update(
                              (v) => v + kActivityFeedVisibleStep > kActivityFeedMaxVisible
                                  ? kActivityFeedMaxVisible
                                  : v + kActivityFeedVisibleStep,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          DetailActionsButtonOverlay(
            onTap: () => _showProfileActions(
              context,
              displayName: displayName,
              npub: npub,
              pubkey: pubkey,
              profile: profile,
            ),
            scrollController: scrollController,
            expandLabel: displayName,
          ),
        ],
      ),
    );
  }
}

void _showProfileActions(
  BuildContext context, {
  required String displayName,
  required String npub,
  required String pubkey,
  required Profile? profile,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = Theme.of(ctx).extension<LabColors>()!;
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        decoration: BoxDecoration(
          color: c.gray66,
          borderRadius: BorderRadius.circular(16),
          border: LabBorder.all(color: c.white16),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Share profile', style: LabTextStyles.med15),
                onTap: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(ShareParams(text: 'nostr:$npub'));
                },
              ),
              ListTile(
                title: Text('Details', style: LabTextStyles.med15),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => DraggableScrollableSheet(
                      initialChildSize: 0.6,
                      minChildSize: 0.4,
                      maxChildSize: 0.92,
                      builder: (context, scrollController) {
                        return Container(
                          decoration: BoxDecoration(
                            color: c.black,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(14),
                            child: DetailsTab(
                              publicationLabel: 'Profile',
                              npub: npub,
                              pubkey: pubkey,
                              rawData: profile?.event.content,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ProfileAbout extends HookWidget {
  const _ProfileAbout({required this.about});

  final String about;

  @override
  Widget build(BuildContext context) {
    final expanded = useState(false);
    const maxLines = 5;

    final content = NoteParser.parse(
      context,
      about,
      textStyle: LabTextStyles.reg15.copyWith(
        color: Theme.of(context).extension<LabColors>()!.white66,
        height: 1.5,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedCrossFade(
          firstChild: Text(
            about,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: LabTextStyles.reg15.copyWith(
              color: Theme.of(context).extension<LabColors>()!.white66,
              height: 1.5,
            ),
          ),
          secondChild: DefaultTextStyle(
            style: LabTextStyles.reg15.copyWith(
              color: Theme.of(context).extension<LabColors>()!.white66,
              height: 1.5,
            ),
            child: content,
          ),
          crossFadeState: expanded.value
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        if (!expanded.value && about.length > 180)
          TextButton(
            onPressed: () => expanded.value = true,
            child: const Text('Read more'),
          ),
      ],
    );
  }
}

class _UserZapsList extends HookConsumerWidget {
  const _UserZapsList({required this.apps});

  final List<App> apps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (apps.isEmpty) return const SizedBox.shrink();

    final allAppTags = <String, Set<String>>{};
    final metadataIds = <String>{};
    for (final app in apps) {
      final appTags = app.event.addressableIdTagMap;
      for (final entry in appTags.entries) {
        allAppTags[entry.key] = {...?allAppTags[entry.key], ...entry.value};
      }
      final metadata = app.installable;
      if (metadata != null) metadataIds.add(metadata.id);
    }

    final appZapsState = ref.watch(
      query<Zap>(
        tags: allAppTags,
        source: const LocalAndRemoteSource(relays: 'AppCatalog'),
        subscriptionPrefix: 'app-user-app-zaps',
      ),
    );

    final metadataZapsState = metadataIds.isNotEmpty
        ? ref.watch(
            query<Zap>(
              tags: {'#e': metadataIds},
              source: const LocalAndRemoteSource(relays: 'AppCatalog'),
              subscriptionPrefix: 'app-user-metadata-zaps',
            ),
          )
        : null;

    final allZaps = {
      ...appZapsState.models,
      if (metadataZapsState != null) ...metadataZapsState.models,
    };

    if (allZaps.isEmpty) return const SizedBox.shrink();

    final zapperPubkeys = <String>{};
    for (final zap in allZaps) {
      final zapperPubkey = zap.event.metadata['author'] as String?;
      if (zapperPubkey != null) zapperPubkeys.add(zapperPubkey);
    }

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
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: ZappersHorizontalList(
        zaps: allZaps.toList(),
        profilesMap: profilesMap,
      ),
    );
  }
}
