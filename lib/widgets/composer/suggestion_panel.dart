import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';

import 'package:zapstore/data/curated_emoji.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'emoji_picker_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SuggestionPanel
//
// Floating suggestion menu rendered via OverlayPortal in NostrComposer so it
// is never clipped by parent containers (modals, etc.).
//
// Styled with LabDropdownMenu (DropdownMenu.svelte parity):
//   gray66 bg + blur(24px), 0.33px white16 border, r16, 0 8px 32px shadow
//
// Tab row: "Profiles / Publications" (@) or "Emoji / GIFs" (:)
//   h26 pills, r6, 13px 500, selected = white16 bg
// Profile rows: 28px avatar, gap 12px, 10px 14px padding, white16 dividers
// Emoji rows: 24px icon, gap 10px, 10px 14px padding, shortcode white66
// Loading spinner in the active tab button + "Loading…" in content area
// "Loading custom emoji…" banner above emoji list when custom init pending
// ─────────────────────────────────────────────────────────────────────────────

class SuggestionPanel extends ConsumerWidget {
  const SuggestionPanel({
    super.key,
    required this.trigger,
    required this.query,
    required this.onSelectMention,
    required this.onSelectEmoji,
  });

  /// `'@'` or `':'`
  final String trigger;
  final String query;

  final void Function(String pubkey, String displayName) onSelectMention;
  final void Function(EmojiEntry entry) onSelectEmoji;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No AnimatedSize — it creates an extra compositing layer inside CTF that
    // fights with BackdropFilter and causes the container to grow unbounded.
    return _SuggestionMenu(
      trigger: trigger,
      query: query,
      onSelectMention: onSelectMention,
      onSelectEmoji: onSelectEmoji,
    );
  }
}

// ── Styled menu box ───────────────────────────────────────────────────────────
// Matches .suggestion-menu CSS: gray33 bg + blur(14px), 0.33px white16 border,
// r12.
//
// Layout trick that properly clips BackdropFilter to rounded corners:
//   outer Container  (clipBehavior: Clip.antiAlias + decoration w/ borderRadius)
//     └─ BackdropFilter (blur confined to the clipped layer rect)
//         └─ inner Container (gray33 fill + content)
//
// Border lives on the outer Container so it renders ON TOP of the blur fill
// without being clipped away.

class _SuggestionMenu extends StatelessWidget {
  const _SuggestionMenu({
    required this.trigger,
    required this.query,
    required this.onSelectMention,
    required this.onSelectEmoji,
  });

  final String trigger;
  final String query;
  final void Function(String pubkey, String displayName) onSelectMention;
  final void Function(EmojiEntry entry) onSelectEmoji;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final isEmoji = trigger == ':';

    // Outer Container establishes the clip layer (antiAlias = rounded rect).
    // BackdropFilter inside is therefore confined to the rounded rect — blur
    // cannot escape past the clip boundary. Border is on the outer decoration
    // so it renders on top of the blur fill.
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: LabBorder.all(color: c.white16, width: LabStroke.thin),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(color: c.gray33),
          child: isEmoji
              ? _EmojiMenu(query: query, onSelect: onSelectEmoji)
              : _ProfileMenu(triggerQuery: query, onSelect: onSelectMention),
        ),
      ),
    );
  }
}

// ── Profile menu (@) ──────────────────────────────────────────────────────────

class _ProfileMenu extends HookConsumerWidget {
  const _ProfileMenu({required this.triggerQuery, required this.onSelect});

  final String triggerQuery;
  final void Function(String pubkey, String displayName) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    // Tab state: "profiles" | "publications"
    final activeTab = useState('profiles');

    final profileState = ref.watch(
      query<Profile>(
        search: triggerQuery.isEmpty ? null : triggerQuery,
        limit: 8,
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          stream: false,
          cachedFor: Duration(minutes: 5),
        ),
        subscriptionPrefix: 'composer-mention-$triggerQuery',
      ),
    );

    final loading = profileState is StorageLoading;
    final items = profileState.models.take(8).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .suggestion-tabs-row { padding: 8px; gap: 4px }
        _TabsRow(
          tabs: [
            _TabDef(
              id: 'profiles',
              label: 'Profiles',
              loadingSpinner: activeTab.value == 'profiles' && loading,
            ),
            const _TabDef(id: 'publications', label: 'Publications'),
          ],
          activeTab: activeTab.value,
          onTabChanged: (t) => activeTab.value = t,
          colors: c,
        ),

        // Content — ConstrainedBox caps the list at 232px so total stays ≤280px.
        // Flexible+Column(mainAxisSize:min) cannot distribute bounded height;
        // direct ConstrainedBox is the reliable alternative.
        if (activeTab.value == 'publications')
          _SuggestionEmpty(label: 'Publications coming soon', colors: c)
        else if (loading && items.isEmpty)
          _SuggestionEmpty(label: 'Loading\u2026', colors: c)
        else if (items.isEmpty)
          _SuggestionEmpty(
              label: triggerQuery.isEmpty
                  ? 'Start typing to search'
                  : 'No profiles found',
              colors: c)
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 232),
            child: _ProfileList(profiles: items, onSelect: onSelect, colors: c),
          ),
      ],
    );
  }
}

