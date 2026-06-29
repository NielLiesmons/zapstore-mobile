import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/label.dart';
import 'package:zapstore/widgets/common/modal.dart';

/// Label picker stacked over [showForumPostModal] — port of
/// webapp's `ForumPostLabelsModal.svelte`.
Future<void> showForumPostLabelsModal(
  BuildContext context, {
  required List<String> selectedLabels,
  required ValueChanged<List<String>> onLabelsChanged,
  bool publishMode = false,
  String? header,
  Future<void> Function()? onPublish,
}) async {
  ModalNestScope.setNested(context, isOpen: true);
  try {
    await showModal<void>(
      context,
      nestedModal: true,
      maxHeightFactor: 0.65,
      builder: (ctx) => _ForumPostLabelsContent(
        initialLabels: selectedLabels,
        publishMode: publishMode,
        header: header,
        onLabelsChanged: onLabelsChanged,
        onPublish: onPublish,
      ),
    );
  } finally {
    if (context.mounted) {
      ModalNestScope.setNested(context, isOpen: false);
    }
  }
}

class _ForumPostLabelsContent extends HookWidget {
  const _ForumPostLabelsContent({
    required this.initialLabels,
    required this.onLabelsChanged,
    this.publishMode = false,
    this.header,
    this.onPublish,
  });

  final List<String> initialLabels;
  final ValueChanged<List<String>> onLabelsChanged;
  final bool publishMode;
  final String? header;
  final Future<void> Function()? onPublish;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final labels = useState(List<String>.from(initialLabels));
    final inputController = useTextEditingController();

    void toggle(String label) {
      final next = List<String>.from(labels.value);
      if (next.contains(label)) {
        next.remove(label);
      } else {
        next.add(label);
      }
      labels.value = next;
      onLabelsChanged(next);
    }

    void addCustomLabel() {
      final value = inputController.text.trim();
      if (value.isEmpty) return;
      if (!labels.value.contains(value)) {
        final next = [...labels.value, value];
        labels.value = next;
        onLabelsChanged(next);
      }
      inputController.clear();
    }

    final customLabels = labels.value
        .where((l) => !kForumCategories.contains(l))
        .toList();
    final allLabels = [...customLabels, ...kForumCategories];
    final perRow = (allLabels.length / 3).ceil();
    final rows = [
      allLabels.take(perRow).toList(),
      allLabels.skip(perRow).take(perRow).toList(),
      allLabels.skip(perRow * 2).toList(),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(kModalInset, 0, kModalInset, kModalInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[
            Text(
              header!,
              textAlign: TextAlign.center,
              style: LabTextStyles.semibold17.copyWith(color: c.white),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: inputController,
            style: LabTextStyles.med15.copyWith(color: c.white),
            cursorColor: c.white,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => addCustomLabel(),
            decoration: InputDecoration(
              hintText: 'Add a label...',
              hintStyle: LabTextStyles.med15.copyWith(color: c.white33),
              filled: true,
              fillColor: c.gray33,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LabRadius.r11),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final row in rows)
                    if (row.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final label in row)
                              LabLabel(
                                label,
                                isSelected: labels.value.contains(label),
                                onTap: () => toggle(label),
                              ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          LabButton.primary(
            onTap: () async {
              if (publishMode) {
                Navigator.of(context).pop();
                await onPublish?.call();
              } else {
                Navigator.of(context).pop();
              }
            },
            text: publishMode ? 'Publish' : 'Done',
          ),
        ],
      ),
    );
  }
}
