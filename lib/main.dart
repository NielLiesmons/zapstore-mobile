import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode, SystemUiOverlayStyle, rootBundle;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:purplebase/purplebase.dart';
import 'package:amber_signer/amber_signer.dart';
import 'package:zapstore/services/app_restart_service.dart';
import 'package:zapstore/services/background_update_service.dart';
import 'package:zapstore/services/notification_service.dart';
import 'package:zapstore/services/settings_service.dart';
import 'package:zapstore/router.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/services/package_manager/android_package_manager.dart';
import 'package:zapstore/services/package_manager/dummy_package_manager.dart';
import 'package:zapstore/services/deep_link_service.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/text_scale.dart';
import 'package:zapstore/providers/theme_mode.dart';
import 'package:zapstore/services/auth_session_service.dart';
import 'package:zapstore/services/updates_service.dart';
import 'models/emoji_list.dart';
import 'models/forum_post.dart';
import 'package:zapstore/widgets/breathing_logo.dart';

export 'package:zapstore/services/auth_session_service.dart'
    show onSignInSuccess, clearLocalOnboardingSession;

/// Global provider container for error reporting (accessible outside widget tree)
late final ProviderContainer _providerContainer;

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // Register app-specific Nostr model types before any widget builds.
    // Model.register writes to a static map — no storage needed at this point.
    ForumPost.register();
    UserEmojiList.register();
    EmojiSet.register();
    Model.register(
      kind: 1111,
      constructor: Comment.fromMap,
      partialConstructor: PartialComment.fromMap,
    );

    // Edge-to-edge: let content draw behind system bars.
    // The barrier overlay and modal backdrop will now cover the full screen.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Create provider container with overrides
    _providerContainer = ProviderContainer(
      overrides: [
        storageNotifierProvider.overrideWith(PurplebaseStorageNotifier.new),
        packageManagerProvider.overrideWith(
          (ref) => Platform.isAndroid
              ? AndroidPackageManager(ref)
              : DummyPackageManager(ref),
        ),
      ],
    );

    FlutterError.onError = (details) {
      // Prevents debugger stopping multiple times
      FlutterError.dumpErrorToConsole(details);
      _errorHandler(details.exception, details.stack);
    };

    runApp(
      UncontrolledProviderScope(
        container: _providerContainer,
        child: const ZapstoreApp(),
      ),
    );
  }, _errorHandler);
}

/// Global error handler that reports errors via NIP-44 encrypted DMs
void _errorHandler(Object exception, StackTrace? stack) {
  // Report error asynchronously (fire and forget)
  // TODO: Disabled until careful review
  // unawaited(
  //   _providerContainer
  //       .read(errorReportingServiceProvider)
  //       .reportError(exception, stack),
  // );
}

class ZapstoreApp extends HookConsumerWidget {
  const ZapstoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier =
        ref.read(storageNotifierProvider.notifier) as PurplebaseStorageNotifier;
    final title = 'Zapstore';

    // Watch initialization state for error overlay display
    final initState = ref.watch(appInitializationProvider);

    // Kick off credential probe + session restore as early as possible.
    ref.watch(storedSessionHintProvider);
    ref.watch(authRestoreProvider);

    // Keep update polling alive app-wide — independent of profile sign-in.
    ref.watch(updatePollerProvider);
    ref.watch(updateCountProvider);

    // Listen to app lifecycle and check for updates when app regains focus
    useEffect(() {
      final observer = _AppLifecycleObserver(ref);
      WidgetsBinding.instance.addObserver(observer);
      return () => WidgetsBinding.instance.removeObserver(observer);
    }, []);

    // Listen to connectivity changes and trigger ensureConnected when going online
    useEffect(() {
      final connectivity = Connectivity();
      StreamSubscription<List<ConnectivityResult>>? subscription;

      // Check initial connectivity state
      connectivity.checkConnectivity().then((results) {
        notifier.connect();
      });

      // Listen to connectivity changes
      subscription = connectivity.onConnectivityChanged.listen((results) {
        notifier.connect();
      });

      return () => subscription?.cancel();
    }, []);

    // Automatically sign out when Amber is uninstalled while signed in.
    ref.listen<bool>(
      packageManagerProvider.select(
        (state) => state.installed.containsKey(kAmberPackageId),
      ),
      (previous, isAmberInstalled) {
        if (previous != true || isAmberInstalled) return;
        if (ref.read(Signer.activePubkeyProvider) == null) return;

        unawaited(() async {
          try {
            await ref.read(amberSignerProvider).signOut();

            final toastContext =
                rootNavigatorKey.currentState?.overlay?.context;
            if (toastContext != null && toastContext.mounted) {
              toastContext.showInfo('Amber was removed, you were signed out');
            }
          } catch (error) {
            debugPrint('Auto sign-out after Amber uninstall failed: $error');
          }
        }());
      },
    );

