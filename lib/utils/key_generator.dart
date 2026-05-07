import 'dart:math';
import 'package:bech32/bech32.dart';

/// Minimal nsec key generator for the onboarding flow.
///
/// Generates a 32-byte random private key and bech32-encodes it as `nsec1…`.
/// Splits the result into 12 display chunks matching the webapp's SpinKeyModal
/// layout (9 chunks of 5 chars + 3 chunks of 6 chars).
class KeyGenerator {
  static final _codec = const Bech32Codec();

  /// Generate a fresh random key. Returns the full [nsec] string and
  /// pre-split [parts] ready for the slot machine display.
  static ({String nsec, List<String> parts}) generate() {
    final random = Random.secure();
    final privKey = List<int>.generate(32, (_) => random.nextInt(256));

    // Ensure key is a valid secp256k1 scalar (first byte < 0x80)
    if (privKey[0] >= 0x80) privKey[0] &= 0x7F;

    final data = _convertBits(privKey, 8, 5, true);
    final nsec = _codec.encode(Bech32('nsec', data));
    return (nsec: nsec, parts: splitNsec(nsec));
  }

  /// Split an nsec string into 12 display chunks (uppercase).
  /// Matches webapp splitNsecIntoParts logic:
  ///   slots 0–8 → 5 chars each, slots 9–11 → 6 chars each.
  static List<String> splitNsec(String nsec) {
    final parts = <String>[];
    int pos = 0;
    for (int i = 0; i < 12; i++) {
      final size = i < 9 ? 5 : 6;
      parts.add(nsec.substring(pos, pos + size).toUpperCase());
      pos += size;
    }
    return parts;
  }

  /// Decode a bech32 [nsec] string to a 64-char lowercase hex private key.
  /// Used to construct a [Bip340PrivateKeySigner] from a locally generated nsec.
  static String nsecToHex(String nsec) {
    const codec = Bech32Codec();
    final decoded = codec.decode(nsec, 200);
    final privBytes = _convertBits(decoded.data, 5, 8, false);
    return privBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static List<int> _convertBits(List<int> data, int from, int to, bool pad) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxv = (1 << to) - 1;
    for (final value in data) {
      acc = (acc << from) | value;
      bits += from;
      while (bits >= to) {
        bits -= to;
        result.add((acc >> bits) & maxv);
      }
    }
    if (pad && bits > 0) {
      result.add((acc << (to - bits)) & maxv);
    }
    return result;
  }
}
