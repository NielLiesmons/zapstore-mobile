import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/widgets/common/empty_state.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'package:zapstore/widgets/social/root_comment.dart';
import 'package:zapstore/widgets/social/zap_comment_item.dart';
import 'package:zapstore/widgets/social/comment_feed_composer.dart';
import 'package:zapstore/widgets/modals/comment_modal.dart';
import 'package:zapstore/services/nostr_comment_service.dart';
import 'package:zapstore/widgets/social/thread_root.dart';

/// Tab badge + relay-bar stats derived from a comments [StorageState].
CommentFeedTabMeta commentFeedTabMeta(StorageState<Comment> state) {
  final models = state.models;
  final rootCount = models.where((c) => c.parentKind != 1111).length;
  return CommentFeedTabMeta(
    count: rootCount,
    initialLoading: state is StorageLoading && models.isEmpty,
    syncing: state is StorageLoading && models.isNotEmpty,
  );
}

class CommentFeedTabMeta {
  const CommentFeedTabMeta({
    required this.count,
    required this.initialLoading,
    required this.syncing,
  });

  final int count;
  final bool initialLoading;
  final bool syncing;
}

/// A merged feed entry: either a root [Comment] or a [Zap] with a comment.
class _FeedEntry {
  const _FeedEntry({required this.createdAt, this.comment, this.zap})
      : assert(comment != null || zap != null);

  final DateTime createdAt;
  final Comment? comment;
  final Zap? zap;
}

/// Comments section for App detail screen — includes zaps with comments.
class CommentsSection extends ConsumerWidget {
  const CommentsSection({super.key, required this.app, this.fileMetadata});

  final App app;
  final Installable? fileMetadata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (fileMetadata == null) {
      return const SizedBox.shrink();
    }

    final commentsState = ref.watch(
      query<Comment>(
        tags: {'#A': {app.id}},
        source: LocalAndRemoteSource(stream: true, relays: 'AppCatalog'),
        subscriptionPrefix: 'app-comments',
      ),
    );

    final zapsState = ref.watch(
      query<Zap>(
        tags: app.event.addressableIdTagMap,
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: true),
        subscriptionPrefix: 'app-comments-zaps-${app.id}',
      ),
    );

    final comments = commentsState.models;
    final zapModels = zapsState.models;
    final errorException = switch (commentsState) {
      StorageError(:final exception) => exception,
      _ => null,
    };

    return _CommentsSectionLayout(
      comments: comments,
      zapsWithComments: zapModels
          .where((z) => z.event.content.trim().isNotEmpty)
          .toList(),
      errorException: errorException,
      isLoading: commentsState is StorageLoading && comments.isEmpty,
      app: app,
      fileMetadata: fileMetadata!,
    );
  }
}

/// Comments section for AppStack/Stack detail screen — includes zaps with comments.
class StackCommentsSection extends ConsumerWidget {
  const StackCommentsSection({super.key, required this.stack});

  final AppStack stack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsState = ref.watch(
      query<Comment>(
        tags: {'#A': {stack.id}},
        source: LocalAndRemoteSource(stream: true, relays: 'AppCatalog'),
        subscriptionPrefix: 'app-stack-comments',
      ),
    );

    final zapsState = ref.watch(
      query<Zap>(
        tags: stack.event.addressableIdTagMap,
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: true),
        subscriptionPrefix: 'stack-comments-zaps-${stack.id}',
      ),
    );

    final comments = commentsState.models;
    final zapModels = zapsState.models;
    final errorException = switch (commentsState) {
      StorageError(:final exception) => exception,
      _ => null,
    };

    return _CommentsSectionLayout(
      comments: comments,
      zapsWithComments: zapModels
          .where((z) => z.event.content.trim().isNotEmpty)
          .toList(),
      errorException: errorException,
      isLoading: commentsState is StorageLoading && comments.isEmpty,
      stack: stack,
    );
  }
}

/// Shared layout for both App and Stack comments — renders a merged feed
/// of root [Comment]s and [Zap]s that carry a comment, sorted newest first.
class _CommentsSectionLayout extends ConsumerWidget {
  const _CommentsSectionLayout({
    required this.comments,
    this.zapsWithComments = const [],
    required this.errorException,
    this.isLoading = false,
    this.app,
    this.fileMetadata,
    this.stack,
  });

  final List<Comment> comments;
  final List<Zap> zapsWithComments;
  final Object? errorException;
  final bool isLoading;
  final App? app;
  final Installable? fileMetadata;
  final AppStack? stack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootComments = comments.where((c) => c.parentKind != 1111).toList();
    final inlineRootId = singleRootCommentId(comments);

    // Merge root comments and zaps-with-comments, sorted newest first.
    final entries = <_FeedEntry>[
      ...rootComments.map((c) => _FeedEntry(createdAt: c.createdAt, comment: c)),
      ...zapsWithComments.map((z) => _FeedEntry(createdAt: z.createdAt, zap: z)),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    Widget? composer;
    if (app != null && fileMetadata != null) {
      composer = CommentFeedComposer(
        ctaLabel: 'Your Comment',
        onTap: () => showCommentModal(
          context,
          placeholder: 'Comment on ${app!.name ?? 'this app'}…',
          rootContext: ThreadRootContext.fromApp(
            app!,
            version: fileMetadata!.version,
          ),
          version: fileMetadata!.version,
          showRootConnector: true,
          onSubmit: (result) => publishRootComment(
            ref: ref,
            result: result,
            app: app!,
            version: fileMetadata!.version,
          ),
        ),
      );
    } else if (stack != null) {
      composer = CommentFeedComposer(
        ctaLabel: 'Your Comment',
        onTap: () => showCommentModal(
          context,
          placeholder: 'Comment on ${stack!.name ?? 'this stack'}…',
          rootContext: ThreadRootContext.fromStack(stack!),
          showRootConnector: true,
          onSubmit: (result) => publishRootComment(
            ref: ref,
            result: result,
            stack: stack!,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (composer != null) composer,
        if (errorException != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildCommentsError(context, errorException!),
          ),

        if (entries.isEmpty)
          if (isLoading)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: BubbleSkeletonList(),
            )
          else
            const EmptyState(message: 'No comments yet', minHeight: 120)
        else
          Column(
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                if (entries[i].comment != null)
                  RootComment(
                    comment: entries[i].comment!,
                    rootContext: app != null
                        ? ThreadRootContext.fromApp(
                            app!,
                            version: fileMetadata?.version,
                          )
                        : stack != null
                            ? ThreadRootContext.fromStack(stack!)
                            : null,
                    version: fileMetadata?.version,
                    inlineThreadReplies:
                        entries[i].comment!.id == inlineRootId,
                  )
                else
                  ZapCommentItem(
                    zap: entries[i].zap!,
                    topPadding: i == 0 ? 0 : 4,
                  ),
              ],
            ],
          ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCommentsError(BuildContext context, Object exception) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Failed to load comments',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
