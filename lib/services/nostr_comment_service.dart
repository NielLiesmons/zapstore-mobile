import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';

import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/models/forum_post.dart';
import 'package:zapstore/widgets/composer/nostr_text_controller.dart';

// ── NIP-22 kind-1111 comment publishing ───────────────────────────────────────
//
// Mirrors webapp's publishComment() in service.js.
//
// Tag layout (NIP-22):
//   Root (uppercase):  A or E  +  K  +  P       (relay hint on A/E)
//   Root mirror (top-level only):  a or e  +  k  +  p
//   Parent (reply only):  e  +  k  +  p
//   Custom emoji:  emoji  (NIP-30)
//   Mentions:  p  (deduped)
//   Media:  media
//   Version:  v  (app/stack root only)
//
// Relay hint used on all uppercase A/E and lowercase e/a tags:
//   wss://relay.zapstore.dev  (kDefaultRelay from app_constants.dart)
//
// Publishing targets:
//   'AppCatalog' relay group (includes relay.zapstore.dev) — saved + published.
//   'social' relay group — best-effort, fire-and-forget.

// ── Public API ────────────────────────────────────────────────────────────────

/// Publishes a NIP-22 kind-1111 comment on a root Nostr model.
///
/// Exactly one of [app], [forumPost], or [stack] must be supplied as the root
/// target. [version] is included as a `v` tag on app and stack root comments.
///
/// [result] is the serialized output of [NostrTextEditingController.serialize]:
/// plain text with inline `nostr:npub…` / `:shortcode:` markers, plus the
/// [ComposerResult.emojiTags] and [ComposerResult.mentions] lists needed to
/// build the correct NIP-22 + NIP-30 tag set.
Future<void> publishRootComment({
  required WidgetRef ref,
  required ComposerResult result,
  App? app,
  ForumPost? forumPost,
  AppStack? stack,
  String? version,
}) async {
  assert(
    [app, forumPost, stack].where((x) => x != null).length == 1,
    'Exactly one root target must be supplied',
  );
  if (result.isEmpty) return;

  final signer = ref.read(Signer.activeSignerProvider);
  if (signer == null) throw Exception('Sign in to post a comment');

  final partial = PartialComment(content: result.text);

  // Root tags (uppercase) + mirror as lowercase for top-level comments
  _addRootTags(partial, app: app, forumPost: forumPost, stack: stack);

  // Version tag — only on root app/stack comments (matches webapp)
  if (version != null && version.trim().isNotEmpty && forumPost == null) {
    partial.event.addTagValue('v', version.trim());
  }

  final seenP = _rootPubkeys(app: app, forumPost: forumPost, stack: stack);
  _addBodyTags(partial, result: result, seenP: seenP);

  final signed = await partial.signWith(signer);
  final storage = ref.read(storageNotifierProvider.notifier);
  await storage.save({signed});
  storage.publish({signed}, relays: {'AppCatalog', 'social'});
}

/// Publishes a NIP-22 kind-1111 reply to [parentComment].
///
/// The root context (uppercase A/E + K + P) is copied from [parentComment]'s
/// own event tags, so the full thread chain is preserved regardless of how
/// deeply nested the reply is.
Future<void> publishReplyComment({
  required WidgetRef ref,
  required ComposerResult result,
  required Comment parentComment,
}) async {
  if (result.isEmpty) return;

  final signer = ref.read(Signer.activeSignerProvider);
  if (signer == null) throw Exception('Sign in to reply');

  final partial = PartialComment(content: result.text);

  // Copy root tags from parent comment
  _copyRootTags(partial, from: parentComment);

  // Immediate parent tags: lowercase e + k (1111) + p
  _addParentTags(partial, parent: parentComment);

  // Body tags (emoji, mentions, media) — dedup against already-added p tags
  final seenP = <String>{
    parentComment.event.pubkey.toLowerCase(),
    ..._extractRootPubkeys(parentComment),
  };
  _addBodyTags(partial, result: result, seenP: seenP);

  final signed = await partial.signWith(signer);
  final storage = ref.read(storageNotifierProvider.notifier);
  await storage.save({signed});
  storage.publish({signed}, relays: {'AppCatalog', 'social'});
}

// ── Tag builders ──────────────────────────────────────────────────────────────

