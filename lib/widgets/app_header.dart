import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/app_pic.dart';
import 'package:zapstore/widgets/common/header_options_button.dart';
import 'package:zapstore/widgets/split_install_button.dart';
import 'package:zapstore/utils/url_utils.dart';

/// App detail header — two-row layout:
///   Row 1: AppPic (80px) + app name only
///   Row 2: PlatformPill (left, animates out during install) + SplitInstallButton (right, expands during install)
///
/// VersionPillWidget has been removed; version info lives in the
/// Latest Release panel below.
class AppHeader extends ConsumerWidget {
  const AppHeader({
    super.key,
    required this.app,
    this.onOptions,
    this.bottomSpacing = 16,
  });

  final App app;
  final VoidCallback? onOptions;

  /// Space below the icon + name block (tighter when screenshots follow).
  final double bottomSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final platform = ref.read(packageManagerProvider.notifier).platform;

    final operation = ref.watch(installOperationProvider(app.identifier));
    final isActiveOp = _isActiveOperation(operation);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Icon + name column + pill row ─────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPic(
              iconUrl: firstValidHttpUrl(app.icons),
              name: app.name,
              identifier: app.identifier,
              size: 80,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AutoSizeText(
                          app.name ?? app.identifier,
                          style: LabTextStyles.heroTitle.copyWith(color: c.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          minFontSize: 16,
                        ),
                      ),
                      if (onOptions != null) ...[
                        const SizedBox(width: 10),
                        HeaderOptionsButton(onTap: onOptions),
                      ],
                    ],
                  ),
                  Gap(10),
                  // Platform pill (left) + install button (right).
                  // During active install ops, the pill slides out and the
                  // button expands to fill the full available width.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Pill: collapses (width → 0, opacity → 0) when an
                      // install/download operation is active.
                      ClipRect(
                        child: AnimatedAlign(
                          alignment: Alignment.centerLeft,
                          widthFactor: isActiveOp ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                          child: AnimatedOpacity(
                            opacity: isActiveOp ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 180),
                            child: _PlatformPill(platform: platform, colors: c),
                          ),
                        ),
                      ),
                      // Spacer only when pill is visible; removed when button
                      // expands so the button truly fills the available width.
                      if (!isActiveOp) const Spacer(),
                      if (isActiveOp)
                        Expanded(child: SplitInstallButton(app: app))
                      else
                        SplitInstallButton(app: app),
                    ],
                  ),
                  ],
                ),
              ),
            ),
          ],
        ),

        Gap(bottomSpacing),
      ],
    );
  }

  static bool _isActiveOperation(Object? op) {
    return op is DownloadQueued ||
        op is Downloading ||
        op is DownloadPaused ||
        op is Verifying ||
        op is ReadyToInstall ||
        op is Installing ||
        op is SystemProcessing ||
        op is Uninstalling;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Small pill showing the target platform — height 36px matches SplitInstallButton,
/// fully rounded, white8 background, text only.
class _PlatformPill extends StatelessWidget {
  const _PlatformPill({required this.platform, required this.colors});

  final String platform;
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.white8,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        _label(platform),
        style: LabTextStyles.reg13.copyWith(color: colors.white66),
      ),
    );
  }

  String _label(String platform) {
    final p = platform.toLowerCase();
    // Match by prefix so "android-arm64-v8a", "ios-simulator", etc. all normalize
    if (p == 'android' || p.startsWith('android-') || p.startsWith('android_')) {
      return 'Android';
    }
    if (p == 'ios' || p.startsWith('ios-') || p.startsWith('ios_')) return 'iOS';
    if (p == 'linux' || p.startsWith('linux-') || p.startsWith('linux_')) return 'Linux';
    if (p == 'macos' || p.startsWith('macos-') || p.startsWith('darwin')) return 'macOS';
    if (p == 'windows' || p.startsWith('windows-') || p.startsWith('win')) return 'Windows';
    // Fallback: capitalize the first dash-segment
    final base = p.split(RegExp(r'[-_]')).first;
    return base.isEmpty ? platform : base[0].toUpperCase() + base.substring(1);
  }
}
