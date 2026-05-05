import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:zapstore/data/curated_emoji.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/common/shimmer.dart';

// ── Data model ────────────────────────────────────────────────────────────────

enum EmojiSource { unicode, custom }

class EmojiEntry {
  final String shortcode;

  /// Unicode: the unicode character(s) string.
  /// Custom: the image URL.
  final String display;
  final EmojiSource source;

  const EmojiEntry({
    required this.shortcode,
    required this.display,
    required this.source,
  });
}

// ── Pre-built list from curated_emoji.dart ────────────────────────────────────

final _unicodeEntries = kCuratedEmoji
    .map((e) => EmojiEntry(
          shortcode: e.shortcode,
          display: e.emoji,
          source: EmojiSource.unicode,
        ))
    .toList(growable: false);

// ── Public API ────────────────────────────────────────────────────────────────

/// Shows the emoji picker as a stacked bottom sheet (50 % of screen height,
/// no separate dark backdrop — matches webapp EmojiPickerModal.svelte).
///
/// Handles the [ModalNestScope] scale-down of any parent modal automatically.
///
/// Returns the selected [EmojiEntry], or `null` if the user dismisses.
Future<EmojiEntry?> showEmojiPicker(BuildContext context) async {
  ModalNestScope.setNested(context, isOpen: true);
  final result = await showModal<EmojiEntry>(
    context,
    maxHeightFactor: 0.5,
    fillHeight: true,
    builder: (_) => const _EmojiPickerContent(),
  );
  if (context.mounted) {
    ModalNestScope.setNested(context, isOpen: false);
  }
  return result;
}

// ── Content widget ────────────────────────────────────────────────────────────

class _EmojiPickerContent extends HookConsumerWidget {
  const _EmojiPickerContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final query = useState('');
    final searchCtrl = useTextEditingController();
    final customEmojis = useState<List<EmojiEntry>>([]);
    final loadingCustom = useState(false);

    // Load NIP-30 custom emoji (kind 10030 / 30030).
    // TODO: replace with actual Riverpod query once those kinds are in the
    // models package. For now we show the loading banner for a realistic
    // duration then clear it (matching webapp's customEmojiInitPending state).
    useEffect(() {
      loadingCustom.value = true;
      var cancelled = false;
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!cancelled) loadingCustom.value = false;
      });
      return () => cancelled = true;
    }, const []);

    final displayEmojis = useMemoized(() {
      final q = query.value.trim().toLowerCase();
      final all = [...customEmojis.value, ..._unicodeEntries];
      if (q.isEmpty) return all;
      return all
          .where((e) => e.shortcode.toLowerCase().contains(q))
          .toList(growable: false);
    }, [query.value, customEmojis.value]);

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Search field ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _SearchField(
            controller: searchCtrl,
            onChanged: (v) => query.value = v,
            colors: c,
          ),
        ),

        // ── Scrollable body ──────────────────────────────────────────────────
        Expanded(
          child: _PickerBody(
            displayEmojis: displayEmojis,
            loadingCustom: loadingCustom.value,
            query: query.value,
            colors: c,
          ),
        ),
      ],
    );
  }
}

// ── Search field (40px, black33 bg, white33 border, r16) ─────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.colors,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: c.black33,
        borderRadius: BorderRadius.circular(LabRadius.r16),
        border: LabBorder.all(color: c.white33, width: LabStroke.thin),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          LabIcon(LabIcons.search, size: 18, color: c.white33),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: false,
              textCapitalization: TextCapitalization.none,
              style: LabTextStyles.reg15.copyWith(color: c.white),
              cursorColor: c.white,
              cursorWidth: 1.6,
              decoration: InputDecoration(
                hintText: 'Search emoji',
                hintStyle: LabTextStyles.reg15.copyWith(color: c.white33),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

// ── Body (loading banner + grid) ─────────────────────────────────────────────

class _PickerBody extends StatelessWidget {
  const _PickerBody({
    required this.displayEmojis,
    required this.loadingCustom,
    required this.query,
    required this.colors,
  });

  final List<EmojiEntry> displayEmojis;
  final bool loadingCustom;
  final String query;
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;

    return CustomScrollView(
      slivers: [
        // ── Custom emoji loading banner ─────────────────────────────────────
        if (loadingCustom)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: c.black33,
                  borderRadius: BorderRadius.circular(LabRadius.r16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: c.white33,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading custom emoji…',
                      style: LabTextStyles.med13.copyWith(color: c.white33),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Empty state ─────────────────────────────────────────────────────
        if (displayEmojis.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(
                query.isNotEmpty
                    ? 'No emoji found for "$query"'
                    : 'No emoji available',
                style: LabTextStyles.reg13.copyWith(color: c.white33),
              ),
            ),
          )

        // ── Emoji grid ──────────────────────────────────────────────────────
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            sliver: SliverLayoutBuilder(
              builder: (context, sliverConstraints) {
                // auto-fill: minmax(40px, 1fr) matches webapp emoji-grid
                const minTile = 40.0;
                const gap = 2.0;
                final cols = ((sliverConstraints.crossAxisExtent + gap) /
                        (minTile + gap))
                    .floor()
                    .clamp(1, 20);
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _EmojiTile(
                      entry: displayEmojis[index],
                      onTap: () =>
                          Navigator.of(context).pop(displayEmojis[index]),
                    ),
                    childCount: displayEmojis.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: 1,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Emoji tile (EmojiItem.svelte port) ───────────────────────────────────────

class _EmojiTile extends StatefulWidget {
  const _EmojiTile({required this.entry, required this.onTap});

  final EmojiEntry entry;
  final VoidCallback onTap;

  @override
  State<_EmojiTile> createState() => _EmojiTileState();
}

class _EmojiTileState extends State<_EmojiTile> {
  bool _pressed = false;
  bool _imgLoaded = false;
  bool _imgError = false;

  // tile size = 36px, img = 78% of 36 = ~28px, char fontSize = 72% = ~26px
  static const double _tileSize = 36;
  static const double _imgSize = _tileSize * 0.78;
  static const double _charSize = _tileSize * 0.72;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: _tileSize,
          height: _tileSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _pressed ? c.white11 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: widget.entry.source == EmojiSource.unicode
              ? Text(
                  widget.entry.display,
                  style: const TextStyle(
                    fontSize: _charSize,
                    height: 1,
                    // Explicit white: emoji rendering respects text opacity;
                    // without this the Material theme's semi-transparent default
                    // text color makes emoji appear washed out.
                    color: Colors.white,
                  ),
                )
              : _buildCustomImg(c),
        ),
      ),
    );
  }

  Widget _buildCustomImg(LabColors c) {
    if (_imgError) {
      return Text(
        '?',
        style: LabTextStyles.reg13.copyWith(color: c.white33),
      );
    }
    return SizedBox(
      width: _imgSize,
      height: _imgSize,
      child: Stack(
        children: [
          // Shimmer while loading (matches emoji-skeleton in EmojiItem.svelte)
          if (!_imgLoaded)
            ShimmerTheme(
              child: Shimmer(
                width: _imgSize,
                height: _imgSize,
                radius: 4,
              ),
            ),
          CachedNetworkImage(
            imageUrl: widget.entry.display,
            width: _imgSize,
            height: _imgSize,
            fit: BoxFit.contain,
            imageBuilder: (_, imageProvider) {
              if (!_imgLoaded) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => setState(() => _imgLoaded = true));
              }
              return Image(image: imageProvider, fit: BoxFit.contain);
            },
            errorWidget: (_, __, ___) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => setState(() => _imgError = true));
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
