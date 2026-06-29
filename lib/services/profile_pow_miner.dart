import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:zapstore/utils/key_generator.dart';
import 'package:zapstore/utils/nip13_pow.dart';

/// Live snapshot for background profile PoW mining.
@immutable
class ProfilePowSnapshot {
  const ProfilePowSnapshot({
    this.isRunning = false,
    this.attempts = 0,
    this.bestBits = 0,
    this.targetBits = kOnboardingProfilePowTargetBits,
    this.elapsed = Duration.zero,
    this.meetsMinimum = false,
    this.best,
  });

  final bool isRunning;
  final int attempts;
  final int bestBits;
  final int targetBits;
  final Duration elapsed;

  /// True once [bestBits] >= [targetBits] (relay minimum satisfied).
  final bool meetsMinimum;

  /// Strongest candidate found so far — used when publishing.
  final ProfilePowResult? best;

  /// Progress toward the minimum (caps at 1.0 once met; mining may continue).
  double get progressTowardMinimum =>
      targetBits <= 0 ? 0 : (bestBits / targetBits).clamp(0.0, 1.0);

  ProfilePowSnapshot copyWith({
    bool? isRunning,
    int? attempts,
    int? bestBits,
    int? targetBits,
    Duration? elapsed,
    bool? meetsMinimum,
    ProfilePowResult? best,
    bool clearBest = false,
  }) {
    return ProfilePowSnapshot(
      isRunning: isRunning ?? this.isRunning,
      attempts: attempts ?? this.attempts,
      bestBits: bestBits ?? this.bestBits,
      targetBits: targetBits ?? this.targetBits,
      elapsed: elapsed ?? this.elapsed,
      meetsMinimum: meetsMinimum ?? this.meetsMinimum,
      best: clearBest ? null : (best ?? this.best),
    );
  }
}

/// Background NIP-13 miner for a minimal kind-0 profile (name only).
///
/// Keeps hashing until [stop] — does not halt when the minimum bit target is hit.
class ProfilePowMiner {
  ProfilePowMiner({this.targetBits = kOnboardingProfilePowTargetBits});

  final int targetBits;
  final ValueNotifier<ProfilePowSnapshot> snapshot =
      ValueNotifier(const ProfilePowSnapshot());

  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamSubscription<Object?>? _subscription;
  DateTime? _startedAt;
  int? _createdAtSeconds;
  DateTime? _lastUiEmit;
  ProfilePowProgress? _pendingProgress;

  void start({required String displayName, required String nsec}) {
    stop();
    final privkey = KeyGenerator.nsecToHex(nsec);
    final pubkey = Utils.derivePublicKey(privkey);
    final content = jsonEncode({'name': displayName.trim()});
    _createdAtSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    _startedAt = DateTime.now();
    _lastUiEmit = null;
    _pendingProgress = null;
    snapshot.value = ProfilePowSnapshot(
      isRunning: true,
      targetBits: targetBits,
    );

    _receivePort = ReceivePort();
    _subscription = _receivePort!.listen(_onMessage);

    Isolate.spawn(
      profilePowIsolateEntry,
      (_receivePort!.sendPort, ProfilePowJob(
        pubkey: pubkey,
        content: content,
        createdAtSeconds: _createdAtSeconds!,
        targetBits: targetBits,
        reportEveryAttempts: 2000,
      )),
    ).then((isolate) {
      _isolate = isolate;
    }).catchError((Object error, StackTrace stack) {
      snapshot.value = snapshot.value.copyWith(isRunning: false);
      debugPrint('ProfilePowMiner: isolate failed: $error\n$stack');
    });
  }

  void _onMessage(Object? message) {
    if (message is! ProfilePowProgress) return;
    _pendingProgress = message;

    final now = DateTime.now();
    final last = _lastUiEmit;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 120) &&
        !message.meetsMinimum) {
      return;
    }
    _flushPendingProgress(now);
  }

  void _flushPendingProgress(DateTime now) {
    final started = _startedAt;
    final createdAt = _createdAtSeconds;
    final message = _pendingProgress;
    if (started == null || createdAt == null || message == null) return;

    _lastUiEmit = now;

    ProfilePowResult? best = snapshot.value.best;
    if (message.bestNonce != null && message.bestBits > 0) {
      final candidate = ProfilePowResult(
        nonce: message.bestNonce!,
        bits: message.bestBits,
        attempts: message.attempts,
        createdAtSeconds: createdAt,
      );
      if (best == null || candidate.bits > best.bits) {
        best = candidate;
      }
    }

    snapshot.value = snapshot.value.copyWith(
      attempts: message.attempts,
      bestBits: message.bestBits,
      meetsMinimum: message.meetsMinimum,
      elapsed: now.difference(started),
      best: best,
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _receivePort?.close();
    _receivePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    if (snapshot.value.isRunning) {
      _flushPendingProgress(DateTime.now());
      snapshot.value = snapshot.value.copyWith(isRunning: false);
    }
  }

  void dispose() {
    stop();
    snapshot.dispose();
  }
}
