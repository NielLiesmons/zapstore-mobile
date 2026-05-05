import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/widgets/common/empty_state.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'package:zapstore/widgets/social/root_comment.dart';
import 'package:zapstore/widgets/social/zap_comment_item.dart';

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

    final comments = switch (commentsState) {
      StorageData(:final models) => models,
      _ => <Comment>[],
    };
    final zapModels = switch (zapsState) {
      StorageData(:final models) => models,
      _ => <Zap>[],
    };
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
      isLoading: commentsState is StorageLoading,
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

    final comments = switch (commentsState) {
      StorageData(:final models) => models,
      _ => <Comment>[],
    };
    final zapModels = switch (zapsState) {
      StorageData(:final models) => models,
      _ => <Zap>[],
    };
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
      isLoading: commentsState is StorageLoading,
      stack: stack,
    );
  }
}

/// Shared layout for both App and Stack comments — renders a merged feed
/// of root [Comment]s and [Zap]s that carry a comment, sorted newest first.
class _CommentsSectionLayout extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final rootComments = comments.where((c) => c.parentKind != 1111).toList();

    // Merge root comments and zaps-with-comments, sorted newest first.
    final entries = <_FeedEntry>[
      ...rootComments.map((c) => _FeedEntry(createdAt: c.createdAt, comment: c)),
      ...zapsWithComments.map((z) => _FeedEntry(createdAt: z.createdAt, zap: z)),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            const EmptyState(message: 'No comments yet', minHeight: 160)
        else
          Column(
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                if (entries[i].comment != null)
                  RootComment(comment: entries[i].comment!)
                else
                  ZapCommentItem(zap: entries[i].zap!),
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
