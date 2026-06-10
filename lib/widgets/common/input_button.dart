import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Fake input that opens a modal or expands a composer — port of webapp
/// `InputButton.svelte`.
class InputButton extends StatelessWidget {
  const InputButton({
    super.key,
    required this.placeholder,
    this.onTap,
    this.leading,
    this.trailing,
  });

  final String placeholder;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 41,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: c.black33,
          borderRadius: BorderRadius.circular(17),
          border: LabBorder.all(color: c.white33, width: LabStroke.thin),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                placeholder,
                style: LabTextStyles.med15.copyWith(color: c.white33),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
