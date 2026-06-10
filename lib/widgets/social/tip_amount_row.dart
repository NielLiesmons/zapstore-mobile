import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Clickable tip amount row above a comment editor — port of `TipAmountRow.svelte`.
class TipAmountRow extends StatelessWidget {
  const TipAmountRow({
    super.key,
    required this.amountSats,
    this.onEdit,
  });

  final int amountSats;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final formatted = amountSats.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onEdit,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => c.gold.createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: LabIcon(LabIcons.zap, size: 16, color: c.white),
                ),
                const SizedBox(width: 8),
                Text(
                  formatted,
                  style: LabTextStyles.semibold17.copyWith(color: c.white),
                ),
              ],
            ),
          ),
        ),
        Container(height: LabStroke.thin, color: c.white16),
      ],
    );
  }
}