    final appThemeMode =
        ref.watch(themeModeProvider).valueOrNull ?? AppThemeMode.dark;
    final resolvedTheme = () {
      if (appThemeMode == AppThemeMode.system) {
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark ? darkTheme : lightTheme;
      }
      return switch (appThemeMode) {
        AppThemeMode.light  => lightTheme,
        AppThemeMode.dark   => darkTheme,
        AppThemeMode.black  => blackTheme,
        AppThemeMode.system => darkTheme,
      };
    }();

    // Always show the main app UI, even during initialization
    return MaterialApp.router(
      title: title,
      theme: resolvedTheme,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        // Device-level accessibility text scaling is intentionally ignored — the
        // app has its own text size and UI scale controls.
        final textScale = ref.watch(textScaleFactorProvider);
        final uiScale = ref.watch(uiScaleFactorProvider);

        // Wrap child with text scaler + optional UI zoom.
        // When uiScale != 1.0 we use Transform.scale + SizedBox + MediaQuery
        // size override — same mechanism as Android's Display Size setting,
        // but scoped to this app. GPU-only cost at steady state.
        Widget scaleChild(Widget inner) {
          final scaled = MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(textScale),
              size: uiScale != 1.0 ? mq.size / uiScale : mq.size,
              devicePixelRatio:
                  uiScale != 1.0 ? mq.devicePixelRatio * uiScale : mq.devicePixelRatio,
            ),
            child: inner,
          );
          if (uiScale == 1.0) return scaled;
          // OverflowBox breaks the parent's tight screen constraints and gives
          // the child the logical dimensions it should fill. Transform.scale
          // then maps that back onto the real screen — same as Android Display Size.
          return Transform.scale(
            scale: uiScale,
            alignment: Alignment.topLeft,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: mq.size.width / uiScale,
              maxWidth: mq.size.width / uiScale,
              minHeight: mq.size.height / uiScale,
              maxHeight: mq.size.height / uiScale,
              child: scaled,
            ),
          );
        }

        // Show error overlay if initialization failed (do not block UI during loading)
        if (initState is AsyncError) {
          return scaleChild(Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: child!,
              ),
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Initialization Error',
                              style: context.textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(initState.error.toString(),
                              textAlign: TextAlign.center,
                              style: context.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ));
        }

        return scaleChild(child!);
      },
    );
  }
}