/// Adds uppercase A/E + K + P root tags (with relay hint) and mirrors them as
/// lowercase a/e + k + p (top-level comment — no separate parent).
void _addRootTags(
  PartialComment partial, {
  App? app,
  ForumPost? forumPost,
  AppStack? stack,
}) {
  const relay = kDefaultRelay;

  if (app != null) {
    final a = '32267:${app.pubkey}:${app.identifier}';
    partial.event.addTag('A', [a, relay]);
    partial.event.addTagValue('K', '32267');
    partial.event.addTagValue('P', app.pubkey.toLowerCase());
    // Mirror as lowercase — only on root-level (no parent comment)
    partial.event.addTag('a', [a, relay]);
    partial.event.addTagValue('k', '32267');
    partial.event.addTagValue('p', app.pubkey.toLowerCase());
  } else if (stack != null) {
    final a = '30267:${stack.pubkey}:${stack.identifier}';
    partial.event.addTag('A', [a, relay]);
    partial.event.addTagValue('K', '30267');
    partial.event.addTagValue('P', stack.pubkey.toLowerCase());
    partial.event.addTag('a', [a, relay]);
    partial.event.addTagValue('k', '30267');
    partial.event.addTagValue('p', stack.pubkey.toLowerCase());
  } else if (forumPost != null) {
    final k = forumPost.event.kind.toString();
    partial.event.addTag('E', [forumPost.id, relay]);
    partial.event.addTagValue('K', k);
    partial.event.addTagValue('P', forumPost.pubkey.toLowerCase());
    partial.event.addTag('e', [forumPost.id, relay]);
    partial.event.addTagValue('k', k);
    partial.event.addTagValue('p', forumPost.pubkey.toLowerCase());
  }
}

/// Copies the uppercase root tags (A/E + K + P) from [from]'s event tags,
/// injecting the relay hint into A/E if not already present.
void _copyRootTags(PartialComment partial, {required Comment from}) {
  const relay = kDefaultRelay;
  final tags = from.event.tags;

  String? aTag;
  String? eTag;
  String? kTag;
  String? pTag;

  for (final tag in tags) {
    if (tag.length >= 2) {
      switch (tag[0]) {
        case 'A':
          aTag ??= tag[1];
        case 'E':
          eTag ??= tag[1];
        case 'K':
          kTag ??= tag[1];
        case 'P':
          pTag ??= tag[1];
      }
    }
  }

  if (aTag != null) {
    partial.event.addTag('A', [aTag, relay]);
  } else if (eTag != null) {
    partial.event.addTag('E', [eTag, relay]);
  }
  if (kTag != null) partial.event.addTagValue('K', kTag);
  if (pTag != null) partial.event.addTagValue('P', pTag.toLowerCase());
}

/// Adds lowercase e (with relay hint) + k (1111) + p for the immediate parent.
void _addParentTags(PartialComment partial, {required Comment parent}) {
  partial.event.addTag('e', [parent.id, kDefaultRelay]);
  partial.event.addTagValue('k', '1111');
  partial.event.addTagValue('p', parent.event.pubkey.toLowerCase());
}

// ── Body tag helpers ──────────────────────────────────────────────────────────

/// Returns the set of pubkeys already added as root-level p/P tags so they
/// can be excluded from mention deduplication.
Set<String> _rootPubkeys({App? app, ForumPost? forumPost, AppStack? stack}) {
  if (app != null) return {app.pubkey.toLowerCase()};
  if (forumPost != null) return {forumPost.pubkey.toLowerCase()};
  if (stack != null) return {stack.pubkey.toLowerCase()};
  return {};
}

/// Collects the uppercase P tag values from [comment] (the root author pubkeys).
Set<String> _extractRootPubkeys(Comment comment) {
  final result = <String>{};
  for (final tag in comment.event.tags) {
    if (tag.length >= 2 && tag[0] == 'P') {
      result.add(tag[1].toLowerCase());
    }
  }
  return result;
}

/// Appends NIP-30 emoji tags, mention p tags, and media tags to [partial].
///
/// [seenP] is pre-populated with pubkeys that already appear in the root / parent
/// p/P tags so the dedup logic stays consistent with the webapp.
void _addBodyTags(
  PartialComment partial, {
  required ComposerResult result,
  required Set<String> seenP,
}) {
  // NIP-30 custom emoji tags (deduped by shortcode)
  final seenEmoji = <String>{};
  for (final emoji in result.emojiTags) {
    if (seenEmoji.add(emoji.shortcode)) {
      partial.event.addTag('emoji', [emoji.shortcode, emoji.url]);
    }
  }

  // Additional mention p tags (deduped against root/parent pubkeys)
  for (final pk in result.mentions) {
    final normalized = pk.toLowerCase();
    if (_isHexPubkey(normalized) && seenP.add(normalized)) {
      partial.event.addTagValue('p', normalized);
    }
  }

  // Media attachment tags
  for (final url in result.mediaUrls) {
    final trimmed = url.trim();
    if (trimmed.isNotEmpty) {
      partial.event.addTagValue('media', trimmed);
    }
  }
}

bool _isHexPubkey(String s) =>
    s.length == 64 && RegExp(r'^[a-f0-9]+$').hasMatch(s);
