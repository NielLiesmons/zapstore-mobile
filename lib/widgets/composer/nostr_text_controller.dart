import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';

import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/text_styles.dart';

// ── Embed data types ──────────────────────────────────────────────────────────

sealed class EmbedData {
  const EmbedData();
}

class MentionEmbed extends EmbedData {
  final String pubkey;
  final String displayName;
  const MentionEmbed({required this.pubkey, required this.displayName});
}

class CustomEmojiEmbed extends EmbedData {
  final String shortcode;
  final String url;
  const CustomEmojiEmbed({required this.shortcode, required this.url});
}

// ── Serialization result ──────────────────────────────────────────────────────

class ComposerResult {
  final String text;

  /// NIP-30 custom emoji tags: [(shortcode, imageUrl), ...]
  final List<({String shortcode, String url})> emojiTags;

  /// Pubkeys of mentioned profiles (hex).
  final List<String> mentions;

  /// Media attachment URLs (from block-level attachments, not inline).
  final List<String> mediaUrls;

  const ComposerResult({
    required this.text,
    required this.emojiTags,
    required this.mentions,
    required this.mediaUrls,
  });

  bool get isEmpty => text.isEmpty && mediaUrls.isEmpty;

  static const empty = ComposerResult(
    text: '',
    emojiTags: [],
    mentions: [],
    mediaUrls: [],
  );
}

// ── Controller ────────────────────────────────────────────────────────────────

/// Custom [TextEditingController] with inline [MentionEmbed] and
/// [CustomEmojiEmbed] support via [WidgetSpan].
///
/// The raw text string stores U+FFFC (OBJECT REPLACEMENT CHARACTER) as an
/// atomic placeholder for each inline embed. The N-th U+FFFC in the text maps
/// to [_embeds][N] in insertion order.
///
/// Usage:
/// ```dart
/// final ctrl = NostrTextEditingController();
/// // Insert from a suggestion panel:
/// ctrl.insertMention(pubkey: '...', displayName: 'alice');
/// ctrl.insertCustomEmoji(shortcode: 'zap', url: 'https://...');
/// // Insert plain unicode emoji:
/// ctrl.insertUnicodeEmoji('⚡');
/// // Serialize before publishing:
/// final result = ctrl.serialize();
/// ```
class NostrTextEditingController extends TextEditingController {
  static const String _kEmbed = '\uFFFC';

  /// Embeds in insertion order. The N-th U+FFFC in [text] maps to [_embeds][N].
  final List<EmbedData> _embeds = [];

  String _prevText = '';

  // ── Insertions ────────────────────────────────────────────────────────────

  /// Inserts a mention chip, replacing the `@query` trigger text before cursor.
  void insertMention({required String pubkey, required String displayName}) {
    _insertEmbed(
      trigger: '@',
      embed: MentionEmbed(pubkey: pubkey, displayName: displayName),
    );
  }

  /// Inserts a custom emoji chip, replacing the `:query` trigger text before cursor.
  void insertCustomEmoji({required String shortcode, required String url}) {
    _insertEmbed(
      trigger: ':',
      embed: CustomEmojiEmbed(shortcode: shortcode, url: url),
    );
  }

