import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Left-aligned pill for expanding or collapsing truncated text.
class ReadMoreButton extends StatelessWidget {
  const ReadMoreButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: c.white8,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: LabTextStyles.med13.copyWith(color: c.white66),
          ),
        ),
      ),
    );
  }
}
