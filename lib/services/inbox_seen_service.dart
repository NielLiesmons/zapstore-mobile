import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local inbox read state — same storage key scheme as the webapp
/// (`zapstore-inbox-seen:v1:{pubkey}`).
class InboxSeenStorage {
  InboxSeenStorage._();

  static const _storagePrefix = 'zapstore-inbox-seen:v1:';
  static const _maxIds = 3000;

  static Future<Set<String>> readIds(String pubkey) async {
    if (pubkey.isEmpty) return {};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_storagePrefix$pubkey');
    if (raw == null) return {};
    try {
      final arr = jsonDecode(raw);
      if (arr is! List) return {};
      return arr.whereType<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> markEventsSeen(
    String pubkey,
    Iterable<String> ids,
  ) async {
    if (pubkey.isEmpty) return;
    final incoming = ids.where((id) => id.isNotEmpty);
    if (incoming.isEmpty) return;

    final current = await readIds(pubkey);
    final updated = {...current, ...incoming};
    if (updated.length == current.length) return;

    var arr = updated.toList();
    if (arr.length > _maxIds) {
      arr = arr.sublist(arr.length - _maxIds);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_storagePrefix$pubkey', jsonEncode(arr));
  }
}
