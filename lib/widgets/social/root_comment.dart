import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/nostr_comment_service.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/l_connector.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/common/note_parser.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/profile_pic_stack.dart';
import 'package:zapstore/widgets/modals/actions_modal.dart';
import 'package:zapstore/widgets/composer/nostr_composer.dart';
import 'package:zapstore/widgets/composer/nostr_text_controller.dart' show ComposerResult;
import 'package:zapstore/widgets/social/message_bubble.dart';
import 'package:zapstore/widgets/common/input_button.dart';
import 'package:zapstore/widgets/social/quoted_message.dart';
import 'package:zapstore/widgets/social/thread_comment.dart';
import 'package:zapstore/widgets/social/thread_root.dart';
import 'package:zapstore/widgets/modals/tip_amount_modal.dart';
import 'package:zapstore/widgets/social/tip_amount_row.dart';

/// Feed-level comment item matching webapp's RootComment.svelte.
///
/// Layout:
///   1. [MessageBubble] — avatar + gray66 bubble (author header + content).
///   2. [_ReplyIndicator] — connector line + [ProfilePicStack] (when replies exist).
///
/// Tapping opens [_ThreadModal] — a bottom sheet with blurred backdrop —
/// showing the root comment (flat [ThreadComment]) + all replies as bubbles.
class RootComment extends ConsumerWidget {
  const RootComment({
    super.key,
    required this.comment,
    this.rootContext,
    this.version,
    this.onReply,
    this.onActions,
  });

  final Comment comment;

  /// Optional root app/stack/forum context — when null, resolved from NIP-22 tags.
  final ThreadRootContext? rootContext;

  /// App version tag shown beside the root label (app detail threads).
  final String? version;

  /// Called when the user swipes right on the bubble (reply gesture).
  /// If null the swipe animation still plays but nothing opens.
  final VoidCallback? onReply;

  /// Called when the user swipes left on the bubble (actions gesture).
  /// If null the swipe animation still plays but nothing opens.
  final VoidCallback? onActions;