class ZapstoreHome extends StatelessWidget {
  const ZapstoreHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BreathingLogo(size: 120),
            const SizedBox(height: 24),
            Text('Zapstore', style: context.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Permissionless app store for Nostr',
              style: context.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

const _kDefaultAppCatalogRelay = 'wss://relay.zapstore.dev';

/// Resolves as soon as local storage is open and queries can be made.
/// UI content gates on this — not on the full [appInitializationProvider].
/// Local seed DB + SQLite must be enough to render meaningful UI offline.
final storageReadyProvider = FutureProvider<void>((ref) async {
  final dir = await getApplicationSupportDirectory();
  final dbPath = path.join(dir.path, 'zapstore.db');

  // Clear storage if requested from a clear all operation
  await maybeClearStorage(dbPath);

  // Seed database on first launch so new users see content immediately
  await _maybeCopySeedDatabase(dbPath);

  // Load local relay config BEFORE storage init
  // This ensures custom relays work even when signed out
  final settings = await ref.read(settingsServiceProvider).load();
  final appCatalogRelays = settings.appCatalogRelays ?? {_kDefaultAppCatalogRelay};

  // Initialize storage with local relay config — after this, queries work
  await ref.read(
    initializationProvider(
      StorageConfiguration(
        databasePath: dbPath,
        defaultQuerySource: LocalAndRemoteSource(
          relays: 'AppCatalog',
          stream: false,
        ),
        defaultRelays: {
          'default': {_kDefaultAppCatalogRelay},
          'bootstrap': {_kDefaultAppCatalogRelay},
          'AppCatalog': appCatalogRelays,
          'social': {
            'wss://relay.damus.io',
            'wss://relay.primal.net',
            'wss://nos.lol',
          },
          'vertex': {'wss://relay.vertexlab.io'},
          'primal': {'wss://relay.primal.net'},
        },
        responseTimeout: Duration(seconds: 6),
      ),
    ).future,
  );
});

/// True when secure storage has an Amber pubkey or local onboarding nsec.
final storedSessionHintProvider = FutureProvider<bool>((ref) async {
  return probeStoredCredentials(ref);
});

/// Restores session right after SQLite is open — before package sync.
final authRestoreProvider = FutureProvider<bool>((ref) async {
  await ref.watch(storageReadyProvider.future);
  final amber = ref.read(amberSignerProvider);
  try {
    return await restoreSession(ref, amber);
  } catch (e, stack) {
    debugPrint('authRestoreProvider failed: $e\n$stack');
    await clearLocalOnboardingSession(ref, amberSigner: amber);
    return false;
  }
});

/// Resolves after all app services are ready (installed packages, deep links).
/// Session restore runs first via [authRestoreProvider].
final appInitializationProvider = FutureProvider<void>((ref) async {
  // Wait for storage to be open first
  await ref.watch(storageReadyProvider.future);

  // Restore signed-in profile before slow device / package work.
  await ref.watch(authRestoreProvider.future);

  // Initialize device capabilities (used for dynamic download concurrency)
  await DeviceCapabilitiesCache.initialize();

  // Record app open time for background notification throttling
  await ref.read(settingsServiceProvider).update(
        (s) => s.copyWith(lastAppOpened: DateTime.now()),
      );

  // Ensure installed packages are available before anything categorizes
  final packageManager = ref.read(packageManagerProvider.notifier);
  await packageManager.syncInstalledPackages();

  final backgroundService = ref.read(backgroundUpdateServiceProvider);
  unawaited(backgroundService.initialize());

  await ref.read(deepLinkServiceProvider).initialize();
});

// AmberSigner provider for Nostr authentication
// Uses SecureStoragePubkeyPersistence to survive database clears
final amberSignerProvider = Provider<AmberSigner>(
  (ref) => AmberSigner(ref, persistence: SecureStoragePubkeyPersistence()),
);

/// Copy the bundled seed database on first launch so the UI has content
/// before relay data arrives. No-op if the database already exists.
/// Skipped when the user has configured a non-default relay, since the
/// seed was built from [_kDefaultAppCatalogRelay] and would be wrong.
Future<void> _maybeCopySeedDatabase(String dbPath) async {
  final dbFile = File(dbPath);
  if (dbFile.existsSync()) return;

  final settings = await SettingsService().load();
  final isDefault = settings.appCatalogRelays == null ||
      (settings.appCatalogRelays!.length == 1 &&
          settings.appCatalogRelays!.contains(_kDefaultAppCatalogRelay));
  if (!isDefault) return;

  try {
    final seedData = await rootBundle.load('assets/seed.db');
    await dbFile.create(recursive: true);
    await dbFile.writeAsBytes(
      seedData.buffer.asUint8List(
        seedData.offsetInBytes,
        seedData.lengthInBytes,
      ),
      flush: true,
    );
  } catch (_) {
    // Non-fatal: the app works fine without the seed — just a cold start
  }
}

/// Observes app lifecycle events and manages package/storage state
class _AppLifecycleObserver with WidgetsBindingObserver {
  _AppLifecycleObserver(this._ref);

  final WidgetRef _ref;

  /// Handle permission grants that happened while app was backgrounded
  Future<void> _checkPermissionGrants() async {
    final packageManager = _ref.read(packageManagerProvider.notifier);
    if (packageManager is! AndroidPackageManager) return;

    final hasPermission = await packageManager.hasPermission();
    if (!hasPermission) return;

    // Advance any operations waiting for permission
    final state = _ref.read(packageManagerProvider);
    final awaitingPermission = state.operations.entries
        .where((e) => e.value is AwaitingPermission)
        .map((e) => e.key)
        .toList(growable: false);

    for (final appId in awaitingPermission) {
      await packageManager.onPermissionGranted(appId);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier =
        _ref.read(storageNotifierProvider.notifier)
            as PurplebaseStorageNotifier;
    final packageManager = _ref.read(packageManagerProvider.notifier);

    if (state == AppLifecycleState.resumed) {
      // Record app open time for background notification throttling
      unawaited(_recordAppOpened());

      // Sync installed packages to detect installs that completed while backgrounded
      unawaited(packageManager.syncInstalledPackages());

      // Re-check for app updates (works without a signed-in profile).
      unawaited(_ref.read(updatePollerProvider.notifier).checkNow());

      // Check for permission grants that happened in settings
      unawaited(_checkPermissionGrants());

      // Reconnect storage/relay connections
      notifier.connect();
    } else if (state == AppLifecycleState.paused) {
      notifier.disconnect();
    }
  }

  /// Record that the user opened the app.
  /// This is used to check inactivity for background notifications.
  Future<void> _recordAppOpened() async {
    await SettingsService().update((s) => s.copyWith(lastAppOpened: DateTime.now()));
  }
}
