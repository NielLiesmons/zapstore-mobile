import 'dart:async';
import 'dart:convert';

import 'package:amber_signer/amber_signer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:purplebase/purplebase.dart';

import '../utils/key_generator.dart';
import 'local_signer_service.dart';
import 'settings_service.dart';

/// Fast secure-storage probe — no SQLite, no sign-in.
Future<bool> probeStoredCredentials(Ref ref) async {
  try {
    final amberPubkey = await SecureStoragePubkeyPersistence().loadPubkey();
    if (amberPubkey != null && amberPubkey.isNotEmpty) return true;

    final nsec = await ref.read(localSignerServiceProvider).loadNsec();
    return nsec != null && nsec.isNotEmpty;
  } catch (e) {
    debugPrint('probeStoredCredentials failed: $e');
    return false;
  }
}

/// Signs out and wipes a locally stored onboarding nsec.
///
/// Use when auto-restore fails or a corrupt local profile bricks startup.
Future<void> clearLocalOnboardingSession(
  Ref ref, {
  AmberSigner? amberSigner,
}) async {
  try {
    await ref.read(localSignerServiceProvider).clearNsec();
  } catch (e) {
    debugPrint('clearLocalOnboardingSession: clearNsec failed: $e');
  }

  try {
    final signer = ref.read(Signer.activeSignerProvider);
    if (signer != null) {
      await signer.signOut();
    }
  } catch (e) {
    debugPrint('clearLocalOnboardingSession: signer signOut failed: $e');
  }

  if (amberSigner != null) {
    try {
      await amberSigner.signOut();
    } catch (e) {
      debugPrint('clearLocalOnboardingSession: amber signOut failed: $e');
    }
  }
}

/// Deletes local kind-0 rows without hydrating [Profile] models.
Future<void> _purgeLocalKind0Profiles(
  PurplebaseStorageNotifier storage,
  String pubkey,
) async {
  final db = storage.db;
  if (db == null) return;

  final rows = db.select(
    'SELECT id FROM events WHERE kind = 0 AND pubkey = ?',
    [pubkey],
  );
  final ids = rows.map((row) => row['id'] as String).toSet();
  if (ids.isEmpty) return;

  debugPrint('Purging ${ids.length} local kind-0 event(s) for $pubkey');
  await storage.delete(ids);
}

/// Validates kind-0 JSON via SQL — never hydrates [Profile] models.
Future<void> _purgeCorruptKind0ViaSql(
  PurplebaseStorageNotifier storage,
  String pubkey,
) async {
  final db = storage.db;
  if (db == null) return;

  final rows = db.select(
    'SELECT id, content FROM events WHERE kind = 0 AND pubkey = ?',
    [pubkey],
  );
  final corruptIds = <String>{};
  for (final row in rows) {
    final id = row['id'] as String?;
    if (id == null) continue;
    try {
      final content = row['content'];
      if (content is! String || content.trim().isEmpty) {
        corruptIds.add(id);
        continue;
      }
      final decoded = jsonDecode(content);
      if (decoded is! Map) corruptIds.add(id);
    } catch (_) {
      corruptIds.add(id);
    }
  }
  if (corruptIds.isEmpty) return;
  debugPrint(
    'Purging ${corruptIds.length} corrupt kind-0 row(s) for $pubkey',
  );
  await storage.delete(corruptIds);
}

/// Pre-restore cleanup — purges corrupt local kind-0 metadata before hydrate.
Future<void> prepareSessionRestore(Ref ref, AmberSigner amberSigner) async {
  try {
    final nsec = await ref.read(localSignerServiceProvider).loadNsec();
    if (nsec == null || nsec.isEmpty) return;

    final hex = KeyGenerator.nsecToHex(nsec);
    final signer = Bip340PrivateKeySigner(hex, ref);
    final storage =
        ref.read(storageNotifierProvider.notifier) as PurplebaseStorageNotifier;
    await _purgeCorruptKind0ViaSql(storage, signer.pubkey);
  } catch (e, stack) {
    debugPrint(
      'prepareSessionRestore: corrupt onboarding state, wiping session: '
      '$e\n$stack',
    );
    await clearLocalOnboardingSession(ref, amberSigner: amberSigner);
  }
}

