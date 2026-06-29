import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zapstore/services/nostr_forum_post_service.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/composer/emoji_picker_modal.dart';
import 'package:zapstore/widgets/composer/nostr_composer.dart';
import 'package:zapstore/widgets/composer/nostr_text_controller.dart';
import 'package:zapstore/widgets/modals/forum_post_labels_modal.dart';

/// Opens the forum post composer — port of webapp's `ForumPostModal.svelte`.
Future<void> showForumPostModal(BuildContext context, WidgetRef ref) {
  return showModal<void>(
    context,
    fillHeight: true,
    maxHeightFactor: 0.92,
    builder: (_) => _ForumPostModalContent(ref: ref),
  );
}

class _ForumPostModalContent extends HookConsumerWidget {
  const _ForumPostModalContent({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final c = Theme.of(context).extension<LabColors>()!;
    final titleController = useTextEditingController();
    final contentController = useMemoized(() => NostrTextEditingController());
    final selectedLabels = useState(<String>[]);
    final submitting = useState(false);
    final error = useState<String?>(null);

    useListenable(titleController);
    useEffect(() {
      return contentController.dispose;
    }, const []);

    Future<void> publish() async {
      if (submitting.value) return;
      final title = titleController.text.trim();
      if (title.isEmpty) return;

      final content = contentController.serialize();
      if (content.isEmpty) return;

      submitting.value = true;
      error.value = null;
      try {
        await publishForumPost(
          ref: ref,
          title: title,
          content: content,
          labels: selectedLabels.value,
        );
        if (context.mounted) Navigator.of(context).pop();
      } catch (e) {
        error.value = e.toString().replaceFirst('Exception: ', '');
      } finally {
        submitting.value = false;
      }
    }

    Future<void> openLabels({required bool publishMode}) async {
      await showForumPostLabelsModal(
        context,
        selectedLabels: selectedLabels.value,
        publishMode: publishMode,
        header: publishMode ? "Don't forget some Labels!" : null,
        onLabelsChanged: (labels) => selectedLabels.value = labels,
        onPublish: publish,
      );
    }

    Future<void> handlePublishTap() async {
      if (titleController.text.trim().isEmpty || submitting.value) return;
      if (selectedLabels.value.isEmpty) {
        await openLabels(publishMode: true);
        return;
      }
      await publish();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: LabStroke.thin, color: c.white16),
        Padding(
          padding: const EdgeInsets.all(kModalInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: c.black33,
                  borderRadius: BorderRadius.circular(LabRadius.r16),
                  border: LabBorder.all(color: c.white33, width: LabStroke.thin),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleController,
                      enabled: !submitting.value,
                      style: LabTextStyles.semibold17.copyWith(color: c.white),
                      cursorColor: c.white,
                      decoration: InputDecoration(
                        hintText: 'Title of Forum Post',
                        hintStyle: LabTextStyles.med17.copyWith(
                          color: c.white33,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    Container(height: LabStroke.thin, color: c.white8),
                    NostrComposer(
                      controller: contentController,
                      placeholder: 'Write your forum post...',
                      size: ComposerSize.large,
                      showActionRow: false,
                      nested: true,
                    ),
                    _ForumPostActionRow(
                      labelCount: selectedLabels.value.length,
                      submitting: submitting.value,
                      canPublish: titleController.text.trim().isNotEmpty,
                      onEmojiTap: () async {
                        final result = await showEmojiPicker(context);
                        if (result == null) return;
                        if (result.source == EmojiSource.unicode) {
                          contentController.insertUnicodeEmoji(result.display);
                        } else {
                          contentController.insertCustomEmoji(
                            shortcode: result.shortcode,
                            url: result.display,
                          );
                        }
                      },
                      onLabelsTap: () => openLabels(publishMode: false),
                      onPublish: handlePublishTap,
                    ),
                  ],
                ),
              ),
              if (error.value != null) ...[
                const SizedBox(height: 8),
                Text(
                  error.value!,
                  style: LabTextStyles.reg13.copyWith(color: c.rougeColor),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ForumPostActionRow extends StatelessWidget {
  const _ForumPostActionRow({
    required this.labelCount,
    required this.submitting,
    required this.canPublish,
    required this.onEmojiTap,
    required this.onLabelsTap,
    required this.onPublish,
  });

  final int labelCount;
  final bool submitting;
  final bool canPublish;
  final VoidCallback onEmojiTap;
  final VoidCallback onLabelsTap;
  final Future<void> Function() onPublish;

  @override
  Widget build(BuildContext context) {
    final hasLabels = labelCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          _ActionIconButton(
            icon: LabIcons.emojiFill,
            iconSize: 18,
            onTap: submitting ? null : onEmojiTap,
          ),
          const SizedBox(width: 8),
          _LabelsTrigger(
            count: labelCount,
            hasLabels: hasLabels,
            onTap: submitting ? null : onLabelsTap,
          ),
          const Spacer(),
          LabButton.primary(
            onTap: (!canPublish || submitting) ? null : () => onPublish(),
            text: submitting ? 'Publishing…' : 'Publish',
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatefulWidget {
  const _ActionIconButton({
    required this.icon,
    required this.iconSize,
    this.onTap,
  });

  final String icon;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: c.white8,
            borderRadius: BorderRadius.circular(LabRadius.r8),
          ),
          child: Center(
            child: LabIcon(
              widget.icon,
              size: widget.iconSize,
              color: c.white33,
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelsTrigger extends StatefulWidget {
  const _LabelsTrigger({
    required this.count,
    required this.hasLabels,
    this.onTap,
  });

  final int count;
  final bool hasLabels;
  final VoidCallback? onTap;

  @override
  State<_LabelsTrigger> createState() => _LabelsTriggerState();
}

class _LabelsTriggerState extends State<_LabelsTrigger> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final bg = widget.hasLabels ? c.white16 : c.white8;

    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 32,
              padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(LabRadius.r8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.count}',
                    style: LabTextStyles.semibold15.copyWith(
                      color: widget.hasLabels ? c.white66 : c.white16,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.count == 1 ? 'Label' : 'Labels',
                    style: LabTextStyles.med15.copyWith(
                      color: widget.hasLabels ? c.white : c.white33,
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: const Size(12, 32),
              painter: _LabelTipPainter(bg),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelTipPainter extends CustomPainter {
  _LabelTipPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(3, 0)
      ..quadraticBezierTo(6, 2, 9, 5)
      ..quadraticBezierTo(11, 8, 12, 11)
      ..quadraticBezierTo(11, 14, 9, 17)
      ..quadraticBezierTo(6, 20, 3, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LabelTipPainter oldDelegate) =>
      oldDelegate.color != color;
}
