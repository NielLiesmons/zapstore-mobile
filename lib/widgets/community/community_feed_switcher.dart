import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/selector.dart';

/// Community feed modes on the home screen (webapp section switcher parity).
enum CommunityFeedMode { forum, activity }

/// Outer height of [Selector] (6px padding × 2 + 30px tab).
const double kCommunitySelectorHeight = 42;

/// Section title + Forum/Activity selector.
class CommunityFeedHeader extends ConsumerWidget {
  const CommunityFeedHeader({
    super.key,
    required this.mode,
    required this.onModeChanged,
    this.bottomPadding = 17,
  });

  final CommunityFeedMode mode;
  final ValueChanged<CommunityFeedMode> onModeChanged;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Community',
              style: LabTextStyles.heroTitle.copyWith(color: c.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 168,
            child: Selector(
              initialIndex: mode == CommunityFeedMode.forum ? 0 : 1,
              white8Selection: true,
              containerRadius: kCommunitySelectorHeight / 2,
              tabs: [
                SelectorTab(label: 'Forum'),
                SelectorTab(label: 'Activity'),
              ],
              onChanged: (index) {
                onModeChanged(
                  index == 0
                      ? CommunityFeedMode.forum
                      : CommunityFeedMode.activity,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}