// ── Emoji menu (:) ────────────────────────────────────────────────────────────

class _EmojiMenu extends StatefulWidget {
  const _EmojiMenu({required this.query, required this.onSelect});

  final String query;
  final void Function(EmojiEntry entry) onSelect;

  @override
  State<_EmojiMenu> createState() => _EmojiMenuState();
}

class _EmojiMenuState extends State<_EmojiMenu> {
  // Mirrors webapp's `customEmojiInitPending`: shows the loading banner while
  // the custom emoji fetch is in flight. Currently kind 10030/30030 are not
  // yet in the models package, so we simulate the init with a brief delay.
  bool _customEmojiLoading = true;
  String _activeTab = 'emoji';

  @override
  void initState() {
    super.initState();
    // Show loading state briefly to indicate a fetch attempt is happening.
    // Replace with actual Nostr query once kind 10030/30030 models are added.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _customEmojiLoading = false);
    });
  }

  List<EmojiEntry> get _items {
    final q = widget.query.trim().toLowerCase();
    final matches = q.isEmpty
        ? kCuratedEmoji.take(24)
        : kCuratedEmoji.where((e) => e.shortcode.contains(q)).take(12);
    return matches
        .map((e) => EmojiEntry(
              shortcode: e.shortcode,
              display: e.emoji,
              source: EmojiSource.unicode,
            ))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final items = _items;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .suggestion-tabs-row { padding: 8px; gap: 4px }
        _TabsRow(
          tabs: [
            _TabDef(
              id: 'emoji',
              label: 'Emoji',
              loadingSpinner: _activeTab == 'emoji' && _customEmojiLoading,
            ),
            const _TabDef(id: 'gifs', label: 'GIFs'),
          ],
          activeTab: _activeTab,
          onTabChanged: (t) => setState(() => _activeTab = t),
          colors: c,
        ),

        if (_activeTab == 'gifs')
          _SuggestionEmpty(label: 'GIFs coming soon', colors: c)
        else ...[
          // Custom emoji loading banner (matches CUSTOM_EMOJI_LOADING_ROW_HTML)
          if (_customEmojiLoading)
            _CustomEmojiLoadingBanner(colors: c),

          // ConstrainedBox accounts for the loading banner (~38px) so total
          // stays within the 280px cap from _SuggestionMenu.
          if (items.isEmpty)
            _SuggestionEmpty(label: 'No emoji found', colors: c)
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: _customEmojiLoading ? 192 : 232),
              child:
                  _EmojiList(items: items, onSelect: widget.onSelect),
            ),
        ],
      ],
    );
  }
}

// ── Tab row ───────────────────────────────────────────────────────────────────

class _TabDef {
  const _TabDef({
    required this.id,
    required this.label,
    this.loadingSpinner = false,
  });
  final String id;
  final String label;
  final bool loadingSpinner;
}

class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.tabs,
    required this.activeTab,
    required this.onTabChanged,
    required this.colors,
  });

  final List<_TabDef> tabs;
  final String activeTab;
  final ValueChanged<String> onTabChanged;
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    // .suggestion-tabs-row { padding: 8px; display: flex; gap: 4px }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          for (final tab in tabs) ...[
            if (tab != tabs.first) const SizedBox(width: 4),
            _TabButton(
              label: tab.label,
              isSelected: activeTab == tab.id,
              showSpinner: tab.loadingSpinner,
              onTap: () => onTabChanged(tab.id),
              colors: c,
            ),
          ]
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.showSpinner,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final bool isSelected;
  final bool showSpinner;
  final VoidCallback onTap;
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    // .suggestion-tab { h26, px10, r6, 13px 500 }
    // .suggestion-tab-selected { background: white16; color: white }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? c.white16 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? c.white : c.white66,
                height: 1,
              ),
            ),
            if (showSpinner) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: c.white66,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Profile list ──────────────────────────────────────────────────────────────

