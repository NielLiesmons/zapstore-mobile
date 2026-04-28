import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/services/bookmarks_service.dart';
import 'package:zapstore/services/notification_service.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/services/trusted_signers_service.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/base_dialog.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/floating_overflow_menu.dart';
import 'package:zapstore/widgets/install_alert_dialog.dart';

/// Split pill install button matching the plan's two-part CTA design.
///
/// Left part: main action (Install / Update / Installed / progress / error).
/// Divider: 1px white33 vertical line.
/// Right part: chevronDown → opens options modal (Share, Copy, Save, Open, Delete…).
class SplitInstallButton extends ConsumerWidget {
  const SplitInstallButton({super.key, required this.app});

  final App app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final operation = ref.watch(installOperationProvider(app.identifier));
    final installedPkg = ref.watch(installedPackageProvider(app.identifier));

    ref.listen(installOperationProvider(app.identifier), (prev, next) {
      if (next is OperationFailed && prev is! OperationFailed) {
        _showErrorToast(context, next);
      }
    });

    final isInstalled = installedPkg != null;
    final effectiveOp =
        (!isInstalled && operation is Completed) ? null : operation;
    final hasUpdate = app.hasUpdate;
    final hasDowngrade = app.hasDowngrade;
    final fileMetadata = app.installable;

    // ── Derive label / action / style ────────────────────────────────────

    String label;
    VoidCallback? leftAction;
    bool isPrimary;
    bool showSpinner = false;
    bool isDisabled = false;
    bool isError = false;
    bool isWarning = false;

    if (effectiveOp != null) {
      isPrimary = true;
      switch (effectiveOp) {
        case DownloadQueued():
          label = 'Queued';
          showSpinner = true;
          leftAction = null;

        case Downloading(:final progress):
          final pct = (progress * 100).round();
          final sizeMb = _formatTotalSizeMb();
          label = sizeMb != null ? '$pct% of $sizeMb' : '$pct%';
          leftAction = () => _pauseDownload(ref);

        case DownloadPaused(:final progress):
          final pct = (progress * 100).round();
          label = '$pct% (paused)';
          showSpinner = true;
          leftAction = () => _resumeDownload(ref);

        case Verifying(:final progress):
          label = progress > 0
              ? 'Verifying ${(progress * 100).round()}%'
              : 'Verifying...';
          showSpinner = true;
          leftAction = null;

        case AwaitingPermission():
          label = 'Grant Permission';
          isWarning = true;
          leftAction = () => _requestPermission(ref);

        case ReadyToInstall():
          label = isInstalled ? 'Queued for update' : 'Queued for install';
          showSpinner = true;
          leftAction = null;

        case Installing(:final isSilent):
          label = isSilent
              ? (isInstalled ? 'Updating...' : 'Installing...')
              : (isInstalled ? 'Requesting update' : 'Requesting install');
          showSpinner = true;
          leftAction = null;

        case InstallCancelled():
          label = 'Retry';
          isWarning = true;
          leftAction = () => _retryInstall(ref);

        case SystemProcessing():
          label = 'System processing...';
          showSpinner = true;
          leftAction = null;

        case Uninstalling():
          label = 'Uninstalling...';
          showSpinner = true;
          leftAction = null;

        case OperationFailed():
          label = 'Error';
          isError = true;
          leftAction = () => _handleErrorTap(ref, context);

        case Completed():
          label = 'Open';
          isPrimary = false;
          leftAction = () => _openApp(context, ref);
      }
    } else if (isInstalled) {
      if (hasDowngrade) {
        label = "Can't downgrade";
        isPrimary = false;
        isDisabled = true;
      } else if (hasUpdate) {
        label = 'Update';
        isPrimary = true;
        if (fileMetadata == null) {
          isDisabled = true;
          leftAction = null;
        } else {
          leftAction = () => _startDownload(context, ref, fileMetadata);
        }
      } else {
        label = 'Installed';
        isPrimary = false;
        leftAction = null;
      }
    } else {
      if (fileMetadata == null) {
        label = 'Install';
        isPrimary = true;
        isDisabled = true;
      } else {
        label = 'Install';
        isPrimary = true;
        leftAction = () => _startDownload(context, ref, fileMetadata);
      }
    }

    // ── Background ───────────────────────────────────────────────────────

    Gradient? gradient;
    Color? bgColor;

    if (isError) {
      bgColor = Theme.of(context).colorScheme.error;
    } else if (isWarning) {
      bgColor = Colors.amber.shade700;
    } else if (isDisabled || !isPrimary) {
      bgColor = c.gray66;
    } else {
      gradient = c.blurple;
    }

    // ── Build pill ───────────────────────────────────────────────────────

