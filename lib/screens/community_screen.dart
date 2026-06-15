import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/providers/comment_activity_feed_provider.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/widgets/common/detail_page_chrome.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/relay_loading_bar.dart';
import 'package:zapstore/widgets/common/top_scroll_fader.dart';
import 'package:zapstore/widgets/community/comment_activity_feed.dart';
import 'package:zapstore/widgets/community/community_section_tabs.dart';
import 'package:zapstore/widgets/forum/forum_feed_container.dart';

/// Zapstore community hub — Forum + Activity feeds (webapp `/community` parity).
class CommunityScreen extends HookConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final topPad = MediaQuery.paddingOf(context).top;
    final activeTab = useState(CommunitySection.forum);
    final visited = useState(<CommunitySection>{CommunitySection.forum});

    void selectTab(CommunitySection tab) {
      activeTab.value = tab;
      visited.value = {...visited.value, tab};
    }

    final communityProfileState = ref.watch(
      query<Profile>(
        authors: {kZapstoreCommunityPubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          cachedFor: Duration(hours: 6),
        ),
        subscriptionPrefix: 'community-screen-profile',
      ),
    );
    final communityProfile = communityProfileState.models.firstOrNull;
    final communityName =
        communityProfile?.name?.trim().isNotEmpty == true
            ? communityProfile!.name!.trim()
            : 'Zapstore Community';

    final activityState = ref.watch(communityActivityCommentsProvider);
    final activityVisible = ref.watch(communityActivityVisibleLimitProvider);
    final activitySyncing =
        activityState is StorageLoading && activityState.models.isNotEmpty;

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
                        profile: communityProfile,
                        pubkey: kZapstoreCommunityPubkey,
                        size: kDetailAuthorAvatarSize,
                      ),
                      title: communityName,
                    ),

                    CommunitySectionTabs(
                      active: activeTab.value,
                      onChanged: selectTab,
                    ),

                    if (activeTab.value == CommunitySection.activity &&
                        activitySyncing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RelayLoadingBar(loading: activitySyncing),
                      ),

                    if (visited.value.contains(CommunitySection.forum))
                      Offstage(
                        offstage: activeTab.value != CommunitySection.forum,
                        child: _KeepAliveTab(
                          child: ForumFeedContainer(
                            scrollController: scrollController,
                          ),
                        ),
                      ),

                    if (visited.value.contains(CommunitySection.activity))
                      Offstage(
                        offstage: activeTab.value != CommunitySection.activity,
                        child: _KeepAliveTab(
                          child: CommentActivityFeed(
                            commentsState: activityState,
                            visibleLimit: activityVisible,
                            emptyMessage: 'No activity yet',
                            onLoadMore: () => ref
                                .read(
                                  communityActivityVisibleLimitProvider.notifier,
                                )
                                .update(
                                  (v) => v + kActivityFeedVisibleStep > kActivityFeedMaxVisible
                                      ? kActivityFeedMaxVisible
                                      : v + kActivityFeedVisibleStep,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Back affordance — top-left over scroll fade
          Positioned(
            top: topPad + 12,
            left: 14,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Theme.of(context).extension<LabColors>()!.white66,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});

  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
