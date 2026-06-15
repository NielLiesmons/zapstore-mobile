import 'package:models/models.dart';

/// Matches [RequestFilter] replaceable coordinate validation.
final RegExp kReplaceableQueryCoord = RegExp(r'^\d+:[0-9a-f]{64}:');

/// Normalizes tag values for [queryKinds] / [query] `ids` filters.
///
/// [RequestFilter] throws `Bad ids input` for values that are not hex event ids
/// or replaceable coordinates (e.g. bare bech32, relay hints). Returns `null`
/// when the value cannot be queried safely.
String? normalizeNostrQueryId(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  var id = trimmed;
  if (id.startsWith('nostr:') ||
      id.startsWith('note') ||
      id.startsWith('nevent') ||
      id.startsWith('naddr')) {
    try {
      id = Utils.decodeShareableToString(id);
    } catch (_) {
      return null;
    }
  }

  if (id.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(id)) {
    return id.toLowerCase();
  }
  if (kReplaceableQueryCoord.hasMatch(id)) return id;
  return null;
}

/// Normalizes hex / npub author pubkeys for [query] `authors` filters.
String? normalizeAuthorPubkey(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  try {
    final hex = Utils.decodeShareableToString(trimmed);
    if (hex.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
      return hex.toLowerCase();
    }
  } catch (_) {
    // Fall through — may already be raw hex.
  }

  if (trimmed.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(trimmed)) {
    return trimmed.toLowerCase();
  }
  return null;
}