    return SizedBox(
      height: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? bgColor : null,
          borderRadius: BorderRadius.circular(17),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: action tap area
                GestureDetector(
                  onTap: isDisabled ? null : leftAction,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: LabTextStyles.med15.copyWith(
                            color: isDisabled ? c.white33 : c.white,
                          ),
                        ),
                        if (showSpinner) ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.white66,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Full-height divider
                Container(
                  width: LabStroke.medium,
                  color: c.whiteEnforced.withValues(alpha: 0.18),
                ),

                // Right: chevron tap area → options modal
                GestureDetector(
                  onTap: () => _openOptions(context, ref),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 9),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: LabIcon(
                          LabIcons.chevronDown,
                          size: 8,
                          color: c.white66,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Options modal ────────────────────────────────────────────────────────

  Future<void> _openOptions(BuildContext context, WidgetRef ref) async {
    await showModal<void>(
      context,
      title: app.name ?? app.identifier,
      builder: (_) => _AppOptionsContent(app: app),
    );
  }

  // ── Install actions ──────────────────────────────────────────────────────

  Future<void> _startDownload(
    BuildContext context,
    WidgetRef ref,
    Installable fileMetadata,
  ) async {
    final proceed = await _checkTrust(context, ref);
    if (!proceed) return;
    final pm = ref.read(packageManagerProvider.notifier);
    await pm.startDownload(
      app.identifier,
      fileMetadata,
      displayName: app.name,
    );
  }

  void _pauseDownload(WidgetRef ref) =>
      ref.read(packageManagerProvider.notifier).pauseDownload(app.identifier);

  void _resumeDownload(WidgetRef ref) =>
      ref.read(packageManagerProvider.notifier).resumeDownload(app.identifier);

  Future<void> _retryInstall(WidgetRef ref) =>
      ref.read(packageManagerProvider.notifier).retryInstall(app.identifier);

  Future<void> _requestPermission(WidgetRef ref) async {
    final pm = ref.read(packageManagerProvider.notifier);
    if (await pm.hasPermission()) {
      await pm.onPermissionGranted(app.identifier);
      return;
    }
    await pm.requestPermission();
    if (await pm.hasPermission()) {
      await pm.onPermissionGranted(app.identifier);
    }
  }

  Future<void> _openApp(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(packageManagerProvider.notifier).launchApp(app.identifier);
    } catch (e) {
      if (!context.mounted) return;
      context.showError(
        'Failed to launch ${app.name ?? app.identifier}',
        technicalDetails: '$e',
      );
    }
  }

  void _handleErrorTap(WidgetRef ref, BuildContext context) {
    final op = ref.read(installOperationProvider(app.identifier));
    if (op is! OperationFailed) return;
    _showErrorDetails(context, op);
    ref.read(packageManagerProvider.notifier).dismissError(app.identifier);
  }

  void _showErrorToast(BuildContext context, OperationFailed op) {
    if (op.description != null ||
        op.type == FailureType.certMismatch ||
        op.type == FailureType.incompatible) {
      _showErrorDetails(context, op);
    }
  }

  void _showErrorDetails(BuildContext context, OperationFailed op) {
    final text = [op.message, if (op.description != null) '\n${op.description}'].join();
    context.showError(
      op.message,
      technicalDetails: op.description,
      actions: [
        ('Copy', () async => Clipboard.setData(ClipboardData(text: text))),
      ],
    );
  }

  Future<bool> _checkTrust(BuildContext context, WidgetRef ref) async {
    final signerPubkey = app.author.value?.pubkey;
    bool shouldShow = true;
    if (signerPubkey != null) {
      try {
        shouldShow =
            !await ref.read(trustServiceProvider).isSignerTrusted(signerPubkey);
      } catch (_) {}
    }
    if (shouldShow) {
      if (!context.mounted) return false;
      final result = await showBaseDialog<({bool trustPermanently})>(
        context: context,
        dialog: InstallAlertDialog(app: app),
      );
      if (result == null) return false;
      if (result.trustPermanently && signerPubkey != null) {
        try {
          await ref.read(trustServiceProvider).addTrustedSigner(signerPubkey);
        } catch (_) {}
      }
    }
    return true;
  }

  String? _formatTotalSizeMb() {
    final bytes = app.installable?.size;
    if (bytes == null || bytes <= 0) return null;
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Options modal content
// ─────────────────────────────────────────────────────────────────────────────

class _AppOptionsContent extends HookConsumerWidget {
  const _AppOptionsContent({required this.app});

  final App app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedInPubkey = ref.watch(Signer.activePubkeyProvider);
    final isSignedIn = signedInPubkey != null;
    final isInstalled =
        ref.watch(installedPackageProvider(app.identifier)) != null;

    final savedAppsAsync = ref.watch(bookmarksProvider);
    final savedAppIds = savedAppsAsync.when(
      data: (ids) => ids,
      loading: () => <String>{},
      error: (_, __) => <String>{},
    );
    final appAddressableId =
        '${app.event.kind}:${app.pubkey}:${app.identifier}';
    final isSaved = savedAppIds.contains(appAddressableId);

    final shareUrl = getAppShareUrl(app);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OptionTile(
          icon: LabIcons.share,
          label: 'Share',
          onTap: () {
            Navigator.of(context).pop();
            SharePlus.instance.share(ShareParams(text: shareUrl));
          },
        ),
        _OptionTile(
          icon: LabIcons.copy,
          label: 'Copy link',
          onTap: () {
            Navigator.of(context).pop();
            Clipboard.setData(ClipboardData(text: shareUrl));
          },
        ),
        if (isSignedIn)
          _OptionTile(
            icon: LabIcons.star,
            label: isSaved ? 'Remove from saved' : 'Save app',
            onTap: () {
              Navigator.of(context).pop();
              _toggleSave(context, ref, signedInPubkey, isSaved);
            },
          ),
        _OptionTile(
          icon: LabIcons.profile,
          label: 'View publisher',
          onTap: () {
            Navigator.of(context).pop();
            pushUser(context, app.pubkey);
          },
        ),
        _OptionTile(
          icon: LabIcons.openWith,
          label: 'Open in browser',
          onTap: () {
            Navigator.of(context).pop();
            _openInBrowser(context, shareUrl);
          },
        ),
        if (isInstalled) ...[
          _OptionTile(
            icon: LabIcons.openWith,
            label: 'Open',
            onTap: () {
              Navigator.of(context).pop();
              _launchApp(context, ref);
            },
          ),
          _OptionTile(
            icon: LabIcons.cross,
            label: 'Delete app',
            isDestructive: true,
            onTap: () {
              Navigator.of(context).pop();
              _uninstall(context, ref);
            },
          ),
        ],
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
      ],
    );
  }

