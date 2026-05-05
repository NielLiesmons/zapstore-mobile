import 'package:models/models.dart';

/// Nostr kind-11 forum post.
///
/// Matches the webapp's `EVENT_KINDS.FORUM_POST = 11` and the schema defined
/// in zaplab_design's `ForumPost extends RegularModel<ForumPost>`.
///
/// Event structure:
/// ```json
/// {
///   "kind": 11,
///   "content": "post body",
///   "tags": [
///     ["title", "Post Title"],
///     ["t", "label"],
///     ...
///   ]
/// }
/// ```
///
/// Registration:
///   Call [ForumPost.register] once during app initialization (after the
///   storage init) so `query<ForumPost>()` and `RequestFilter<ForumPost>`
///   resolve to kind 11.
class ForumPost extends RegularModel<ForumPost> {
  ForumPost.fromMap(super.map, super.ref) : super.fromMap();

  /// Registers `ForumPost` ↔ kind 11 with the models registry.
  /// Call this once, after `StorageNotifier.initialize()`.
  static void register() {
    Model.register<ForumPost>(
      kind: 11,
      constructor: ForumPost.fromMap,
    );
  }

  /// Post title (from the `title` tag). Null if no title tag present.
  String? get title => event.getFirstTagValue('title');

  /// Full text content of the post.
  String get content => event.content;

  /// Creation timestamp.
  @override
  DateTime get createdAt => event.createdAt;

  /// Author pubkey.
  @override
  String get pubkey => event.pubkey;

  /// Topic/label tags (all `t` tag values).
  Set<String> get topics => event.getTagSetValues('t');
}