/// Validates readable local kind-0 metadata; purges rows that crash hydration.
Future<void> repairLocalProfilesForPubkey(Ref ref, String pubkey) async {
  final storage =
      ref.read(storageNotifierProvider.notifier) as PurplebaseStorageNotifier;

  await _purgeCorruptKind0ViaSql(storage, pubkey);

  try {
    final profiles = await storage.query(
      RequestFilter<Profile>(authors: {pubkey}).toRequest(),
      source: const LocalSource(),
    );

    final corruptIds = <String>{};
    for (final profile in profiles) {
      try {
        profile.name;
        profile.pictureUrl;
        profile.about;
      } catch (e) {
        debugPrint('Corrupt local profile ${profile.id}: $e');
        corruptIds.add(profile.id);
      }
    }

    if (corruptIds.isNotEmpty) {
      await storage.delete(corruptIds);
    }
  } catch (e, stack) {
    debugPrint(
      'Local profile query failed for $pubkey — purging kind-0: $e\n$stack',
    );
    await _purgeLocalKind0Profiles(storage, pubkey);
  }
}

/// Restore Amber or locally stored onboarding key. Returns true when signed in.
Future<bool> restoreSession(Ref ref, AmberSigner amberSigner) async {
  Signer? restoredSigner;

  try {
    final amberOk = await amberSigner.attemptAutoSignIn();
    if (amberOk) {
      restoredSigner = ref.read(Signer.activeSignerProvider);
      // Keep signed-in chrome hidden until profile repair completes.
      restoredSigner?.removeAsActivePubkey();
    }
  } catch (e, stack) {
    debugPrint('Amber auto sign-in failed: $e\n$stack');
    await clearLocalOnboardingSession(ref, amberSigner: amberSigner);
    return false;
  }

  if (restoredSigner == null) {
    try {
      final nsec = await ref.read(localSignerServiceProvider).loadNsec();
      if (nsec != null && nsec.isNotEmpty) {
        final hex = KeyGenerator.nsecToHex(nsec);
        final signer = Bip340PrivateKeySigner(hex, ref);
        // Keep the home header unsigned-in until profile repair finishes.
        await signer.signIn(setAsActive: false);
        restoredSigner = signer;
      }
    } catch (e, stack) {
      debugPrint('Local key auto sign-in failed: $e\n$stack');
      await clearLocalOnboardingSession(ref, amberSigner: amberSigner);
      return false;
    }
  }

  if (restoredSigner == null) return false;

  try {
    await repairLocalProfilesForPubkey(ref, restoredSigner.pubkey);
    restoredSigner.setAsActivePubkey();
    warmContactListCache(ref);
    return true;
  } catch (e, stack) {
    debugPrint('Session finalize failed: $e\n$stack');
    await clearLocalOnboardingSession(ref, amberSigner: amberSigner);
    return false;
  }
}

/// Best-effort contact-list warm-up — must not block startup (local-first).
void warmContactListCache(Ref ref) {
  final pubkey = ref.read(Signer.activePubkeyProvider);
  if (pubkey == null) return;

  final storage =
      ref.read(storageNotifierProvider.notifier) as PurplebaseStorageNotifier;

  unawaited(
    storage.query(
      RequestFilter<ContactList>(authors: {pubkey}).toRequest(),
      source: const RemoteSource(relays: 'social', stream: false),
      subscriptionPrefix: 'app-contact-list',
    ),
  );
}

/// Called after manual sign-in (Amber button, onboarding).
Future<void> onSignInSuccess(Ref ref) async {
  warmContactListCache(ref);
}

/// Local active profile — returns null instead of crashing on corrupt kind-0.
final safeActiveLocalProfileProvider = Provider.autoDispose<Profile?>((ref) {
  final pubkey = ref.watch(Signer.activePubkeyProvider);
  if (pubkey == null) return null;
  try {
    return ref.watch(Signer.activeProfileProvider(const LocalSource()));
  } catch (e, stack) {
    debugPrint('safeActiveLocalProfileProvider: discarding corrupt profile: '
        '$e\n$stack');
    unawaited(repairLocalProfilesForPubkey(ref, pubkey));
    return null;
  }
});