  Future<void> _openInBrowser(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) context.showError('Failed to open browser');
    }
  }

  Future<void> _launchApp(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(packageManagerProvider.notifier).launchApp(app.identifier);
    } catch (e) {
      if (context.mounted) {
        context.showError(
          'Failed to launch ${app.name ?? app.identifier}',
          technicalDetails: '$e',
        );
      }
    }
  }

  Future<void> _uninstall(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(packageManagerProvider.notifier).uninstall(app.identifier);
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString();
        if (!msg.contains('cancelled')) {
          context.showError('Uninstall failed', technicalDetails: msg);
        }
      }
    }
  }

  Future<void> _toggleSave(
    BuildContext context,
    WidgetRef ref,
    String signedInPubkey,
    bool isCurrentlySaved,
  ) async {
    try {
      final signer = ref.read(Signer.activeSignerProvider);
      if (signer == null) {
        if (context.mounted) {
          context.showError('Sign in required',
              description: 'You need to sign in to save apps.');
        }
        return;
      }

      final existingStackState = await ref.storage.query(
        RequestFilter<AppStack>(
          authors: {signedInPubkey},
          tags: {
            '#d': {kAppBookmarksIdentifier},
          },
        ).toRequest(),
        source: const LocalSource(),
      );
      final existingStack = existingStackState.firstOrNull;
      List<String> existingAppIds = [];

      if (existingStack != null) {
        try {
          final decrypted =
              await signer.nip44Decrypt(existingStack.content, signedInPubkey);
          existingAppIds = (jsonDecode(decrypted) as List).cast<String>();
        } catch (_) {}
      }

      final appId = '${app.event.kind}:${app.pubkey}:${app.identifier}';
      if (isCurrentlySaved) {
        existingAppIds.remove(appId);
      } else {
        if (!existingAppIds.contains(appId)) existingAppIds.add(appId);
      }

      final platform = ref.read(packageManagerProvider.notifier).platform;
      final partialStack = PartialAppStack.withEncryptedApps(
        name: 'Saved Apps',
        identifier: kAppBookmarksIdentifier,
        apps: existingAppIds,
        platform: platform,
      );
      final signed = await partialStack.signWith(signer);
      await ref.storage.save({signed});
      ref.storage.publish({signed}, relays: 'AppCatalog');

      if (context.mounted) {
        context.showInfo(
            isCurrentlySaved ? 'App removed from saved' : 'App saved');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Failed to update bookmark', technicalDetails: '$e');
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single option row in the options modal
// ─────────────────────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final color = isDestructive ? const Color(0xFFFF453A) : c.white;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            LabIcon(icon, size: 18, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: LabTextStyles.reg17.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
