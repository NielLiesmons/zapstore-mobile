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

class _BottomBarState extends State<BottomBar> {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

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
              padding: const EdgeInsets.fromLTRB(16, 16, 6, 16),
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

  Widget _buildSignedInBar(AppColors c) {
    return Row(
      children: [
        // Zap button
        AppButton.primary(
          onTap: widget.onZap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppIcons.zap, size: 18, color: c.whiteEnforced),
              const SizedBox(width: 8),
              Text(
                'Zap',
                style: AppTextStyles.med17.copyWith(color: c.whiteEnforced),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Comment input placeholder
        Expanded(
          child: GestureDetector(
            onTap: widget.onComment,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: c.black33,
                borderRadius: BorderRadius.circular(16),
                border: AppBorder.all(color: c.white33, width: 0.33),
              ),
              child: Row(
                children: [
                  AppIcon(
                    AppIcons.reply,
                    size: 18,
                    color: c.white33,
                    outlineColor: c.white33,
                    outlineThickness: 1.4,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.commentPlaceholder,
                    style: AppTextStyles.med17.copyWith(color: c.white33),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Options button
        GestureDetector(
          onTap: widget.onOptions,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: AppIcon(AppIcons.details, size: 20, color: c.white33),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestBar(AppColors c) {
    return Row(
      children: [
        AppButton.primarySmall(
          onTap: widget.onGetStarted,
          text: 'Sign in',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Join the conversation',
            style: AppTextStyles.med17.copyWith(color: c.white66),
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
    final c = Theme.of(context).extension<AppColors>()!;

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
              padding: const EdgeInsets.all(12),
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

  Widget _buildFeedBar(AppColors c) {
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
                AppIcon(
                  AppIcons.plus,
                  size: 16,
                  color: c.whiteEnforced,
                  outlineColor: c.whiteEnforced,
                  outlineThickness: 2.8,
                ),
                const SizedBox(width: 8),
                Text(
                  ctaLabel,
                  style: AppTextStyles.med17.copyWith(color: c.whiteEnforced),
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
                border: AppBorder.all(color: c.white33, width: 0.33),
              ),
              child: Row(
                children: [
                  AppIcon(
                    AppIcons.search,
                    size: 18,
                    color: c.white33,
                    outlineColor: c.white33,
                    outlineThickness: 1.4,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    searchLabel,
                    style: AppTextStyles.med17.copyWith(color: c.white33),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestBar(AppColors c) {
    return Row(
      children: [
        AppButton.primarySmall(
          onTap: onGetStarted,
          text: 'Sign in',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Join the conversation',
            style: AppTextStyles.med17.copyWith(color: c.white66),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
