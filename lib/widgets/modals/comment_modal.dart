import 'package:flutter/material.dart';

import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/composer/nostr_composer.dart';
import 'package:zapstore/widgets/composer/nostr_text_controller.dart'; // ComposerResult

// ── Public API ────────────────────────────────────────────────────────────────

/// Shows the comment composer modal — a direct port of webapp's
/// `CommentModal.svelte`.
///
/// The sheet uses the standard [showModal] surface (gray66 + blur + r32 top,
/// ModalNestScope for scale-down when the emoji picker opens on top).
///
/// [placeholder] defaults to "Write your comment…".
/// [onSubmit] receives the serialized [ComposerResult]; caller is responsible
/// for publishing the Nostr event. Returning normally closes the sheet.
/// Returning by throwing leaves it open (so the user doesn't lose their text).
Future<void> showCommentModal(
  BuildContext context, {
  String placeholder = 'Write your comment…',
  Future<void> Function(ComposerResult result)? onSubmit,
}) {
  return showModal<void>(
    context,
    builder: (_) => _CommentModalContent(
      placeholder: placeholder,
      onSubmit: onSubmit,
    ),
  );
}

// ── Modal content ─────────────────────────────────────────────────────────────

class _CommentModalContent extends StatefulWidget {
  const _CommentModalContent({
    required this.placeholder,
    this.onSubmit,
  });

  final String placeholder;
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

  @override
  Widget build(BuildContext context) {
    // 14px padding on all sides, matching webapp .comment-sheet padding.
    return Padding(
      padding: const EdgeInsets.all(14),
      child: NostrComposer(
        placeholder: widget.placeholder,
        size: ComposerSize.medium,
        autofocus: true,
        showActionRow: true,
        onSubmit: _submitting ? null : _handleSubmit,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
