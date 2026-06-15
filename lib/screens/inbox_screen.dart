import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/providers/inbox_seen_provider.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/empty_state.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'package:zapstore/widgets/common/top_scroll_fader.dart';
import 'package:zapstore/widgets/community/comment_card.dart';
import 'package:zapstore/widgets/modals/actions_modal.dart';
import 'package:zapstore/widgets/social/root_comment.dart';

/// Max kind-1111 comments to load (any `p` tag matching the inbox owner), from Zapstore relay only.
const int kInboxReplyLimit = 20;

/// Same [query] arguments must be used everywhere so Riverpod de-dupes the subscription.
AutoDisposeStateNotifierProvider<RequestNotifier<Comment>, StorageState<Comment>>
    inboxRepliesProvider(String pubkey) {
  return query<Comment>(
    tags: {'#p': {pubkey}},
    limit: kInboxReplyLimit,
    where: (comment) =>
        comment.event.getTagSetValues('p').contains(pubkey),
    source: const LocalAndRemoteSource(
      relays: kDefaultRelay,
      stream: true,
    ),
    subscriptionPrefix: 'app-inbox-zapstore-relay-$pubkey',
  );
}

/// Full-screen inbox: kind-1111 comments that `p`-tag you, from [kDefaultRelay] only.
class InboxScreen extends HookConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final topPad = MediaQuery.paddingOf(context).top;
    final headerHeight = topPad + 48.0;
    final colors = Theme.of(context).extension<LabColors>()!;

    final pubkey = ref.watch(Signer.activePubkeyProvider);

    useEffect(() {
      if (pubkey != null) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pop();
      });
      return null;
    }, [pubkey]);

    if (pubkey == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final commentsState = ref.watch(inboxRepliesProvider(pubkey));
    final comments = List<Comment>.from(commentsState.models)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final loadingGate = useState(false);
    useEffect(() {
      final timer = Timer(const Duration(milliseconds: 100), () {
        loadingGate.value = true;
      });
      return timer.cancel;
    }, []);

    final List<Widget> emptyBodyChildren;
    if (commentsState is StorageError) {
      emptyBodyChildren = [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Could not load inbox.',
            style: LabTextStyles.reg15.copyWith(color: colors.rougeColor),
          ),
        ),
      ];
    } else if (commentsState is StorageLoading && loadingGate.value) {
      emptyBodyChildren = const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: CommentCardSkeletonList(rowCount: 5),
        ),
      ];
    } else {
      emptyBodyChildren = const [
        EmptyState(
          message:
              'Nothing here yet. When someone comments on Zapstore, it shows up here.',
          minHeight: 200,
        ),
      ];
    }

    return ShimmerTheme(
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: TopScrollFader(
                scrollController: scrollController,
                fadeStart: headerHeight,
                child: comments.isEmpty
                    ? ListView(
                        controller: scrollController,
                        padding: EdgeInsets.only(
                          top: headerHeight + 10,
                          bottom: MediaQuery.paddingOf(context).bottom + 32,
                        ),
                        children: emptyBodyChildren,
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: EdgeInsets.only(
                          top: headerHeight + 10,
                          left: 14,
                          right: 14,
                          bottom: MediaQuery.paddingOf(context).bottom + 32,
                        ),
                        itemCount: comments.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: kCommentCardListGap),
                        itemBuilder: (context, i) {
                          final comment = comments[i];
                          final eventId = comment.event.id;
                          void markSeen() => ref
                              .read(inboxSeenProvider(pubkey).notifier)
                              .markSeen([eventId]);
                          return CommentCard(
                            comment: comment,
                            inboxOwnerPubkey: pubkey,
                            onCardTap: () {
                              markSeen();
                              showThreadModal(
                                context,
                                ref,
                                comment: comment,
                              );
                            },
                            onReply: () {
                              markSeen();
                              showThreadModal(
                                context,
                                ref,
                                comment: comment,
                                initialExpand: true,
                              );
                            },
                            onActions: () {
                              markSeen();
                              showCommentActionsModal(
                                context,
                                comment: comment,
                                ref: ref,
                              );
                            },
                          );
                        },
                      ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _InboxHeader(
                onMarkAllRead: comments.isNotEmpty
                    ? () => ref
                        .read(inboxSeenProvider(pubkey).notifier)
                        .markSeen(comments.map((c) => c.event.id))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxHeader extends StatelessWidget {
  const _InboxHeader({this.onMarkAllRead});

  final VoidCallback? onMarkAllRead;

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
                    Text(
                      'Inbox',
                      style: LabTextStyles.semibold23.copyWith(color: c.white),
                    ),
                    const Spacer(),
                    if (onMarkAllRead != null)
                      GestureDetector(
                        onTap: onMarkAllRead,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          'Mark all as read',
                          style: LabTextStyles.reg11.copyWith(color: c.white33),
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

