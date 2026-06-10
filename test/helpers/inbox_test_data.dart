import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/models/forum_post.dart';

import 'storage_test_container.dart';

/// Inbox owner — matches models test fixtures.
const kInboxTestOwnerPk =
    'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';

const kInboxTestAuthorPk =
    '726a1e261cc6474674e8285e3951b3bb139be9a773d1acf49dc868db861a1c11';

const kInboxTestReplyAuthorPk =
    '7fa56f5d6962ab1e3cd424e758c3002b8665f7b0d8dcee9fe9e288d7751ac194';

const _longBody =
    'This is a longer mention body with enough lines to stress layout. '
    'It includes nostr mentions, markdown **bold**, and multiple sentences '
    'so the bubble column clearly exceeds the avatar rail height.';

/// Seeds profiles, an app root, and varied kind-1111 mentions for inbox tests.
Future<List<Comment>> seedInboxTestComments(ProviderContainer container) async {
  ForumPost.register();

  for (final (pk, name) in [
    (kInboxTestAuthorPk, 'Alice'),
    (kInboxTestReplyAuthorPk, 'Bob'),
    (kInboxTestOwnerPk, 'Inbox Owner'),
  ]) {
    final profile = PartialProfile(name: name).dummySign(pk);
    await container.testStorage.save({profile});
  }

  final app = PartialApp()
    ..identifier = 'inbox-layout-test'
    ..name = 'Layout Test App'
    ..summary = 'Inbox overflow regression';
  final signedApp = app.dummySign(kInboxTestAuthorPk);
  await container.testStorage.save({signedApp});

  final comments = <Comment>[];

  Comment mention({
    required String content,
    required String authorPk,
    Model? parentModel,
    DateTime? createdAt,
  }) {
    final partial = PartialComment(
      content: content,
      rootModel: signedApp,
      parentModel: parentModel ?? signedApp,
      createdAt: createdAt,
    );
    partial.event.addTagValue('p', kInboxTestOwnerPk);
    return partial.dummySign(authorPk);
  }

  comments.add(mention(content: _longBody, authorPk: kInboxTestAuthorPk));

  final parent = mention(
    content: 'Parent comment on the app thread',
    authorPk: kInboxTestAuthorPk,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
  );
  await container.testStorage.save({parent});
  comments.add(parent);

  comments.add(
    mention(
      content: 'Nested reply with quote context above the body text.',
      authorPk: kInboxTestReplyAuthorPk,
      parentModel: parent,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1_700_000_100_000),
    ),
  );

  for (var i = 0; i < 9; i++) {
    comments.add(
      mention(
        content: 'Bulk mention #$i — $_longBody',
        authorPk: i.isEven ? kInboxTestAuthorPk : kInboxTestReplyAuthorPk,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1_700_000_200_000 + i),
      ),
    );
  }

  await container.testStorage.save(comments.toSet());
  return comments;
}

Future<void> signInInboxTestOwner(ProviderContainer container) async {
  final signer = DummySigner(container.testRef, pubkey: kInboxTestOwnerPk);
  await signer.initialize();
  await signer.signIn();
}
