import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/models/forum_post.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/l_connector.dart';
import 'package:zapstore/widgets/common/label.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/profile_pic_stack.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'package:zapstore/widgets/common/time_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ForumPostCard
// ─────────────────────────────────────────────────────────────────────────────
//
// Pixel-faithful port of webapp's ForumPostCard.svelte.
//
// Data strategy (mirrors app_detail_screen.dart):
//   • Author profile  — inline query<Profile> on social+vertex relays, 2h cache
//   • Comments        — inline query<Comment> (#E tag) on Zapstore relay
//     → derives commenter ProfilePicItems and reply count for the reply row
//
// Layout: left column (32px: avatar + connector) + right column (meta/title/
//         content/labels) + reply row with LabLConnector + ProfilePicStack.
//
// Avatar / column size: 32px (matches LabButton.tab height = 34, sits cleanly
// between xs=26 and small=34).
//
// Vertical line: drawn with LayoutBuilder so the Container receives an
// explicit pixel height (no loose-constraint collapse to 0px).
// Left column center = 16px → L-connector left padding = 16px so the
// connector's x=0.75 arm lands at ~16.75px ≈ dead center of the avatar.

class ForumPostCard extends HookConsumerWidget {
  const ForumPostCard({
    super.key,
    required this.post,
    this.onTap,
  });

