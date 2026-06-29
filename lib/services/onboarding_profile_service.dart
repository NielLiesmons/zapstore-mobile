import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:models/models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:zapstore/main.dart';
import 'package:zapstore/services/local_signer_service.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/key_generator.dart';

const _blossomAuthTtlSec = 5 * 60;

/// Saves [nsec], signs in, and publishes a minimal profile to [kOnboardingProfileRelays].
///
/// Relay publish is best-effort — local sign-in always completes so the
/// complete-profile modal can open even when the relay is unreachable.
Future<void> publishIntermediateOnboardingProfile({
  required WidgetRef ref,
  required String displayName,
  required String nsec,
  required ProfilePowMiner miner,
}) async {
  await ref.read(localSignerServiceProvider).saveNsec(nsec);
  final hex = KeyGenerator.nsecToHex(nsec);
  final signer = Bip340PrivateKeySigner(hex, ref.asRef);
  await signer.signIn();

  final signed = await _signOnboardingProfile(
    displayName: displayName.trim(),
    signer: signer,
  );
  await ref.storage.save({signed});
  await _publishOnboardingProfileBestEffort(ref, signed);
  await onSignInSuccess(ref.asRef);
}

/// Publishes the final profile (name, about, picture) to [kOnboardingProfileRelays].
///
/// Saves locally first; relay publish is best-effort.
Future<void> publishFinalOnboardingProfile({
  required WidgetRef ref,
  required String displayName,
  String? about,
  String? pictureUrl,
  required ProfilePowMiner miner,
}) async {
  final signer = ref.read(Signer.activeSignerProvider);
  if (signer == null) throw Exception('Sign in to save your profile');

  final partial = PartialProfile(
    name: displayName.trim(),
    about: about?.trim().isEmpty == true ? null : about?.trim(),
    pictureUrl: pictureUrl,
  );

  final signed = await partial.signWith(signer);
  await ref.storage.save({signed});
  await _publishOnboardingProfileBestEffort(ref, signed);
}

Future<Profile> _signOnboardingProfile({
  required String displayName,
  required Signer signer,
}) async {
  final partial = PartialProfile(name: displayName);
  return partial.signWith(signer);
}

Future<void> _publishOnboardingProfileBestEffort(
  WidgetRef ref,
  Profile signed,
) async {
  try {
    await ref.storage.publish({signed}, relays: kOnboardingProfileRelays);
  } catch (e, stack) {
    debugPrint(
      '[onboarding] profile publish to $kOnboardingProfileRelays failed '
      '(non-fatal): $e\n$stack',
    );
  }
}

/// Writes [nsec] to a temp file and opens the system share sheet.
Future<void> shareNsecBackup(String nsec) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/zapstore-secret-key.txt');
  await file.writeAsString(
    '$nsec\n',
    flush: true,
  );
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/plain', name: 'zapstore-secret-key.txt')],
    subject: 'Zapstore secret key backup',
  );
}

/// Uploads a profile picture to Primal Blossom during onboarding.
Future<String> uploadOnboardingProfileImage({
  required WidgetRef ref,
  required Uint8List bytes,
  required String mimeType,
}) {
  return _uploadToBlossom(
    ref: ref,
    bytes: bytes,
    mimeType: mimeType,
    baseUrl: kPrimalBlossomUrl,
  );
}

/// Uploads an image to Zapstore Blossom (kind 24242 auth). Returns the public URL.
Future<String> uploadImageToZapstoreBlossom({
  required WidgetRef ref,
  required Uint8List bytes,
  required String mimeType,
}) {
  return _uploadToBlossom(
    ref: ref,
    bytes: bytes,
    mimeType: mimeType,
    baseUrl: 'https://cdn.zapstore.dev',
  );
}

Future<String> _uploadToBlossom({
  required WidgetRef ref,
  required Uint8List bytes,
  required String mimeType,
  required String baseUrl,
}) async {
  final signer = ref.read(Signer.activeSignerProvider);
  if (signer == null) throw Exception('Sign in to upload');

  final digestHex = sha256.convert(bytes).toString();
  final expiration =
      DateTime.now().toUtc().add(const Duration(seconds: _blossomAuthTtlSec));

  final authPartial = PartialBlossomAuthorization()
    ..type = BlossomAuthorizationType.upload
    ..hash = digestHex
    ..expiration = expiration
    ..content = 'Upload $digestHex';

  final signedAuth = await authPartial.signWith(signer);
  final authHeader =
      'Nostr ${base64Encode(utf8.encode(jsonEncode(signedAuth.toMap())))}';

  final normalizedBase = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final blobUrl = '$normalizedBase/$digestHex';

  final head = await http.head(Uri.parse(blobUrl));
  if (head.statusCode == 200) return blobUrl;

  final response = await http.put(
    Uri.parse('$normalizedBase/upload'),
    headers: {
      'Authorization': authHeader,
      'Content-Type': mimeType,
      'X-SHA-256': digestHex,
      'Content-Digest': digestHex,
      'Content-Length': '${bytes.length}',
    },
    body: bytes,
  );

  if (!response.statusCode.toString().startsWith('2')) {
    final reason = response.headers['x-reason'] ?? response.body;
    throw Exception(
      reason.isNotEmpty ? reason : 'Upload failed (${response.statusCode})',
    );
  }

  try {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final url = json['url'];
    if (url is String && url.isNotEmpty) return url;
  } catch (_) {}

  return blobUrl;
}