  void _openThread(BuildContext context, WidgetRef ref) {
    showThreadModal(
      context,
      ref,
      comment: comment,
      rootContext: rootContext,
      version: version,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorState = ref.watch(
      query<Profile>(
        authors: {comment.event.pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          stream: false,
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'cb-profile-${comment.event.pubkey}',
      ),
    );
    final author = authorState.models.firstOrNull;
    final directReplies = comment.replies.toList();

    // BFS to count and collect ALL descendants (full subtree), not just direct
    // replies. Mirrors _ThreadBody._collectSubtree used in the thread modal.
    final allDescendants = <Comment>[];
    {
      final seen = <String>{};
      final queue = <Comment>[...directReplies];
      while (queue.isNotEmpty) {
        final c = queue.removeAt(0);
        if (seen.add(c.id)) {
          allDescendants.add(c);
          queue.addAll(c.replies.toList());
        }
      }
    }

    // Unique replier pubkeys (up to 3 for avatar stack) — drawn from the full
    // subtree so the avatars represent all participants, not just direct repliers.
    final uniqueReplierPubkeys = <String>{};
    final replierItems = <ProfilePicItem>[];
    for (final r in allDescendants) {
      if (uniqueReplierPubkeys.add(r.event.pubkey)) {
        replierItems.add(ProfilePicItem(pubkey: r.event.pubkey));
        if (replierItems.length >= 3) break;
      }
    }

    // Fetch profiles for repliers to build display names
    final replierProfilesState = uniqueReplierPubkeys.isNotEmpty
        ? ref.watch(
            query<Profile>(
              authors: uniqueReplierPubkeys,
              source: const LocalAndRemoteSource(
                relays: {'social', 'vertex'},
                stream: false,
                cachedFor: Duration(hours: 2),
              ),
              subscriptionPrefix: 'cb-replier-${comment.id}',
            ),
          )
        : null;

    final replierProfiles = {
      for (final p in replierProfilesState?.models ?? <Profile>[])
        p.pubkey: p,
    };

    final replyIndicatorText = _buildReplyIndicatorText(replierItems, replierProfiles);

    // Merge loaded profiles back into the items so ProfilePicStack renders
    // actual avatars instead of initials fallback.
    final replierItemsWithProfiles = replierItems
        .map((item) => ProfilePicItem(
              pubkey: item.pubkey,
              profile: item.pubkey != null ? replierProfiles[item.pubkey] : null,
            ))
        .toList();

    final contentWidget = NoteParser.parse(
      context,
      comment.content,
      emojiTags: NoteParser.extractEmojiTags(comment.event.tags),
    );

    return GestureDetector(
      onTap: () => _openThread(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessageBubble(
            profile: author,
            pubkey: comment.event.pubkey,
            content: contentWidget,
            timestamp: comment.createdAt,
            topPadding: 0,
            onReply: onReply ??
                () => showThreadModal(
                      context,
                      ref,
                      comment: comment,
                      rootContext: rootContext,
                      version: version,
                      initialExpand: true,
                    ),
            onActions: onActions ??
                () => showCommentActionsModal(
                      context,
                      comment: comment,
                      commentAuthor: author,
                      rootContext: rootContext,
                      version: version,
                      ref: ref,
                    ),
          ),

          // Reply indicator — pulled 2px up to sit closer to the bubble above.
          if (allDescendants.isNotEmpty)
            Transform.translate(
              offset: const Offset(0, -2),
              child: _ReplyIndicator(
                replierItems: replierItemsWithProfiles,
                replyCount: allDescendants.length,
                replyIndicatorText: replyIndicatorText,
                onTap: () => _openThread(context, ref),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the reply indicator label: "Name", "Name & Name", "Name & N Others".
  static String _buildReplyIndicatorText(
    List<ProfilePicItem> items,
    Map<String, Profile> profilesMap,
  ) {
    if (items.isEmpty) return '';
    final n = items.length;
    final nameA = _shortName(profilesMap[items[0].pubkey]);
    if (n == 1) return nameA;
    if (n == 2) {
      return '$nameA & ${_shortName(profilesMap[items[1].pubkey])}';
    }
    return '$nameA & ${n - 1} Others';
  }

  static String _shortName(Profile? p) {
    final name = p?.name?.trim() ?? '';
    if (name.isEmpty) return 'Someone';
    if (name.length <= 18) return name;
    return '${name.substring(0, 18)}...';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thread modal — body + footer (used by showAppModal via fillHeight + footer)
// ─────────────────────────────────────────────────────────────────────────────

/// Opens the comment thread bottom sheet for [comment].
void showThreadModal(
  BuildContext context,
  WidgetRef ref, {
  required Comment comment,
  ThreadRootContext? rootContext,
  String? version,
  bool initialExpand = false,
  Comment? initialReplyTo,
  Profile? initialReplyAuthor,
}) {
  final controller = ThreadModalController(
    expanded: initialExpand,
    replyTo: initialReplyTo,
    replyAuthor: initialReplyAuthor,
  );
  showModal<void>(
    context,
    fillHeight: true,
    maxHeightFactor: 0.75,
    footer: (ctx) => ListenableBuilder(
      listenable: controller,
      builder: (_, __) => _ThreadFooter(
        controller: controller,
        comment: comment,
        onSubmit: (parent, result) =>
            publishReplyComment(ref: ref, result: result, parentComment: parent),
      ),
    ),
    builder: (_) => _ThreadBody(
      comment: comment,
      rootContext: rootContext,
      version: version,
      controller: controller,
    ),
  ).whenComplete(controller.dispose);
}

/// Shared expand/collapse state for the thread modal footer composer.
class ThreadModalController extends ChangeNotifier {
  ThreadModalController({
    this.expanded = false,
    Comment? replyTo,
    Profile? replyAuthor,
  })  : replyTarget = replyTo,
        replyTargetAuthor = replyAuthor;

  bool expanded;
  Comment? replyTarget;
  Profile? replyTargetAuthor;
  int? pendingTipSats;

  void expand({Comment? replyTo, Profile? replyAuthor}) {
    expanded = true;
    replyTarget = replyTo;
    replyTargetAuthor = replyAuthor;
    notifyListeners();
  }

  void collapse() {
    expanded = false;
    replyTarget = null;
    replyTargetAuthor = null;
    pendingTipSats = null;
    notifyListeners();
  }

  void setPendingTip(int? sats) {
    pendingTipSats = sats;
    notifyListeners();
  }
}

/// Scrollable body: unified root rail + divider + reply bubbles.
class _ThreadBody extends ConsumerWidget {
  const _ThreadBody({
    required this.comment,
    this.rootContext,
    this.version,
    required this.controller,
  });

  final Comment comment;
  final ThreadRootContext? rootContext;
  final String? version;
  final ThreadModalController controller;

  /// BFS walk of [root.replies] → [reply.replies] → … collecting ALL
  /// descendants at every depth, sorted chronologically.
  ///
  /// Mirrors webapp's collectCommentSubtree() in thread-discussion.js.
  static List<Comment> _collectSubtree(Comment root) {
    final result = <Comment>[];
    final seen = <String>{};
    final queue = <Comment>[...root.replies.toList()];
    while (queue.isNotEmpty) {
      final c = queue.removeAt(0);
      if (seen.add(c.id)) {
        result.add(c);
        queue.addAll(c.replies.toList());
      }
    }
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    // Recursively collect all descendants (level 2, 3, 4 …) chronologically.
    final replies = _collectSubtree(comment);

    // Build an id→Comment lookup for resolving quoted parents in nested replies.
    final byId = <String, Comment>{
      comment.id: comment,
      for (final r in replies) r.id: r,
    };

    final authorState = ref.watch(
      query<Profile>(
        authors: {comment.event.pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          stream: false,
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'tm-profile-${comment.event.pubkey}',
      ),
    );
    final author = authorState.models.firstOrNull;

    return ThreadRootContextWatch(
      comment: comment,
      rootContextOverride: rootContext,
      builder: (context, resolvedRoot) {
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _ThreadRootUnified(
              comment: comment,
              rootContext: resolvedRoot,
              version: version,
              author: author,
              content: NoteParser.parse(
                context,
                comment.content,
                emojiTags: NoteParser.extractEmojiTags(comment.event.tags),
              ),
              onOptions: () => showCommentActionsModal(
                context,
                comment: comment,
                commentAuthor: author,
                rootContext: resolvedRoot,
                version: version,
                ref: ref,
                onComment: () => controller.expand(),
              ),
            ),

            // Replies — border-top + 14px horizontal inset (webapp .thread-replies)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.white11, width: 1.4)),
              ),
              padding: const EdgeInsets.fromLTRB(
                kCommentModalInset,
                12,
                kCommentModalInset,
                0,
              ),
              child: Column(
                children: [
                  if (replies.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'No comments yet',
                          style: LabTextStyles.reg15.copyWith(color: c.white33),
                        ),
                      ),
                    )
                  else
                    for (int i = 0; i < replies.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _ThreadReply(
                        reply: replies[i],
                        rootId: comment.id,
                        byId: byId,
                        controller: controller,
                        onActions: () => showCommentActionsModal(
                          context,
                          comment: replies[i],
                          rootContext: resolvedRoot,
                          version: version,
                          ref: ref,
                        ),
                      ),
                    ],
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

/// Unified left-rail root block — port of webapp `.thread-root-unified`.
class _ThreadRootUnified extends StatelessWidget {
  const _ThreadRootUnified({
    required this.comment,
    required this.rootContext,
    required this.author,
    required this.content,
    this.version,
    this.onOptions,
  });

  final Comment comment;
  final ThreadRootContext? rootContext;
  final Profile? author;
  final Widget content;
  final String? version;
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kCommentModalInset,
        kCommentModalInset,
        kCommentModalInset,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                if (rootContext != null) ...[
                  ThreadRootBadge(context_: rootContext!),
                  Container(
                    width: 2,
                    height: 12,
                    color: c.white16,
                  ),
                ],
                ProfilePic(
                  profile: author,
                  pubkey: comment.event.pubkey,
                  size: 36,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rootContext != null)
                  ThreadRootEvent(context_: rootContext!, version: version),
                ThreadComment(
                  profile: author,
                  pubkey: comment.event.pubkey,
                  content: content,
                  timestamp: comment.createdAt,
                  showAvatar: false,
                  headerActions: onOptions != null
                      ? ThreadRootOptionsButton(onTap: onOptions)
                      : null,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned footer — collapsed [InputButton] or inline [NostrComposer].
class _ThreadFooter extends StatefulWidget {
  const _ThreadFooter({
    required this.controller,
    required this.comment,
    this.onSubmit,
  });

  final ThreadModalController controller;
  final Comment comment;
  final Future<void> Function(Comment parent, ComposerResult result)? onSubmit;

  @override
  State<_ThreadFooter> createState() => _ThreadFooterState();
}

class _ThreadFooterState extends State<_ThreadFooter> {
  bool _submitting = false;

  Future<void> _handleSubmit(ComposerResult result) async {
    if (_submitting || widget.onSubmit == null) return;
    final hasTip = widget.controller.pendingTipSats != null &&
        widget.controller.pendingTipSats! >= 1;
    if (result.isEmpty && !hasTip) return;

    final parent = widget.controller.replyTarget ?? widget.comment;

    if (hasTip) {
      // Text-only reply path when a tip is attached — comment zap invoice flow
      // (webapp ZapSliderModal + z-wrapper) is not ported to Flutter yet.
      if (!result.isEmpty) {
        setState(() => _submitting = true);
        try {
          await widget.onSubmit!(parent, result);
          if (mounted) widget.controller.collapse();
        } finally {
          if (mounted) setState(() => _submitting = false);
        }
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onSubmit!(parent, result);
      if (mounted) widget.controller.collapse();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openTipPicker() async {
    final amount = await showTipAmountModal(
      context,
      initialAmount: widget.controller.pendingTipSats,
    );
    if (amount != null && mounted) {
      widget.controller.setPendingTip(amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom > 0
        ? 0.0
        : MediaQuery.paddingOf(context).bottom;
    final pendingTip = widget.controller.pendingTipSats;
    final hasTip = pendingTip != null && pendingTip >= 1;

    Widget? quote;
    final replyTarget = widget.controller.replyTarget;
    if (replyTarget != null) {
      quote = QuotedMessage.fromComment(
        replyTarget,
        author: widget.controller.replyTargetAuthor,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            kCommentModalInset,
            0,
            kCommentModalInset,
            kCommentModalInset + bottomPad,
          ),
          child: widget.controller.expanded
              ? Container(
                  decoration: BoxDecoration(
                    color: c.black33,
                    borderRadius: BorderRadius.circular(LabRadius.r17),
                    border: LabBorder.all(color: c.white33, width: LabStroke.thin),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasTip)
                        TipAmountRow(
                          amountSats: pendingTip,
                          onEdit: _openTipPicker,
                        ),
                      NostrComposer(
                        placeholder: replyTarget != null ? 'Reply…' : 'Reply…',
                        size: ComposerSize.medium,
                        autofocus: true,
                        showActionRow: true,
                        nested: true,
                        allowEmptySubmit: hasTip,
                        quotedContent: quote,
                        onTipTap: _openTipPicker,
                        onSubmit: _submitting ? null : _handleSubmit,
                        onClose: widget.controller.collapse,
                      ),
                    ],
                  ),
                )
              : InputButton(
                  placeholder: 'Comment',
                  leading: LabIcon(LabIcons.reply, size: 18, color: c.white33),
                  onTap: () => widget.controller.expand(),
                ),
        ),
      ],
    );
  }
}

/// A single reply inside the thread modal.
///
/// Shows a [QuotedMessage] above the bubble when this reply's parent is not
/// the root comment (i.e. it is a nested reply), matching the webapp's
/// inline quoted-parent display.
class _ThreadReply extends ConsumerWidget {
  const _ThreadReply({
    required this.reply,
    required this.rootId,
    required this.byId,
    required this.controller,
    this.onActions,
  });

  final Comment reply;
  final String rootId;
  final Map<String, Comment> byId;
  final ThreadModalController controller;
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(
      query<Profile>(
        authors: {reply.event.pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          stream: false,
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'tr-profile-${reply.event.pubkey}',
      ),
    );
    final profile = profileState.models.firstOrNull;

    // Resolve whether this reply targets a non-root comment (nested reply).
    final parentId = _getParentEventId(reply);
    final isNestedReply = parentId != null && parentId != rootId;
    final quotedComment = isNestedReply ? byId[parentId] : null;

    // Build bubble content: optional QuotedMessage prepended.
    Widget bubbleContent = NoteParser.parse(
      context,
      reply.content,
      emojiTags: NoteParser.extractEmojiTags(reply.event.tags),
    );

    if (quotedComment != null) {
      bubbleContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          QuotedMessage.fromComment(quotedComment),
          bubbleContent,
        ],
      );
    }

    return MessageBubble(
      profile: profile,
      pubkey: reply.event.pubkey,
      content: bubbleContent,
      timestamp: reply.createdAt,
      isLight: true,
      inThreadModal: true,
      onReply: () => controller.expand(replyTo: reply, replyAuthor: profile),
      onActions: onActions,
    );
  }

  /// Extracts the lowercase `e` tag value (direct parent event ID) from a
  /// NIP-22 comment event, matching getCommentParentEventId() in thread-discussion.js.
  static String? _getParentEventId(Comment c) {
    for (final tag in c.event.tags) {
      if (tag.length >= 2 && tag[0] == 'e' && tag[1].isNotEmpty) {
        return tag[1].toLowerCase();
      }
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reply indicator (connector line + ProfilePicStack)
// ─────────────────────────────────────────────────────────────────────────────

/// Matches the `reply-indicator` div in RootComment.svelte:
/// vertical bar + curved L-corner SVG + [ProfilePicStack] with name text + count.
class _ReplyIndicator extends StatelessWidget {
  const _ReplyIndicator({
    required this.replierItems,
    required this.replyCount,
    required this.replyIndicatorText,
    this.onTap,
  });

  final List<ProfilePicItem> replierItems;
  final int replyCount;
  final String replyIndicatorText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Aligns the connector with the avatar center of the MessageBubble above
        // (avatar = 36px centered at 14 screen-pad + 18 = 32px from left edge)
        padding: const EdgeInsets.only(left: 32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Connector: visual 28px + 13px bottom padding aligns L-shape
            // endpoint with the vertical center of the 28px avatars on the right.
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: SizedBox(
                width: 25,
                height: 28,
                child: LabLConnector(color: c.white16),
              ),
            ),
            const SizedBox(width: 2),

            Flexible(
              child: ProfilePicStack(
                profiles: replierItems,
                text: replyIndicatorText,
                suffix: '$replyCount',
                avatarSize: 28,
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
