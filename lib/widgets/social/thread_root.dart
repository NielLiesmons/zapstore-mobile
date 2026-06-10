import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/models/forum_post.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/app_pic.dart';
import 'package:zapstore/widgets/common/shimmer.dart';

const double kCommentModalInset = 14;

/// Forum post badge emoji — matches webapp `/images/emoji/forum.png`.
const String kForumEmojiAsset = 'assets/images/emoji/forum.png';

/// Bottom scroll fade height above pinned footer — matches webapp inset token.
const double kCommentModalBottomFade = 14;

/// Root app / stack / forum context shown above comment composers and in
/// opened thread modals — port of webapp `rootContext` on RootComment.
class ThreadRootContext {
  const ThreadRootContext({
    required this.label,
    this.iconUrl,
    this.href,
    this.deleted = false,
    this.isStack = false,
    this.isApp = false,
    this.isForum = false,
    this.identifier,
    this.loading = false,
  });

  final String label;
  final String? iconUrl;
  final String? href;
  final bool deleted;
  final bool isStack;
  final bool isApp;
  final bool isForum;
  final String? identifier;
  final bool loading;

  bool get isNavigable => !deleted && !loading && (href?.isNotEmpty ?? false);

  factory ThreadRootContext.fromApp(App app, {String? version, String? href}) {
    final name = app.name?.trim();
    final id = app.identifier;
    return ThreadRootContext(
      label: (name?.isNotEmpty == true ? name! : id).trim(),
      iconUrl: app.icons.firstOrNull,
      href: href,
      isApp: true,
      identifier: id,
    );
  }

  factory ThreadRootContext.fromStack(AppStack stack, {String? href}) {
    final title = stack.name?.trim();
    final id = stack.identifier;
    return ThreadRootContext(
      label: (title?.isNotEmpty == true ? title! : id).trim(),
      href: href,
      isStack: true,
      identifier: id,
    );
  }

  factory ThreadRootContext.fromForumPost(ForumPost post, {String? href}) {
    final title = post.title?.trim();
    final firstLine = post.content.split('\n').first.trim();
    final label = title?.isNotEmpty == true
        ? title!
        : (firstLine.isNotEmpty ? firstLine : 'Publication');
    return ThreadRootContext(
      label: _truncateOneliner(label),
      href: href,
      isForum: true,
      iconUrl: kForumEmojiAsset,
    );
  }

  factory ThreadRootContext.fromModel(Model model, {String? href}) {
    if (model is App) return ThreadRootContext.fromApp(model, href: href);
    if (model is AppStack) return ThreadRootContext.fromStack(model, href: href);
    if (model is ForumPost) {
      return ThreadRootContext.fromForumPost(model, href: href);
    }
    return const ThreadRootContext(label: 'Post', isForum: true);
  }

  factory ThreadRootContext.loadingForKind(int kind) {
    final isStack = kind == 30267;
    final isApp = kind == 32267;
    return ThreadRootContext(
      label: isStack
          ? 'Loading Stack…'
          : isApp
              ? 'Loading App…'
              : kind == 11
                  ? 'Loading Publication…'
                  : 'Loading…',
      isStack: isStack,
      isApp: isApp,
      isForum: !isStack && !isApp,
      loading: true,
    );
  }

  factory ThreadRootContext.deletedForKind(int kind) {
    final isStack = kind == 30267;
    final isApp = kind == 32267;
    return ThreadRootContext(
      label: isStack
          ? 'Stack not found'
          : isApp
              ? 'App not found'
              : kind == 11
                  ? 'Publication not found'
                  : 'Thread not found',
      deleted: true,
      isStack: isStack,
      isApp: isApp,
      isForum: !isStack && !isApp,
    );
  }

  static String? rootCoord(EventBase<Model<dynamic>> event) =>
      event.getFirstTagValue('E') ?? event.getFirstTagValue('A');

  static String? hrefForModel(Model model) {
    try {
      if (model is App) {
        final naddr = Utils.encodeShareableFromString(model.id, type: 'naddr');
        return '/app/$naddr';
      }
      if (model is AppStack) {
        final naddr = Utils.encodeShareableFromString(model.id, type: 'naddr');
        return '/stack/$naddr';
      }
      if (model is ForumPost) {
        return '/forum/${model.event.id}';
      }
    } catch (_) {}
    return null;
  }
}

String _truncateOneliner(String raw, [int max = 80]) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  if (t.length <= max) return t;
  return '${t.substring(0, max)}…';
}

/// Resolves [ThreadRootContext] from a comment's NIP-22 root tags.
ThreadRootContext? resolveThreadRootContext({
  required Comment comment,
  Model? rootModel,
  bool rootLoading = false,
  bool rootMissing = false,
}) {
  if (rootLoading) {
    return ThreadRootContext.loadingForKind(comment.rootKind ?? 11);
  }
  if (rootMissing) {
    return ThreadRootContext.deletedForKind(comment.rootKind ?? 11);
  }
  if (rootModel != null) {
    return ThreadRootContext.fromModel(
      rootModel,
      href: ThreadRootContext.hrefForModel(rootModel),
    );
  }
  return null;
}

const LocalAndRemoteSource kThreadRootSource = LocalAndRemoteSource(
  relays: {kDefaultRelay, 'AppCatalog'},
  stream: true,
);

/// Watches the root entity for [comment] and builds [ThreadRootContext].
class ThreadRootContextWatch extends ConsumerWidget {
  const ThreadRootContextWatch({
    super.key,
    required this.comment,
    this.rootContextOverride,
    required this.builder,
  });

