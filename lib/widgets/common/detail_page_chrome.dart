import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/dropdown_menu.dart';
import 'package:zapstore/widgets/common/profile_pic_stack.dart';

/// Author avatar size on detail pages — matches [kDetailActionsButtonSize].
const double kDetailAuthorAvatarSize = 44;

/// Community stack avatars in the author meta column.
const double kDetailCommunityAvatarSize = 22;

/// Floating actions button — same footprint as [kDetailAuthorAvatarSize].
const double kDetailActionsButtonSize = 44;

/// Actions button width + gap before scroll content (meta row timestamp, etc.).
const double kDetailActionsButtonGutter = kDetailActionsButtonSize + 14;

/// Short npub-style label for unknown authors.
String detailShortPubkey(String pubkey) {
  if (pubkey.length <= 12) return pubkey;
  return '${pubkey.substring(0, 6)}…${pubkey.substring(pubkey.length - 4)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating round actions button (top-right, highest z-index)
// ─────────────────────────────────────────────────────────────────────────────

/// Drop shadow shared by floating actions + scroll-to-top controls.
List<BoxShadow> detailActionsButtonShadow(LabColors c) => [
      BoxShadow(
        color: c.black.withValues(alpha: 0.5),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];

// ─────────────────────────────────────────────────────────────────────────────
// Author meta row — pic + name column (community below name); actions overlay
// ─────────────────────────────────────────────────────────────────────────────

class DetailAuthorMetaRow extends StatelessWidget {
  const DetailAuthorMetaRow({
    super.key,
    required this.leading,
    required this.title,
    this.timestamp,
    this.trailing,
    this.onAuthorTap,
  });

  final Widget leading;
  final String title;
  final Widget? timestamp;
  final Widget? trailing;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: kDetailAuthorAvatarSize,
                  height: kDetailAuthorAvatarSize,
                  child: Center(
                    child: onAuthorTap != null
                        ? GestureDetector(
                            onTap: onAuthorTap,
                            behavior: HitTestBehavior.opaque,
                            child: leading,
                          )
                        : leading,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: onAuthorTap != null
                              ? GestureDetector(
                                  onTap: onAuthorTap,
                                  behavior: HitTestBehavior.opaque,
                                  child: Text(
                                    title,
                                    style: LabTextStyles.med15
                                        .copyWith(color: c.white66),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                )
                              : Text(
                                  title,
                                  style: LabTextStyles.med15
                                      .copyWith(color: c.white66),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                        ),
                        if (timestamp != null) ...[
                          const SizedBox(width: 14),
                          timestamp!,
                        ],
                      ],
                    ),
                    if (trailing != null) ...[
                      const SizedBox(height: 3),
                      trailing!,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: kDetailActionsButtonGutter),
            ],
          ),
        ),
        Container(height: 1, color: c.white11),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Community stack + dropdown (below author name in meta column)
// ─────────────────────────────────────────────────────────────────────────────

class DetailCommunityMenu extends HookWidget {
  const DetailCommunityMenu({
    super.key,
    required this.groupId,
    required this.menuTitle,
    required this.items,
  });

  final String groupId;
  final String menuTitle;
  final List<ProfilePicItem> items;

  static String _communityLabel(List<ProfilePicItem> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) {
      final name = items.first.profile?.name?.trim();
      return 'In ${name?.isNotEmpty == true ? name! : 'Community'}';
    }
    return 'In ${items.length} Communities';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final c = Theme.of(context).extension<LabColors>()!;
    final overlayController = useMemoized(() => OverlayPortalController());
    final layerLink = useMemoized(() => LayerLink());
    final label = _communityLabel(items);

    return OverlayPortal(
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
            onTapOutside: (_) => overlayController.hide(),
            child: LabDropdownMenu(
              constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
              children: [
                LabDropdownItem(
                  isFirst: true,
                  child: Text(
                    menuTitle,
                    style: LabTextStyles.reg13.copyWith(color: c.white66),
                  ),
                ),
                for (final item in items)
                  LabDropdownItem(
                    child: Text(item.profile?.name ?? 'Community'),
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
          child: ProfilePicStack(
            profiles: items,
            avatarSize: kDetailCommunityAvatarSize,
            text: label,
            pillTextColor: c.white33,
            showPillBackground: false,
            textLeadingPadding: 12,
            onTap: () {
              if (overlayController.isShowing) {
                overlayController.hide();
              } else {
                overlayController.show();
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Fixed top-right actions control — circle at rest, widens into a pill on scroll.
class DetailActionsButtonOverlay extends StatelessWidget {
  const DetailActionsButtonOverlay({
    super.key,
    required this.onTap,
    required this.scrollController,
    required this.expandLabel,
    this.expandStartOffset = 56,
  });

  final VoidCallback onTap;
  final ScrollController scrollController;
  final String expandLabel;
  final double expandStartOffset;

  static const double _labelLeftPad = 14;
  static const double _dividerWidth = 1;

  double _labelWidth(BuildContext context, double maxLabelWidth) {
    final style = LabTextStyles.med15.copyWith(
      color: Theme.of(context).extension<LabColors>()!.white66,
    );
    final painter = TextPainter(
      text: TextSpan(text: expandLabel, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxLabelWidth);
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final c = Theme.of(context).extension<LabColors>()!;
    final maxPillWidth = MediaQuery.sizeOf(context).width - 28;
    final maxLabelTextWidth = maxPillWidth -
        kDetailActionsButtonSize -
        _labelLeftPad -
        _dividerWidth;

    return Positioned(
      top: topPad + 20,
      right: 14,
      child: ListenableBuilder(
        listenable: scrollController,
        builder: (context, _) {
          final offset =
              scrollController.hasClients ? scrollController.offset : 0.0;
          final t =
              ((offset - expandStartOffset) / 28.0).clamp(0.0, 1.0);
          final labelW = _labelWidth(context, maxLabelTextWidth)
              .clamp(0.0, maxLabelTextWidth);
          final expandedExtra = _labelLeftPad + labelW + _dividerWidth;
          final pillWidth = (kDetailActionsButtonSize + expandedExtra * t)
              .clamp(kDetailActionsButtonSize, maxPillWidth);
          final labelAreaWidth =
              (pillWidth - kDetailActionsButtonSize).clamp(0.0, double.infinity);
          final radius = kDetailActionsButtonSize / 2;
          final labelStyle = LabTextStyles.med15.copyWith(color: c.white66);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: detailActionsButtonShadow(c),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  clipBehavior: Clip.hardEdge,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      width: pillWidth,
                      height: kDetailActionsButtonSize,
                      decoration: BoxDecoration(
                        color: c.gray66,
                        borderRadius: BorderRadius.circular(radius),
                        border: LabBorder.all(
                          color: c.white16,
                          width: LabStroke.thin,
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                        if (labelAreaWidth > 0)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: labelAreaWidth,
                            child: Opacity(
                              opacity: t,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: _labelLeftPad,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          expandLabel,
                                          style: labelStyle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  ColoredBox(
                                    color: c.white16,
                                    child: const SizedBox(
                                      width: _dividerWidth,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          top: 0,
                          width: kDetailActionsButtonSize,
                          height: kDetailActionsButtonSize,
                          child: Center(
                            child: LabIcon(
                              LabIcons.options,
                              size: 22,
                              color: c.white33,
                            ),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
