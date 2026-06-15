import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';

/// Community hub sections — mirrors webapp `/community` sidebar (Forum, Activity, …).
enum CommunitySection { forum, activity }

/// Horizontally scrollable pill tabs matching [SocialTabs] styling.
class CommunitySectionTabs extends StatelessWidget {
  const CommunitySectionTabs({
    super.key,
    required this.active,
    required this.onChanged,
  });

  final CommunitySection active;
  final ValueChanged<CommunitySection> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Row(
        children: [
          _Tab(
            label: 'Forum',
            selected: active == CommunitySection.forum,
            onTap: () => onChanged(CommunitySection.forum),
            c: c,
          ),
          const SizedBox(width: 8),
          _Tab(
            label: 'Activity',
            selected: active == CommunitySection.activity,
            onTap: () => onChanged(CommunitySection.activity),
            c: c,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.c,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return LabButton.tab(
      onTap: onTap,
      isSelected: selected,
      child: Text(
        label,
        style: LabTextStyles.med15.copyWith(
          color: selected ? c.white : c.white66,
        ),
      ),
    );
  }
}
