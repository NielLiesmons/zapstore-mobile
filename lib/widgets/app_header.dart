import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/app_pic.dart';
import 'package:zapstore/widgets/split_install_button.dart';
import 'package:zapstore/utils/url_utils.dart';

/// App detail header — two-row layout:
///   Row 1: AppPic (80px) + app name only
///   Row 2: PlatformPill (left) + SplitInstallButton (right)
///
/// VersionPillWidget has been removed; version info lives in the
/// Latest Release panel below.
class AppHeader extends ConsumerWidget {
  const AppHeader({super.key, required this.app});

  final App app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final platform = ref.read(packageManagerProvider.notifier).platform;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoSizeText(
                    app.name ?? app.identifier,
                    // h1 size (24px) + semibold weight via fontVariations so the
                    // Inter variable font actually renders at 600 (not w800/black).
                    style: LabTextStyles.semibold22.copyWith(
                      color: c.white,
                      fontWeight: FontWeight.w600,
                      fontVariations: const [FontVariation('wght', 600)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    minFontSize: 16,
                  ),
                  Gap(8),
                  // Platform pill (left) + install button (right)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _PlatformPill(platform: platform, colors: c),
                      const Spacer(),
                      SplitInstallButton(app: app),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        Gap(16),
      ],
    );
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
