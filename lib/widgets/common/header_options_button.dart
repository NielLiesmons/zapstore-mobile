import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';

/// Round 30×30 options (⋯) button for detail page title rows.
class HeaderOptionsButton extends StatelessWidget {
  const HeaderOptionsButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: c.gray33,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: LabIcon(LabIcons.options, size: 14, color: c.white33),
        ),
      ),
    );
  }
}