  final ForumPost post;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    // ── Author profile ────────────────────────────────────────────────────────
    final profileState = ref.watch(
      query<Profile>(
        authors: {post.pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'forum-post-profile-${post.pubkey}',
      ),
    );
    final author = profileState.models.firstOrNull;

    // ── Comments — all levels via NIP-22 uppercase #E root tag ──────────────
    // No limit: all comments are fetched so (a) the count is accurate for the
    // full tree and (b) they land in SQLite cache for instant display when the
    // post screen opens.
    final commentsState = ref.watch(
      query<Comment>(
        tags: {'#E': {post.id}},
        source: const LocalAndRemoteSource(
          relays: kDefaultRelay,
          stream: false,
        ),
        subscriptionPrefix: 'forum-post-comments-${post.id}',
      ),
    );
    final comments = commentsState.models;

    // ── Zaps with content (text zaps count toward engagement total) ───────────
    final zapsState = ref.watch(
      query<Zap>(
        tags: {'#e': {post.id}},
        source: const LocalAndRemoteSource(
          relays: kDefaultRelay,
          stream: false,
        ),
        subscriptionPrefix: 'forum-post-card-zaps-${post.id}',
      ),
    );
    final zapsWithContent = zapsState.models
        .where((z) => z.event.content.trim().isNotEmpty)
        .toList();

    // Total engagement = all comments in tree + zaps with content
    final totalCount = comments.length + zapsWithContent.length;

    // De-duplicate commenter pubkeys and build ProfilePicItems
    final seen = <String>{};
    final uniqueCommenterPubkeys = <String>{};
    final commenters = <ProfilePicItem>[];
    for (final c in comments) {
      if (seen.add(c.event.pubkey)) {
        uniqueCommenterPubkeys.add(c.event.pubkey);
        commenters.add(ProfilePicItem(pubkey: c.event.pubkey));
        if (commenters.length >= 3) break;
      }
    }

    // Fetch profiles for commentors so the ProfilePicStack renders real avatars
    final commenterProfilesState = uniqueCommenterPubkeys.isNotEmpty
        ? ref.watch(
            query<Profile>(
              authors: uniqueCommenterPubkeys,
              source: const LocalAndRemoteSource(
                relays: {'social', 'vertex'},
                stream: false,
                cachedFor: Duration(hours: 2),
              ),
              subscriptionPrefix: 'fpc-commenters-${post.id}',
            ),
          )
        : null;

    final commenterProfiles = {
      for (final p in commenterProfilesState?.models ?? <Profile>[])
        p.pubkey: p,
    };

    final commentersWithProfiles = commenters
        .map((item) => ProfilePicItem(
              pubkey: item.pubkey,
              profile:
                  item.pubkey != null ? commenterProfiles[item.pubkey] : null,
            ))
        .toList();

    final showReplyRow = totalCount > 0;

    final title = post.title;
    final content = post.content;
    final labels = post.topics.toList();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: c.white11, width: 0.33),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row ───────────────────────────────────────────────────────
            // IntrinsicHeight + CrossAxisAlignment.stretch so the left column
            // fills the right column's height → the vertical connector line
            // extends all the way down to where the reply row begins.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: avatar + vertical connector.
                  // Stack approach avoids LayoutBuilder inside IntrinsicHeight
                  // (LayoutBuilder receives unbounded constraints during the
                  // intrinsic-sizing pass → crash). Instead, the ProfilePic is
                  // a non-positioned child (sets the Stack's intrinsic height to
                  // 32px for the Row's measurement pass), while the Positioned
                  // line uses bottom:0 to fill whatever stretched height the Row
                  // later assigns (right-column height). No LayoutBuilder needed.
                  SizedBox(
                    width: 32,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: ProfilePic(
                            profile: author,
                            pubkey: post.pubkey,
                            size: 32,
                          ),
                        ),
                        if (showReplyRow)
                          Positioned(
                            top: 33,   // 32px avatar + 1px gap
                            bottom: 0,
                            left: 15.25, // (32 − 1.5) / 2 = centre
                            width: 1.5,
                            child: ColoredBox(color: c.white16),
                          ),
                      ],
                    ),
                  ),
                  // Right: meta + title + content + labels
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Meta row: author name + timestamp
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  author?.name ??
                                      '${post.pubkey.substring(0, 10)}…',
                                  style: LabTextStyles.med15
                                      .copyWith(color: c.white66),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TimeAgoText(
                                post.createdAt,
                                style: LabTextStyles.reg13
                                    .copyWith(color: c.white33),
                              ),
                            ],
                          ),
                          if (title != null && title.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: LabTextStyles.semibold17
                                  .copyWith(color: c.white),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (content.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              content,
                              style: LabTextStyles.reg15
                                  .copyWith(color: c.white66),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (labels.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _LabelsRow(labels: labels),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Reply row ─────────────────────────────────────────────────────
            // Offset by left-column center (16px) so the L-connector arm
            // aligns directly below the avatar centre above.
            if (showReplyRow)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // L-connector: bottom padding = avatarSize/2 = 16px so the
                    // horizontal arm tip aligns with the ProfilePicStack centres.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: 27,
                        height: 28,
                        child: LabLConnector(color: c.white16),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child:                         ProfilePicStack(
                          profiles: commentersWithProfiles,
                          text: _stackText(commentersWithProfiles, totalCount),
                          suffix: totalCount > 0 ? totalCount.toString() : '',
                          avatarSize: 24,
                          onTap: onTap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _stackText(List<ProfilePicItem> items, int totalCount) {
    if (items.isEmpty) return '';
    final name0 = items[0].profile?.name ?? 'Someone';
    if (items.length == 1 && totalCount <= 1) return name0;
    if (items.length == 2 && totalCount == 2) {
      return '$name0 & ${items[1].profile?.name ?? 'Someone'}';
    }
    return '$name0 & ${totalCount - 1} Others';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Labels row — scrollable, edge-faded, using LabLabel
// ─────────────────────────────────────────────────────────────────────────────

class _LabelsRow extends HookWidget {
  const _LabelsRow({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scrollController = useScrollController();
    final isScrolled = useState(false);

    useEffect(() {
      void listener() {
        final atStart = scrollController.offset <= 0;
        if (isScrolled.value == atStart) {
          isScrolled.value = !atStart;
        }
      }
      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController]);

    final leftStop = isScrolled.value ? 0.03 : 0.0;

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: [0.0, leftStop, 0.92, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: labels
              .map(
                (label) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: LabLabel(label, size: LabLabelSize.small),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Zap pill — reserved for when zap totals are surfaced on forum posts
// ─────────────────────────────────────────────────────────────────────────────
// ignore: unused_element
class _ZapPill extends StatelessWidget {
  const _ZapPill({required this.amount, required this.c});

  final int amount;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.only(left: 8, right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const RadialGradient(
          center: Alignment(-0.8, -0.8),
          radius: 1.8,
          colors: [Color(0x24FFC736), Color(0x14FFA037)],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LabIcon(LabIcons.zap, size: 12, color: const Color(0xFFFFD060)),
          const SizedBox(width: 4),
          Text(
            _formatSats(amount),
            style: LabTextStyles.semibold13.copyWith(color: c.white),
          ),
        ],
      ),
    );
  }

  static String _formatSats(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    }
    return n.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ForumPostCardSkeleton — shimmer placeholder matching the live layout
// ─────────────────────────────────────────────────────────────────────────────
//
// Per DESIGN_SYSTEM.md:
//   • Shimmer for primary content (avatar, title)
//   • Static white8 bones for secondary content (author name, body lines)
// Layout mirrors ForumPostCard exactly: left column + right column + reply row.

class ForumPostCardSkeleton extends StatelessWidget {
  const ForumPostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.white11, width: 0.33),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ───────────────────────────────────────────────────────
          // Mirrors the real card: IntrinsicHeight + stretch so the connector
          // line in the left Stack fills the right column's natural height.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: avatar + vertical connector (Stack, same as real card)
                SizedBox(
                  width: 32,
                  child: Stack(
                    children: [
                      const Align(
                        alignment: Alignment.topCenter,
                        child: Shimmer(width: 32, height: 32, isCircle: true),
                      ),
                      Positioned(
                        top: 33,
                        bottom: 0,
                        left: 15.25,
                        width: 1.5,
                        child: ColoredBox(color: c.white16),
                      ),
                    ],
                  ),
                ),
                // Right: meta + title + body bones
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Meta row
                        Row(
                          children: [
                            _Bone(width: 100, height: 13, c: c),
                            const Spacer(),
                            _Bone(width: 36, height: 11, c: c),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Title — primary shimmer
                        const Shimmer(width: 200, height: 17),
                        const SizedBox(height: 5),
                        // Body line 1
                        _Bone(width: double.infinity, height: 13, c: c),
                        const SizedBox(height: 4),
                        // Body line 2 (shorter)
                        _Bone(width: 140, height: 13, c: c),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Reply row ─────────────────────────────────────────────────────
          // Padding(left:16) mirrors the real card; gap after L-connector = 2px.
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: 27,
                    height: 28,
                    child: LabLConnector(color: c.white16),
                  ),
                ),
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar stack — matches ProfilePicStack(avatarSize:24, overlap:8)
                      // width = 24 + 2*(24-8) = 56
                      SizedBox(
                        width: 56,
                        height: 24,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              child: _Bone(
                                  width: 24, height: 24, c: c, isCircle: true),
                            ),
                            Positioned(
                              left: 16,
                              child: _Bone(
                                  width: 24, height: 24, c: c, isCircle: true),
                            ),
                            Positioned(
                              left: 32,
                              child: _Bone(
                                  width: 24, height: 24, c: c, isCircle: true),
                            ),
                          ],
                        ),
                      ),
                      // Pill bone — overlaps stack by 8px, matching ProfilePicStack pill
                      Transform.translate(
                        offset: const Offset(-8, 0),
                        child: _Bone(
                            width: 80, height: 24, c: c, isCircle: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Static (non-animated) secondary-content bone. r17 by default, or circle.
class _Bone extends StatelessWidget {
  const _Bone({
    required this.width,
    required this.height,
    required this.c,
    this.isCircle = false,
  });

  final double width;
  final double height;
  final LabColors c;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        color: c.white8,
        borderRadius: isCircle
            ? BorderRadius.circular(height / 2)
            : BorderRadius.circular(LabRadius.r17),
      ),
    );
  }
}
