import 'package:flutter/material.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/widgets/common/button.dart';

/// Tabbed feed interface matching webapp's SocialTabs.svelte exactly.
///
/// Tabs: Comments · Zaps · Labels · Details (each a pill button).
/// Tab row is a horizontally scrollable [Row] of [LabButton.tab] widgets —
/// selected tab uses blurple66 gradient, unselected uses gray66.
///
/// Content is driven by [contentBuilder] which receives the active [SocialTab]
/// value.  The parent is responsible for supplying the counts / loading states.
class SocialTabs extends StatefulWidget {
  const SocialTabs({
    super.key,
    required this.contentBuilder,
    this.commentCount,
    this.commentsLoading = false,
    this.zapAmount,
    this.zapsLoading = false,
    this.labelCount,
    this.labelsLoading = false,
    this.showDetailsTab = true,
    this.initialTab = SocialTab.comments,
  });

  /// Builds the content area for the currently active tab.
  final Widget Function(SocialTab activeTab) contentBuilder;

  final int? commentCount;
  final bool commentsLoading;

  /// Total sats received — shown with ⚡ in the Zaps tab button.
  final int? zapAmount;
  final bool zapsLoading;

  final int? labelCount;
  final bool labelsLoading;

  final bool showDetailsTab;
  final SocialTab initialTab;

  @override
  State<SocialTabs> createState() => _SocialTabsState();
}

/// Enum matching the tab ids in webapp's SocialTabs.svelte.
enum SocialTab { comments, zaps, labels, details }

class _SocialTabsState extends State<SocialTabs> {
  late SocialTab _active;

  // Tabs are built lazily: first time a tab is selected, its widget is
  // constructed and added to the IndexedStack where it stays for the lifetime
  // of the screen — no re-fetch when switching back to a visited tab.
  final Set<SocialTab> _visited = {};
  final Map<SocialTab, Widget> _cache = {};

  @override
  void initState() {
    super.initState();
    _active = widget.initialTab;
    // Pre-build the initial tab so it is ready immediately.
    _visited.add(_active);
    _cache[_active] = widget.contentBuilder(_active);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      SocialTab.comments,
      SocialTab.zaps,
      SocialTab.labels,
      if (widget.showDetailsTab) SocialTab.details,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Tab row (horizontally scrollable, gap 8px) ────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: tabs.map((tab) {
              final isSelected = tab == _active;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LabButton.tab(
                  onTap: () {
                    if (_active == tab) return;
                    setState(() {
                      _active = tab;
                      // Build and cache the content only when first visited.
                      _visited.add(tab);
                      _cache.putIfAbsent(tab, () => widget.contentBuilder(tab));
                    });
                  },
                  isSelected: isSelected,
                  child: _TabLabel(
                    tab: tab,
                    isSelected: isSelected,
                    commentCount: widget.commentCount,
                    commentsLoading: widget.commentsLoading,
                    zapAmount: widget.zapAmount,
                    zapsLoading: widget.zapsLoading,
                    labelCount: widget.labelCount,
                    labelsLoading: widget.labelsLoading,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Tab content ───────────────────────────────────────────────────
        // IndexedStack keeps visited tab subtrees alive in the widget tree so
        // their Riverpod providers are not disposed on every switch.
        // Unvisited tabs are SizedBox.shrink() placeholders — no queries are
        // created until the user actually taps that tab.
        IndexedStack(
          index: tabs.indexOf(_active),
          children: tabs.map((tab) {
            if (!_visited.contains(tab)) return const SizedBox.shrink();
            return _cache[tab]!;
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Label widget for each tab button, matching the `.tab-stats` span in
/// SocialTabs.svelte — text + optional count/spinner.
class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.tab,
    required this.isSelected,
    this.commentCount,
    this.commentsLoading = false,
    this.zapAmount,
    this.zapsLoading = false,
    this.labelCount,
    this.labelsLoading = false,
  });

  final SocialTab tab;
  final bool isSelected;
  final int? commentCount;
  final bool commentsLoading;
  final int? zapAmount;
  final bool zapsLoading;
  final int? labelCount;
  final bool labelsLoading;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final fgColor = isSelected ? c.whiteEnforced : c.white;
    final statColor = isSelected ? c.white66 : c.white33;
    final textStyle = LabTextStyles.med15.copyWith(color: fgColor);

    switch (tab) {
      case SocialTab.comments:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Comments', style: textStyle),
            if (commentsLoading) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: c.blurpleLightColor,
                ),
              ),
            ] else if (commentCount != null) ...[
              const SizedBox(width: 6),
              Text(
                _formatCount(commentCount!),
                style: LabTextStyles.med15.copyWith(color: statColor),
              ),
            ],
          ],
        );

      case SocialTab.zaps:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Zaps', style: textStyle),
            if (zapsLoading) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: c.blurpleLightColor,
                ),
              ),
            ] else if (zapAmount != null && zapAmount! > 0) ...[
              const SizedBox(width: 4),
              LabIcon(LabIcons.zap, size: 12, color: statColor),
              const SizedBox(width: 2),
              Text(
                _formatSats(zapAmount!),
                style: LabTextStyles.med13.copyWith(color: statColor),
              ),
            ] else ...[
              const SizedBox(width: 6),
              Text('0', style: LabTextStyles.med13.copyWith(color: statColor)),
            ],
          ],
        );

      case SocialTab.labels:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Labels', style: textStyle),
            if (labelsLoading) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: c.blurpleLightColor,
                ),
              ),
            ] else if (labelCount != null) ...[
              const SizedBox(width: 6),
              Text(
                _formatCount(labelCount!),
                style: LabTextStyles.med13.copyWith(color: statColor),
              ),
            ],
          ],
        );

      case SocialTab.details:
        return Text('Details', style: textStyle);
    }
  }

  static String _formatCount(int n) {
    if (n > 999) return '999+';
    if (n > 99) return '99+';
    return '$n';
  }

  static String _formatSats(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
