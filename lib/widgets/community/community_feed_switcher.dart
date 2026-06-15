import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/dropdown_menu.dart';
import 'package:zapstore/widgets/social/thread_root.dart' show kForumEmojiAsset;

/// Community feed modes on the home screen (webapp section switcher parity).
enum CommunityFeedMode { forum, activity }

const String kActivityEmojiAsset = 'assets/images/emoji/activity.png';

/// Section title + chevron dropdown to switch Forum / Activity feeds.
class CommunityFeedHeader extends HookWidget {
  const CommunityFeedHeader({
    super.key,
    required this.mode,
    required this.onModeChanged,
    this.isLoading = false,
    this.bottomPadding = 17,
  });

  final CommunityFeedMode mode;
  final ValueChanged<CommunityFeedMode> onModeChanged;
  final bool isLoading;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final overlayController = useMemoized(() => OverlayPortalController());
    final layerLink = useMemoized(() => LayerLink());
    final isOpen = useState(false);

    void dismiss() {
      overlayController.hide();
      isOpen.value = false;
    }

    void toggle() {
      if (isOpen.value) {
        dismiss();
      } else {
        overlayController.show();
        isOpen.value = true;
      }
    }

    const groupId = 'community-feed-switcher';

    final title = mode == CommunityFeedMode.forum ? 'Forum' : 'Activity';

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OverlayPortal(
            controller: overlayController,
            overlayChildBuilder: (ctx) => CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 4),
              child: Align(
                alignment: Alignment.topLeft,
                child: TapRegion(
                  groupId: groupId,
                  onTapOutside: (_) => dismiss(),
                  child: LabDropdownMenu(
                    constraints: const BoxConstraints(minWidth: 200),
                    children: [
                      _FeedMenuItem(
                        label: 'Forum',
                        emojiAsset: kForumEmojiAsset,
                        isActive: mode == CommunityFeedMode.forum,
                        isFirst: true,
                        onTap: () {
                          onModeChanged(CommunityFeedMode.forum);
                          dismiss();
                        },
                      ),
                      _FeedMenuItem(
                        label: 'Activity',
                        emojiAsset: kActivityEmojiAsset,
                        isActive: mode == CommunityFeedMode.activity,
                        onTap: () {
                          onModeChanged(CommunityFeedMode.activity);
                          dismiss();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: TapRegion(
              groupId: groupId,
              child: CompositedTransformTarget(
                link: layerLink,
                child: GestureDetector(
                  onTap: toggle,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontVariations: const [FontVariation('wght', 650)],
                          fontSize: 22,
                          height: 1.0,
                          letterSpacing: 0.15,
                          leadingDistribution: TextLeadingDistribution.even,
                          color: c.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: isOpen.value ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: LabIcon(
                          LabIcons.chevronDown,
                          size: 16,
                          color: c.white33,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (isLoading)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: c.white33,
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedMenuItem extends StatelessWidget {
  const _FeedMenuItem({
    required this.label,
    required this.emojiAsset,
    required this.isActive,
    required this.onTap,
    this.isFirst = false,
  });

  final String label;
  final String emojiAsset;
  final bool isActive;
  final VoidCallback onTap;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return LabDropdownItem(
      isFirst: isFirst,
      isActive: isActive,
      onTap: onTap,
      child: Row(
        children: [
          Image.asset(
            emojiAsset,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: LabTextStyles.med15.copyWith(
              color: isActive ? c.white : c.white66,
            ),
          ),
        ],
      ),
    );
  }
}
