import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';

import 'package:zapstore/models/emoji_list.dart';
import 'package:zapstore/widgets/composer/emoji_picker_modal.dart';

// ── Custom emoji provider ─────────────────────────────────────────────────────
//
// Mirrors the webapp's emoji-search.js behaviour:
//   1. Watch the current user's kind-10030 emoji list.
//   2. For every "a" tag that references a kind-30030 set, watch that set too.
//   3. Return a merged, deduped list of EmojiEntry (custom source, shortcode,
//      image URL) — suitable for prepending to the unicode list.
//
// The tuple result `(loading, entries)` lets callers show the
// CUSTOM_EMOJI_LOADING_ROW_HTML equivalent while the relay fetch is in flight.

/// Result type: (isLoading, customEmojiEntries).
typedef CustomEmojiState = ({bool loading, List<EmojiEntry> entries});

/// Reactive provider that tracks the signed-in user's custom emoji.
///
/// Returns immediately with `(loading: false, entries: [])` when no user is
/// signed in. While the kind-10030 event is being fetched from the relay it
/// returns `(loading: true, entries: [])`. Once loaded, returns the full
/// merged list from the emoji list + any referenced emoji sets.
final customEmojiProvider = Provider.autoDispose<CustomEmojiState>((ref) {
  final pubkey = ref.watch(Signer.activePubkeyProvider);

  if (pubkey == null) {
    return (loading: false, entries: const []);
  }

  // Watch user's kind-10030 emoji list (replaceable — at most one per author).
  final emojiListState = ref.watch(
    query<UserEmojiList>(
      authors: {pubkey},
      source: const LocalAndRemoteSource(
        relays: {'social'},
        cachedFor: Duration(hours: 1),
        stream: false,
      ),
      subscriptionPrefix: 'user-emoji-list',
    ),
  );

  final isListLoading = emojiListState is StorageLoading;
  final emojiList = emojiListState.models.firstOrNull;

  if (emojiList == null) {
    return (loading: isListLoading, entries: const []);
  }

  final entries = <EmojiEntry>[];
  // Deduplicate: shortcode → first-seen entry wins (user list > sets).
  final seen = <String>{};

  void addEntry(String shortcode, String url) {
    final key = shortcode.toLowerCase();
    if (seen.add(key)) {
      entries.add(EmojiEntry(
        shortcode: key,
        display: url,
        source: EmojiSource.custom,
      ));
    }
  }

  // User's directly-listed emoji (highest priority).
  for (final (shortcode, url) in emojiList.emojiEntries) {
    addEntry(shortcode, url);
  }

  // Watch each referenced kind-30030 emoji set.
  bool anySetsLoading = false;
  for (final ref_ in emojiList.emojiSetRefs) {
    final parts = ref_.split(':'); // ['30030', pubkey, identifier]
    if (parts.length < 3) continue;
    final setAuthor = parts[1];
    final setIdentifier = parts[2];

    final setEmojiState = ref.watch(
      query<EmojiSet>(
        authors: {setAuthor},
        tags: {
          '#d': {setIdentifier},
        },
        source: const LocalAndRemoteSource(
          relays: {'social'},
          cachedFor: Duration(hours: 1),
          stream: false,
        ),
        subscriptionPrefix: 'emoji-set-$setIdentifier',
      ),
    );

    if (setEmojiState is StorageLoading) {
      anySetsLoading = true;
    }

    for (final emojiSet in setEmojiState.models) {
      for (final (shortcode, url) in emojiSet.emojiEntries) {
        addEntry(shortcode, url);
      }
    }
  }

  return (loading: isListLoading || anySetsLoading, entries: entries);
});
