import 'package:flutter/material.dart';
import 'package:models/models.dart';

import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/composer/nostr_composer.dart';
import 'package:zapstore/widgets/composer/nostr_text_controller.dart'; // ComposerResult
import 'package:zapstore/widgets/social/quoted_message.dart';
import 'package:zapstore/widgets/social/quoted_zap_message.dart';

// ── Public API ────────────────────────────────────────────────────────────────

/// Shows the comment composer modal — a direct port of webapp's
/// `CommentModal.svelte`.
///
/// The sheet uses the standard [showModal] surface (gray66 + blur + r32 top,
/// ModalNestScope for scale-down when the emoji picker opens on top).
///
/// [placeholder] defaults to "Write your comment…".
/// [quotedComment] — when set, renders a [QuotedMessage] block above the
///   composer so the user sees the context they are replying to.
/// [quotedZap] — when set, renders a [QuotedZapMessage] block above the
///   composer (mutually exclusive with [quotedComment]; if both are passed
///   [quotedComment] takes priority).
/// [quotedAuthorName] — display name for the quoted author (used with
///   [quotedZap] since the zap model does not carry a resolved profile).
/// [onSubmit] receives the serialized [ComposerResult]; caller is responsible
/// for publishing the Nostr event. Returning normally closes the sheet.
/// Returning by throwing leaves it open (so the user doesn't lose their text).
Future<void> showCommentModal(
  BuildContext context, {
  String placeholder = 'Write your comment…',
  Comment? quotedComment,
  Profile? quotedCommentAuthor,
  Zap? quotedZap,
  String? quotedAuthorName,
  Future<void> Function(ComposerResult result)? onSubmit,
}) {
  return showModal<void>(
    context,
    builder: (_) => _CommentModalContent(
      placeholder: placeholder,
      quotedComment: quotedComment,
      quotedCommentAuthor: quotedCommentAuthor,
      quotedZap: quotedZap,
      quotedAuthorName: quotedAuthorName,
      onSubmit: onSubmit,
    ),
  );
}

// ── Modal content ─────────────────────────────────────────────────────────────

class _CommentModalContent extends StatefulWidget {
  const _CommentModalContent({
    required this.placeholder,
    this.quotedComment,
    this.quotedCommentAuthor,
    this.quotedZap,
    this.quotedAuthorName,
    this.onSubmit,
  });

  final String placeholder;
  final Comment? quotedComment;
  final Profile? quotedCommentAuthor;
  final Zap? quotedZap;
  final String? quotedAuthorName;
  final Future<void> Function(ComposerResult result)? onSubmit;

  @override
  State<_CommentModalContent> createState() => _CommentModalContentState();
}

class _CommentModalContentState extends State<_CommentModalContent> {
  bool _submitting = false;

  Future<void> _handleSubmit(ComposerResult result) async {
    if (_submitting || result.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit?.call(result);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget? _buildQuote() {
    if (widget.quotedComment != null) {
      return QuotedMessage.fromComment(
        widget.quotedComment!,
        author: widget.quotedCommentAuthor,
      );
    }
    if (widget.quotedZap != null) {
      final name = widget.quotedAuthorName ?? 'Someone';
      final content = widget.quotedZap!.event.content;
      return QuotedZapMessage(
        authorName: name,
        amountSats: widget.quotedZap!.amount,
        contentPreview: content,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final quote = _buildQuote();

    // Pass quotedContent directly into NostrComposer so it renders inside
    // the black33 container, not as a separate element above it.
    return Padding(
      padding: const EdgeInsets.all(14),
      child: NostrComposer(
        placeholder: widget.placeholder,
        size: ComposerSize.medium,
        autofocus: true,
        showActionRow: true,
        quotedContent: quote,
        onSubmit: _submitting ? null : _handleSubmit,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