  final Comment comment;
  final ThreadRootContext? rootContextOverride;
  final Widget Function(BuildContext context, ThreadRootContext? rootContext) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rootContextOverride != null) {
      return builder(context, rootContextOverride);
    }

    final rootCoord = ThreadRootContext.rootCoord(comment.event);
    if (rootCoord == null) {
      return builder(context, null);
    }

    final rootState = ref.watch(
      queryKinds(
        ids: {rootCoord},
        limit: 1,
        source: kThreadRootSource,
        subscriptionPrefix: 'tr-root-${comment.id.hashCode}',
        where: null,
        and: null,
      ),
    );

    Model? rootModel;
    final raw = rootState.models.firstOrNull;
    if (raw is Model) rootModel = raw;

    final loading = rootState is StorageLoading && rootModel == null;
    final missing = !loading && rootModel == null;

    final ctx = resolveThreadRootContext(
      comment: comment,
      rootModel: rootModel,
      rootLoading: loading,
      rootMissing: missing,
    );
    return builder(context, ctx);
  }
}

// ── Badge + label widgets (CommentModalRootRow / ThreadRootBadge / Event) ────

const double kThreadRootBadgeSize = 28;

/// 28×28 tile with the forum post emoji (14×14), matching webapp ThreadRootBadge.
class ForumEmojiBadge extends StatelessWidget {
  const ForumEmojiBadge({
    super.key,
    this.size = kThreadRootBadgeSize,
    this.backgroundColor,
  });

  final double size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? c.black33,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Image.asset(
          kForumEmojiAsset,
          width: 14,
          height: 14,
        ),
      ),
    );
  }
}

/// 2×2 stack tile — port of `ActivityStackMiniBadge.svelte`.
class ThreadStackMiniBadge extends StatelessWidget {
  const ThreadStackMiniBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Container(
      width: kThreadRootBadgeSize,
      height: kThreadRootBadgeSize,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.gray33,
        borderRadius: BorderRadius.circular(6),
        border: LabBorder.all(color: c.white16, width: LabStroke.thin),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [_tile(c), const SizedBox(width: 2), _tile(c)],
          ),
          const SizedBox(height: 2),
          Row(
            children: [_tile(c), const SizedBox(width: 2), _tile(c)],
          ),
        ],
      ),
    );
  }

  Widget _tile(LabColors c) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: c.blurpleColor66,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class ThreadRootBadge extends StatelessWidget {
  const ThreadRootBadge({super.key, required this.context_});

  final ThreadRootContext context_;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    if (context_.loading) {
      return Shimmer(
        width: kThreadRootBadgeSize,
        height: kThreadRootBadgeSize,
        radius: 6,
      );
    }

    if (context_.deleted) {
      return Container(
        width: kThreadRootBadgeSize,
        height: kThreadRootBadgeSize,
        decoration: BoxDecoration(
          color: c.white8,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            '?',
            style: LabTextStyles.med13.copyWith(color: c.white33),
          ),
        ),
      );
    }

    if (context_.isStack) {
      return const ThreadStackMiniBadge();
    }

    if (context_.isApp || context_.identifier != null) {
      return AppPic(
        iconUrl: context_.iconUrl,
        name: context_.label,
        identifier: context_.identifier,
        size: kThreadRootBadgeSize,
        onTap: null,
      );
    }

    if (context_.isForum) {
      return const ForumEmojiBadge();
    }

    return Container(
      width: kThreadRootBadgeSize,
      height: kThreadRootBadgeSize,
      decoration: BoxDecoration(
        color: c.white8,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: LabIcon(LabIcons.reply, size: 14, color: c.white66),
      ),
    );
  }
}

class ThreadRootEvent extends StatelessWidget {
  const ThreadRootEvent({
    super.key,
    required this.context_,
    this.version,
  });

  final ThreadRootContext context_;
  final String? version;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final showVersion =
        version != null && version!.isNotEmpty && !context_.isStack && !context_.deleted;

    final labelColor = context_.deleted || context_.loading ? c.white33 : c.white66;

    Widget label;
    if (context_.isStack) {
      label = RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: LabTextStyles.med15.copyWith(color: c.white33),
          children: [
            const TextSpan(text: 'Stack '),
            TextSpan(
              text: context_.label,
              style: LabTextStyles.med15.copyWith(color: labelColor),
            ),
          ],
        ),
      );
    } else {
      label = Text(
        context_.label,
        style: LabTextStyles.med15.copyWith(color: labelColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final row = SizedBox(
      height: kThreadRootBadgeSize,
      child: Row(
        children: [
          Flexible(child: label),
          if (showVersion) ...[
            const SizedBox(width: 8),
            Text(
              'v$version',
              style: LabTextStyles.med15.copyWith(color: c.white33),
            ),
          ],
        ],
      ),
    );

    if (context_.isNavigable) {
      return GestureDetector(
        onTap: () => context.go(context_.href!),
        behavior: HitTestBehavior.opaque,
        child: row,
      );
    }
    return row;
  }
}

/// Shared root row for [showCommentModal] — port of `CommentModalRootRow.svelte`.
class CommentModalRootRow extends StatelessWidget {
  const CommentModalRootRow({
    super.key,
    required this.context_,
    this.version,
    this.showConnector = false,
  });

  final ThreadRootContext context_;
  final String? version;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const SizedBox(width: 8),
              ThreadRootBadge(context_: context_),
              const SizedBox(width: 8),
              Expanded(
                child: ThreadRootEvent(context_: context_, version: version),
              ),
            ],
          ),
        ),
        if (showConnector)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 21),
              child: Container(
                width: 2,
                height: 10,
                color: c.white16,
              ),
            ),
          ),
      ],
    );
  }
}
