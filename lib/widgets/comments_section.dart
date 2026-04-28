import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/social/root_comment.dart';

/// Comments section for App detail screen
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
        tags: {
          '#A': {app.id},
        },
        source: LocalAndRemoteSource(stream: true, relays: 'AppCatalog'),
        subscriptionPrefix: 'app-comments',
      ),
    );

    final List<Comment> comments = switch (commentsState) {
      StorageData(:final models) => models,
      _ => [],
    };
    final errorException = switch (commentsState) {
      StorageError(:final exception) => exception,
      _ => null,
    };

    return _CommentsSectionLayout(
      comments: comments,
      errorException: errorException,
      app: app,
      fileMetadata: fileMetadata!,
    );
  }
}

/// Comments section for AppStack/Stack detail screen
class StackCommentsSection extends ConsumerWidget {
  const StackCommentsSection({super.key, required this.stack});

  final AppStack stack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsState = ref.watch(
      query<Comment>(
        tags: {
          '#A': {stack.id},
        },
        source: LocalAndRemoteSource(stream: true, relays: 'AppCatalog'),
        subscriptionPrefix: 'app-stack-comments',
      ),
    );

    final List<Comment> comments = switch (commentsState) {
      StorageData(:final models) => models,
      _ => [],
    };
    final errorException = switch (commentsState) {
      StorageError(:final exception) => exception,
      _ => null,
    };

    return _CommentsSectionLayout(
      comments: comments,
      errorException: errorException,
      stack: stack,
    );
  }
}

/// Shared layout for both App and Stack comments.
class _CommentsSectionLayout extends StatelessWidget {
  const _CommentsSectionLayout({
    required this.comments,
    required this.errorException,
    this.app,
    this.fileMetadata,
    this.stack,
  });

  final List<Comment> comments;
  final Object? errorException;
  final App? app;
  final Installable? fileMetadata;
  final AppStack? stack;

  @override
  Widget build(BuildContext context) {
    final rootComments = comments.where((c) => c.parentKind != 1111).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (errorException != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildCommentsError(context, errorException!),
          ),

        if (rootComments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No comments yet',
                style: LabTextStyles.reg15.copyWith(
                  color: Theme.of(context).extension<LabColors>()!.white33,
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              for (int i = 0; i < rootComments.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                RootComment(comment: rootComments[i]),
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
