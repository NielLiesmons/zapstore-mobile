import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zapstore/services/inbox_seen_service.dart';

/// Per-pubkey inbox read ids — mirrors webapp `user-inbox-seen.svelte.js`.
final inboxSeenProvider = StateNotifierProvider.autoDispose
    .family<InboxSeenNotifier, Set<String>, String>((ref, pubkey) {
  return InboxSeenNotifier(pubkey);
});

class InboxSeenNotifier extends StateNotifier<Set<String>> {
  InboxSeenNotifier(this.pubkey) : super({}) {
    _load();
  }

  final String pubkey;

  Future<void> _load() async {
    state = await InboxSeenStorage.readIds(pubkey);
  }

  bool isUnread(String eventId) =>
      eventId.isNotEmpty && !state.contains(eventId);

  Future<void> markSeen(Iterable<String> ids) async {
    await InboxSeenStorage.markEventsSeen(pubkey, ids);
    state = await InboxSeenStorage.readIds(pubkey);
  }
}
