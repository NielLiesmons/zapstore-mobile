import 'package:async_button_builder/async_button_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/notification_service.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/auth_widgets.dart';
import 'package:zapstore/widgets/social/root_comment.dart';

/// Comments section for App detail screen
class CommentsSection extends HookConsumerWidget {
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

    // Extract comments and error state
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
      addCommentButton: _AddCommentButton(
        fileMetadata: fileMetadata!,
        app: app,
      ),
      app: app,
      fileMetadata: fileMetadata!,
    );
  }
}

/// Comments section for AppStack/Stack detail screen
class StackCommentsSection extends HookConsumerWidget {
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

    // Extract comments and error state
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
      addCommentButton: _AddStackCommentButton(stack: stack),
      stack: stack,
    );
  }
}

/// Shared layout for both App and Stack comments.
/// Renders comments as [MessageBubble]s (webapp style).
class _CommentsSectionLayout extends StatelessWidget {
  const _CommentsSectionLayout({
    required this.comments,
    required this.errorException,
    required this.addCommentButton,
    this.app,
    this.fileMetadata,
    this.stack,
  });

  final List<Comment> comments;
  final Object? errorException;
  final Widget addCommentButton;
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
        // Add Comment button
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: addCommentButton,
        ),

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
                style: AppTextStyles.reg15.copyWith(
                  color: Theme.of(context).extension<AppColors>()!.white33,
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


class _AddCommentButton extends ConsumerWidget {
  const _AddCommentButton({required this.fileMetadata, required this.app});

  final Installable fileMetadata;
  final App app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _showCommentComposer(context),
        icon: const Icon(Icons.add_comment),
        label: const Text('Add Comment'),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _showCommentComposer(BuildContext context) {
    showAppSheet(
      context,
      builder: (context) =>
          _CommentComposer(fileMetadata: fileMetadata, app: app),
    );
  }
}

class _AddStackCommentButton extends ConsumerWidget {
  const _AddStackCommentButton({required this.stack});

  final AppStack stack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _showStackCommentComposer(context),
        icon: const Icon(Icons.add_comment),
        label: const Text('Add Comment'),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _showStackCommentComposer(BuildContext context) {
    showAppSheet(
      context,
      builder: (context) => _StackCommentComposer(stack: stack),
    );
  }
}

class _CommentComposer extends HookConsumerWidget {
  const _CommentComposer({required this.fileMetadata, required this.app});

  final Installable fileMetadata;
  final App app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(Signer.activePubkeyProvider) != null;
    final textController = useTextEditingController();
    // Rebuild on text changes so the Post button enables/disables correctly
    useListenable(textController);

    final installedVersion = app.installedPackage?.version;
    final versionToComment = installedVersion ?? fileMetadata.version;
    final appName = app.name ?? 'this app';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comment on $versionToComment',
                  style: context.textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!isSignedIn) ...[
              const SignInPrompt(
                message:
                    'Sign in to share your thoughts and help others discover great apps.',
              ),
            ] else ...[
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  hintText:
                      'Share your thoughts about $appName $versionToComment...',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 4,
                autofocus: true,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AsyncButtonBuilder(
                child: const Text('Post Comment'),
                onPressed: () =>
                    _publishComment(ref, textController.text, context),
                builder: (context, child, callback, buttonState) {
                  return FilledButton(
                    onPressed: !isSignedIn
                        ? null
                        : buttonState.maybeWhen(
                            loading: () => null,
                            orElse: () => textController.text.trim().isEmpty
                                ? null
                                : callback,
                          ),
                    child: buttonState.maybeWhen(
                      loading: () => const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      orElse: () => child,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publishComment(
    WidgetRef ref,
    String content,
    BuildContext context,
  ) async {
    if (content.trim().isEmpty) return;

    try {
      final signer = ref.read(Signer.activeSignerProvider);
      if (signer == null) {
        if (context.mounted) {
          context.showError(
            'Sign in required',
            description: 'You need to sign in with Amber to post comments.',
          );
        }
        return;
      }

      // Get the version to comment on (installed version or latest release)
      final installedVersion = app.installedPackage?.version;
      final versionToComment = installedVersion ?? fileMetadata.version;

      final comment = PartialComment(
        content: content.trim(),
        rootModel: app,
        // No parentModel for root comments - only A/K/P tags, no e/k/p
      );

      // Add v tag for version (per NIP-22 guidance, not d tag)
      comment.event.addTagValue('v', versionToComment);

      final signedComment = await comment.signWith(signer);

      await signedComment.save();
      await signedComment.publish(relays: 'AppCatalog');

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Failed to post comment', technicalDetails: '$e');
      }
    }
  }
}

/// Reply composer for threaded comments
class _StackCommentComposer extends HookConsumerWidget {
  const _StackCommentComposer({required this.stack});

  final AppStack stack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(Signer.activePubkeyProvider) != null;
    final textController = useTextEditingController();
    useListenable(textController);

    final stackName = stack.name ?? stack.identifier;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comment on $stackName',
                  style: context.textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!isSignedIn) ...[
              const SignInPrompt(
                message: 'Sign in to share your thoughts about this stack.',
              ),
            ] else ...[
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  hintText: 'Share your thoughts about $stackName...',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 4,
                autofocus: true,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AsyncButtonBuilder(
                child: const Text('Post Comment'),
                onPressed: () =>
                    _publishComment(ref, textController.text, context),
                builder: (context, child, callback, buttonState) {
                  return FilledButton(
                    onPressed: !isSignedIn
                        ? null
                        : buttonState.maybeWhen(
                            loading: () => null,
                            orElse: () => textController.text.trim().isEmpty
                                ? null
                                : callback,
                          ),
                    child: buttonState.maybeWhen(
                      loading: () => const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      orElse: () => child,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publishComment(
    WidgetRef ref,
    String content,
    BuildContext context,
  ) async {
    if (content.trim().isEmpty) return;

    try {
      final signer = ref.read(Signer.activeSignerProvider);
      if (signer == null) {
        if (context.mounted) {
          context.showError(
            'Sign in required',
            description: 'You need to sign in with Amber to post comments.',
          );
        }
        return;
      }

      final comment = PartialComment(content: content.trim(), rootModel: stack);

      final signedComment = await comment.signWith(signer);

      await signedComment.save();
      await signedComment.publish(relays: 'AppCatalog');

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Failed to post comment', technicalDetails: '$e');
      }
    }
  }
}