  /// Inserts a plain unicode emoji at the cursor (no embed needed).
  void insertUnicodeEmoji(String emoji) {
    final offset = selection.isValid ? selection.extentOffset : text.length;
    final newText =
        '${text.substring(0, offset)}$emoji${text.substring(offset)}';
    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset + emoji.length),
    );
  }

  /// Clears all content and resets embed state.
  void clearContent() {
    _embeds.clear();
    _prevText = '';
    value = TextEditingValue.empty;
  }

  bool get hasContent => text.isNotEmpty;

  // ── Serialization ─────────────────────────────────────────────────────────

  /// Produces the Nostr wire format matching webapp's `getSerializedContent()`.
  /// - Mentions → `nostr:npub1…` (hex pubkey encoded)
  /// - Custom emoji → `:shortcode:` + emoji tag collected
  /// - Unicode emoji → rendered inline as-is
  ComposerResult serialize() {
    final buffer = StringBuffer();
    final emojiTags = <({String shortcode, String url})>[];
    final mentions = <String>[];
    int embedIdx = 0;

    for (int i = 0; i < text.length; i++) {
      if (text[i] == _kEmbed && embedIdx < _embeds.length) {
        final embed = _embeds[embedIdx++];
        switch (embed) {
          case MentionEmbed(:final pubkey, :final displayName):
            mentions.add(pubkey);
            try {
              final npub = Utils.encodeShareableFromString(pubkey, type: 'npub');
              buffer.write('nostr:$npub');
            } catch (_) {
              buffer.write('@$displayName');
            }
          case CustomEmojiEmbed(:final shortcode, :final url):
            emojiTags.add((shortcode: shortcode, url: url));
            buffer.write(':$shortcode:');
        }
      } else {
        buffer.write(text[i]);
      }
    }

    return ComposerResult(
      text: buffer.toString().trim(),
      emojiTags: emojiTags,
      mentions: mentions,
      mediaUrls: const [],
    );
  }

  // ── TextEditingController overrides ───────────────────────────────────────

  @override
  set value(TextEditingValue newValue) {
    final prevCount = _countEmbeds(_prevText);
    final newCount = _countEmbeds(newValue.text);

    if (newCount < prevCount) {
      final diff = prevCount - newCount;
      final deletedStart = _findDeletedEmbedStart(_prevText, newValue.text);
      final end = (deletedStart + diff).clamp(0, _embeds.length);
      if (deletedStart < _embeds.length) {
        _embeds.removeRange(deletedStart, end);
      }
    }

    _prevText = newValue.text;
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = <InlineSpan>[];
    int embedIdx = 0;
    int lastPos = 0;
    final str = text;

    for (int i = 0; i < str.length; i++) {
      if (str[i] == _kEmbed) {
        if (i > lastPos) {
          spans.add(TextSpan(text: str.substring(lastPos, i), style: style));
        }
        if (embedIdx < _embeds.length) {
          spans.add(_buildEmbedSpan(context, _embeds[embedIdx], style));
          embedIdx++;
        }
        lastPos = i + 1;
      }
    }

    if (lastPos < str.length) {
      spans.add(TextSpan(text: str.substring(lastPos), style: style));
    }

    if (spans.isEmpty) {
      return TextSpan(style: style);
    }
    return TextSpan(style: style, children: spans);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _insertEmbed({required String trigger, required EmbedData embed}) {
    final t = text;
    final offset = selection.isValid ? selection.extentOffset : t.length;
    final before = t.substring(0, offset);

    // Find and replace the trigger+query that preceded the cursor
    final pattern = trigger == '@' ? RegExp(r'@\S*$') : RegExp(r':\S*$');
    final match = pattern.firstMatch(before);
    final replaceStart = match?.start ?? offset;

    final afterCursor = t.substring(offset);
    // Insert embed char + space (space lets user continue typing naturally)
    final newText = '${t.substring(0, replaceStart)}\uFFFC $afterCursor';

    // Embed index = number of existing U+FFFC chars before replaceStart
    final embedIndex =
        _kEmbed.allMatches(t.substring(0, replaceStart)).length;
    _embeds.insert(embedIndex, embed);

    final newOffset = math.min(replaceStart + 2, newText.length);
    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  InlineSpan _buildEmbedSpan(
    BuildContext context,
    EmbedData embed,
    TextStyle? baseStyle,
  ) {
    switch (embed) {
      case MentionEmbed(:final pubkey, :final displayName):
        final color = hexToColor(pubkey);
        final bgColor = Color.fromARGB(51, color.red, color.green, color.blue);
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '@$displayName',
              style: (baseStyle ?? LabTextStyles.reg15).copyWith(
                color: color,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        );

      case CustomEmojiEmbed(:final url):
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) =>
                  const SizedBox(width: 20, height: 20),
            ),
          ),
        );
    }
  }

  static int _countEmbeds(String text) {
    int count = 0;
    for (int i = 0; i < text.length; i++) {
      if (text[i] == _kEmbed) count++;
    }
    return count;
  }

  static int _findDeletedEmbedStart(String oldText, String newText) {
    int i = 0;
    final minLen = math.min(oldText.length, newText.length);
    while (i < minLen && oldText[i] == newText[i]) {
      i++;
    }
    // Count embed chars before divergence point in old text
    int count = 0;
    for (int j = 0; j < i; j++) {
      if (oldText[j] == _kEmbed) count++;
    }
    return count;
  }
}
