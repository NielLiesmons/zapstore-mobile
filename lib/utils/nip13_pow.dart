import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Minimum leading-zero bits required before publish is allowed.
const int kOnboardingProfilePowTargetBits = 16;

/// NIP-13: leading zero bits in the 32-byte event id (hex).
int countLeadingZeroBits(String eventIdHex) {
  final bytes = _hexToBytes(eventIdHex);
  var total = 0;
  for (final byte in bytes) {
    final bits = _zeroBitsInByte(byte);
    total += bits;
    if (bits != 8) break;
  }
  return total;
}

int _zeroBitsInByte(int v) {
  if (v == 0) return 8;
  var n = 0;
  for (var i = 7; i >= 0; i--) {
    if ((v & (1 << i)) == 0) {
      n++;
    } else {
      break;
    }
  }
  return n;
}

/// NIP-01 event id (same serialization as [Utils.getEventId] in models).
String computeEventId({
  required String pubkey,
  required int createdAtSeconds,
  required int kind,
  required List<List<String>> tags,
  required String content,
}) {
  final data = [
    0,
    pubkey.toLowerCase(),
    createdAtSeconds,
    kind,
    tags,
    content,
  ];
  final digest = sha256.convert(
    Uint8List.fromList(utf8.encode(json.encode(data))),
  );
  return digest.toString();
}

Uint8List _hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// Serializable mining job for an isolate.
class ProfilePowJob {
  const ProfilePowJob({
    required this.pubkey,
    required this.content,
    required this.createdAtSeconds,
    required this.targetBits,
    required this.reportEveryAttempts,
  });

  final String pubkey;
  final String content;
  final int createdAtSeconds;
  final int targetBits;
  final int reportEveryAttempts;
}

/// Periodic update while mining continues (even after minimum is met).
class ProfilePowProgress {
  const ProfilePowProgress({
    required this.attempts,
    required this.bestBits,
    required this.elapsedMs,
    required this.meetsMinimum,
    this.bestNonce,
  });

  final int attempts;
  final int bestBits;
  final int elapsedMs;
  final bool meetsMinimum;

  /// Nonce for [bestBits], when a candidate exists.
  final int? bestNonce;
}

/// Best mined candidate to attach at publish time.
class ProfilePowResult {
  const ProfilePowResult({
    required this.nonce,
    required this.bits,
    required this.attempts,
    required this.createdAtSeconds,
  });

  final int nonce;
  final int bits;
  final int attempts;
  final int createdAtSeconds;
}

/// Runs until the isolate is killed — does not stop at [ProfilePowJob.targetBits].
void profilePowIsolateEntry((SendPort sendPort, ProfilePowJob job) message) {
  final sendPort = message.$1;
  final job = message.$2;
  final started = DateTime.now().millisecondsSinceEpoch;

  var nonce = 0;
  var attempts = 0;
  var bestBits = 0;
  int? bestNonce;

  while (true) {
    final tags = <List<String>>[
      ['nonce', '$nonce', '${job.targetBits}'],
    ];
    final id = computeEventId(
      pubkey: job.pubkey,
      createdAtSeconds: job.createdAtSeconds,
      kind: 0,
      tags: tags,
      content: job.content,
    );
    final bits = countLeadingZeroBits(id);
    if (bits > bestBits) {
      bestBits = bits;
      bestNonce = nonce;
    }
    attempts++;
    nonce++;

    if (attempts % job.reportEveryAttempts == 0) {
      sendPort.send(
        ProfilePowProgress(
          attempts: attempts,
          bestBits: bestBits,
          bestNonce: bestNonce,
          meetsMinimum: bestBits >= job.targetBits,
          elapsedMs: DateTime.now().millisecondsSinceEpoch - started,
        ),
      );
    }
  }
}
