import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';

/// Fixed bottom action bar matching webapp's BottomBar.svelte.
///
/// Displays a Zap button, Comment input placeholder, and Options button.
/// Morphs into comment input when Comment is tapped.
/// Slides out when [modalOpen] is true (e.g. zap slider open).
class BottomBar extends StatefulWidget {
  const BottomBar({
    super.key,
    this.isSignedIn = true,
    this.modalOpen = false,
    this.onZap,
    this.onComment,
    this.onOptions,
    this.onGetStarted,
    this.commentPlaceholder = 'Comment',
  });

  final bool isSignedIn;
  final bool modalOpen;
  final VoidCallback? onZap;
  final VoidCallback? onComment;
  final VoidCallback? onOptions;
  final VoidCallback? onGetStarted;
  final String commentPlaceholder;

  @override
  State<BottomBar> createState() => _BottomBarState();
}

/// Trailing options (⋯) hit area: **41px tall**, **37px wide** (4px narrower
/// than height). Icon is geometrically centered in that box; nominal size is
/// ~68% of height so the glyph reads balanced vs the 20px zap icon.
class BottomBarOptionsHitBox extends StatelessWidget {
  const BottomBarOptionsHitBox({super.key, this.onTap});

  final VoidCallback? onTap;

  static const double height = 41;
  static const double width = height - 4;
  static double get iconNominalSize => height * 0.68;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: LabIcon(
            LabIcons.options,
            size: iconNominalSize,
            color: c.white33,
          ),
        ),
      ),
    );
  }
}

class _BottomBarState extends State<BottomBar> {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return AnimatedSlide(
      offset: widget.modalOpen ? const Offset(0, 1) : Offset.zero,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: widget.modalOpen ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: c.gray66,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(color: c.white8, width: 0.33),
                  left: BorderSide(color: c.white8, width: 0.33),
                  right: BorderSide(color: c.white8, width: 0.33),
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.black,
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                14,
                14,
                widget.isSignedIn ? 6 : 14,
                6,
              ),
              child: SafeArea(
                top: false,
                child: widget.isSignedIn
                    ? _buildSignedInBar(c)
                    : _buildGuestBar(c),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignedInBar(LabColors c) {
    return Row(
      children: [
        // Zap button — 41px, icon only, blurple gradient
        GestureDetector(
          onTap: widget.onZap,
          child: Container(
            width: 41,
            height: 41,
            decoration: BoxDecoration(
              gradient: c.blurple,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Center(
              child: LabIcon(LabIcons.zap, size: 20, color: c.whiteEnforced),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Comment input placeholder — 41px
        Expanded(
          child: GestureDetector(
            onTap: widget.onComment,
            child: Container(
              height: 41,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.black33,
                borderRadius: BorderRadius.circular(17),
                border: LabBorder.all(color: c.white33, width: 0.33),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LabIcon(LabIcons.reply, size: 16, color: c.white33),
                  const SizedBox(width: 8),
                  Text(
                    widget.commentPlaceholder,
                    style: LabTextStyles.med15.copyWith(color: c.white33),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Options button — square hit target; see [BottomBarOptionsHitBox].
        BottomBarOptionsHitBox(onTap: widget.onOptions),
      ],
    );
  }

  Widget _buildGuestBar(LabColors c) {
    return Row(
      children: [
        LabButton.primarySmall(
          onTap: widget.onGetStarted,
          text: 'Sign in',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Join the conversation',
            style: LabTextStyles.med15.copyWith(color: c.white66),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Community feed bottom bar matching CommunityBottomBar.svelte.
///
/// Shows a + Post button and Search Forum input placeholder.
class CommunityBottomBar extends StatelessWidget {
  const CommunityBottomBar({
    super.key,
    this.isSignedIn = true,
    this.modalOpen = false,
    this.ctaLabel = 'Post',
    this.searchLabel = 'Search Forum',
    this.onAdd,
    this.onSearch,
    this.onGetStarted,
  });

  final bool isSignedIn;
  final bool modalOpen;
  final String ctaLabel;
  final String searchLabel;
  final VoidCallback? onAdd;
  final VoidCallback? onSearch;
  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return AnimatedSlide(
      offset: modalOpen ? const Offset(0, 1) : Offset.zero,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: modalOpen ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: c.gray66,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(color: c.white8, width: 0.33),
                  left: BorderSide(color: c.white8, width: 0.33),
                  right: BorderSide(color: c.white8, width: 0.33),
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.black,
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: SafeArea(
                top: false,
                child: isSignedIn
                    ? _buildFeedBar(c)
                    : _buildGuestBar(c),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedBar(LabColors c) {
    return Row(
      children: [
        // + Post button
        GestureDetector(
          onTap: onAdd,
          child: Container(
            height: 38,
            padding: const EdgeInsets.fromLTRB(14, 0, 20, 0),
            decoration: BoxDecoration(
              gradient: c.blurple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LabIcon(
                  LabIcons.plus,
                  size: 16,
                  color: c.whiteEnforced,
                  thick: true,
                ),
                const SizedBox(width: 8),
                Text(
                  ctaLabel,
                  style: LabTextStyles.med17.copyWith(color: c.whiteEnforced),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Search Forum input
        Expanded(
          child: GestureDetector(
            onTap: onSearch,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: c.black33,
                borderRadius: BorderRadius.circular(16),
                border: LabBorder.all(color: c.white33, width: 0.33),
              ),
              child: Row(
                children: [
                  LabIcon(
                    LabIcons.search,
                    size: 18,
                    color: c.white33,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    searchLabel,
                    style: LabTextStyles.med17.copyWith(color: c.white33),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestBar(LabColors c) {
    return Row(
      children: [
        LabButton.primarySmall(
          onTap: onGetStarted,
          text: 'Sign in',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Join the conversation',
            style: LabTextStyles.med17.copyWith(color: c.white66),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
