import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

/// Persists a locally generated nsec (bech32-encoded private key) to secure
/// storage so the user stays signed in across app restarts without needing an
/// external signer app like Amber.
class LocalSignerService {
  static const _nsecKey = 'local_nsec';

  Future<void> saveNsec(String nsec) =>
      _storage.write(key: _nsecKey, value: nsec);

  Future<String?> loadNsec() => _storage.read(key: _nsecKey);

  Future<void> clearNsec() => _storage.delete(key: _nsecKey);
}

final localSignerServiceProvider =
    Provider<LocalSignerService>((ref) => LocalSignerService());
