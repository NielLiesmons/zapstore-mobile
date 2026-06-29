import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';

import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/models/forum_post.dart';
import 'package:zapstore/widgets/composer/nostr_text_controller.dart';

/// Builds and publishes a Zapstore community kind-11 forum post.
///
/// Mirrors webapp's `handleForumPostSubmit` in CommunityForumShell.svelte.
Future<void> publishForumPost({
  required WidgetRef ref,
  required String title,
  required ComposerResult content,
  required List<String> labels,
}) async {
  final trimmedTitle = title.trim();
  if (trimmedTitle.isEmpty) return;

  final signer = ref.read(Signer.activeSignerProvider);
  if (signer == null) throw Exception('Sign in to post');

  final partial = PartialForumPost(
    title: trimmedTitle,
    content: content.text,
    labels: labels,
    emojiTags: content.emojiTags,
    mediaUrls: content.mediaUrls,
    mentions: content.mentions,
  );

  final signed = await partial.signWith(signer);
  final storage = ref.read(storageNotifierProvider.notifier);
  await storage.save({signed});
  storage.publish({signed}, relays: {'AppCatalog', 'social'});
}

/// Unsigned kind-11 event builder for [ForumPost].
class PartialForumPost extends RegularPartialModel<ForumPost> {
  PartialForumPost({
    required String title,
    required String content,
    List<String> labels = const [],
    List<({String shortcode, String url})> emojiTags = const [],
    List<String> mediaUrls = const [],
    List<String> mentions = const [],
  }) {
    event.addTagValue('h', kZapstoreCommunityPubkey);
    event.addTagValue('title', title);
    event.content = content;

    for (final label in labels) {
      final trimmed = label.trim();
      if (trimmed.isNotEmpty) {
        event.addTagValue('t', trimmed);
      }
    }

    final seenEmoji = <String>{};
    for (final emoji in emojiTags) {
      if (seenEmoji.add(emoji.shortcode)) {
        event.addTag('emoji', [emoji.shortcode, emoji.url]);
      }
    }

    final seenP = <String>{};
    for (final pk in mentions) {
      final normalized = pk.toLowerCase();
      if (_isHexPubkey(normalized) && seenP.add(normalized)) {
        event.addTagValue('p', normalized);
      }
    }

    for (final url in mediaUrls) {
      final trimmed = url.trim();
      if (trimmed.isNotEmpty) {
        event.addTagValue('media', trimmed);
      }
    }
  }
}

bool _isHexPubkey(String s) =>
    s.length == 64 && RegExp(r'^[a-f0-9]+$').hasMatch(s);
