import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:purplebase/purplebase.dart';

/// Exposes [Ref] for model construction in widget tests.
final testRefProvider = Provider<Ref>((ref) => ref);

/// Isolated in-memory [DummyStorageNotifier] for widget / integration tests.
Future<ProviderContainer> createStorageTestContainer({
  StorageConfiguration? config,
  List<Override>? overrides,
}) async {
  final container = ProviderContainer(overrides: [
    storageNotifierProvider.overrideWith((ref) => DummyStorageNotifier(ref)),
    ...?overrides,
  ]);

  final storageConfig = StorageConfiguration(
    databasePath: config?.databasePath,
    keepSignatures: config?.keepSignatures ?? false,
    skipVerification: config?.skipVerification ?? false,
    defaultRelays: config?.defaultRelays ?? {'default': {'wss://test.relay'}},
    defaultQuerySource:
        config?.defaultQuerySource ?? const LocalAndRemoteSource(stream: false),
    idleTimeout: config?.idleTimeout ?? const Duration(minutes: 5),
    responseTimeout: config?.responseTimeout ?? Duration.zero,
    streamingBufferDuration: config?.streamingBufferDuration ?? Duration.zero,
    keepMaxModels: config?.keepMaxModels ?? 1000,
    requestBufferDuration: config?.requestBufferDuration ?? Duration.zero,
  );

  await container.read(initializationProvider(storageConfig).future);
  return container;
}

extension StorageTestContainerExt on ProviderContainer {
  DummyStorageNotifier get testStorage =>
      read(storageNotifierProvider.notifier) as DummyStorageNotifier;

  Ref get testRef => read(testRefProvider);
}