class _ProfileList extends StatelessWidget {
  const _ProfileList({
    required this.profiles,
    required this.onSelect,
    required this.colors,
  });

  final List<Profile> profiles;
  final void Function(String pubkey, String displayName) onSelect;
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: profiles.length,
      itemBuilder: (_, i) {
        final p = profiles[i];
        final name = p.name ?? p.pubkey.substring(0, 8);
        // profileTextColor(hexToColor(...)) matches MessageBubble's nameColor exactly.
        final nameColor = profileTextColor(hexToColor(p.pubkey));
        return _SuggestionRow(
          onTap: () => onSelect(p.pubkey, name),
          isLast: i == profiles.length - 1,
          colors: c,
          child: Row(
            children: [
              // 28px avatar, circle, white16 border (.suggestion-profile-pic)
              ProfilePic(
                profile: p,
                pubkey: p.pubkey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: nameColor,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Emoji list ────────────────────────────────────────────────────────────────

class _EmojiList extends StatelessWidget {
  const _EmojiList({required this.items, required this.onSelect});

  final List<EmojiEntry> items;
  final void Function(EmojiEntry) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final e = items[i];
        final c = Theme.of(context).extension<LabColors>()!;
        return _SuggestionRow(
          onTap: () => onSelect(e),
          isLast: i == items.length - 1,
          colors: c,
          child: Row(
            children: [
              // .emoji-unicode { font-size: 20; width: 24; text-align: center }
              // .emoji-img { width: 24; height: 24 }
              e.source == EmojiSource.unicode
                  ? SizedBox(
                      width: 24,
                      child: Text(
                        e.display,
                        // Explicit white: emoji rendering respects text opacity;
                        // without this, the Material theme's default semi-transparent
                        // text color makes emoji appear washed out.
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: e.display,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => ShimmerTheme(
                        child: Shimmer(width: 24, height: 24, radius: 4),
                      ),
                      errorWidget: (_, __, ___) =>
                          const SizedBox(width: 24, height: 24),
                    ),
              // .suggestion-menu-emoji .suggestion-item { gap: 10px }
              const SizedBox(width: 10),
              // .emoji-shortcode { font-size: 13; color: white66 }
              Expanded(
                child: Text(
                  e.shortcode,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.white66,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Custom emoji loading banner ───────────────────────────────────────────────

// Matches .suggestion-emoji-custom-loading in ShortTextInput.svelte:
// padding: 8px 12px, border-bottom: 0.33px white8, spinner + text
class _CustomEmojiLoadingBanner extends StatelessWidget {
  const _CustomEmojiLoadingBanner({required this.colors});
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: c.white8, width: LabStroke.thin)),
        ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: c.white66,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading custom emoji\u2026',
            style: TextStyle(fontSize: 13, color: c.white66),
          ),
        ],
      ),
    );
  }
}

// ── Shared suggestion row ─────────────────────────────────────────────────────

// .suggestion-item { padding: 8px 12px; gap varies; border-bottom: 0.33 white8 except last }
// .suggestion-item:hover/.selected { background: white8 }
class _SuggestionRow extends StatefulWidget {
  const _SuggestionRow({
    required this.child,
    required this.onTap,
    required this.isLast,
    required this.colors,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool isLast;
  final LabColors colors;

  @override
  State<_SuggestionRow> createState() => _SuggestionRowState();
}

class _SuggestionRowState extends State<_SuggestionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        // .suggestion-item { padding: 8px 12px }
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          // .suggestion-item:hover { background: var(--white8) }
          color: _pressed ? c.white8 : Colors.transparent,
          // .suggestion-item:not(:last-child) { border-bottom: 0.33px white8 }
          border: widget.isLast
              ? null
              : Border(
                  bottom:
                      BorderSide(color: c.white8, width: LabStroke.thin)),
        ),
        child: widget.child,
      ),
    );
  }
}

// ── Empty / loading states ────────────────────────────────────────────────────

class _SuggestionEmpty extends StatelessWidget {
  const _SuggestionEmpty({required this.label, required this.colors});

  final String label;
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Center(
        child: Text(
          label,
          style: TextStyle(fontSize: 13, color: colors.white33),
        ),
      ),
    );
  }
}
