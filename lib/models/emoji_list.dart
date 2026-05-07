import 'package:models/models.dart';

// ── NIP-30 custom emoji models ────────────────────────────────────────────────
//
// Kind 10030: user emoji list (replaceable, one per author)
//   Tags:  ["emoji", shortcode, url]  — emoji directly listed by the user
//          ["a",   "30030:pubkey:id"] — referenced emoji set
//
// Kind 30030: emoji set (parameterizable replaceable, many per author)
//   Tags:  ["emoji", shortcode, url]  — emoji in this set
//          ["d",   identifier]        — unique name/slug of the set
//
// Both are parsed with the same helpers and use the shared EmojiEntry type
// defined in emoji_picker_modal.dart.

/// User-curated emoji list — Nostr kind 10030 (replaceable).
class UserEmojiList extends ReplaceableModel<UserEmojiList> {
  UserEmojiList.fromMap(super.map, super.ref) : super.fromMap();

  /// Registers `UserEmojiList` ↔ kind 10030 with the models registry.
  /// Call once during app initialization (before storage is needed).
  static void register() {
    Model.register<UserEmojiList>(
      kind: 10030,
      constructor: UserEmojiList.fromMap,
    );
  }

  /// All `["emoji", shortcode, url]` tags as `(shortcode, url)` pairs.
  List<(String shortcode, String url)> get emojiEntries {
    return event
        .getTagSet('emoji')
        .where((t) => t.length >= 3)
        .map((t) => (t[1], t[2]))
        .toList(growable: false);
  }

  /// `a`-tag coordinates that reference kind-30030 emoji sets.
  /// Format of each value: `"30030:pubkey:identifier"`.
  List<String> get emojiSetRefs {
    return event
        .getTagSet('a')
        .where((t) => t.length >= 2 && t[1].startsWith('30030:'))
        .map((t) => t[1])
        .toList(growable: false);
  }
}

/// Named emoji set — Nostr kind 30030 (parameterizable replaceable).
class EmojiSet extends ParameterizableReplaceableModel<EmojiSet> {
  EmojiSet.fromMap(super.map, super.ref) : super.fromMap();

  /// Registers `EmojiSet` ↔ kind 30030 with the models registry.
  /// Call once during app initialization (before storage is needed).
  static void register() {
    Model.register<EmojiSet>(
      kind: 30030,
      constructor: EmojiSet.fromMap,
    );
  }

  /// Human-readable name (`title` tag value, optional).
  String? get title => event.getFirstTagValue('title');

  /// All `["emoji", shortcode, url]` tags as `(shortcode, url)` pairs.
  List<(String shortcode, String url)> get emojiEntries {
    return event
        .getTagSet('emoji')
        .where((t) => t.length >= 3)
        .map((t) => (t[1], t[2]))
        .toList(growable: false);
  }
}
