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
    final c = Theme.of(context).extension<AppColors>()!;
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
                    style: AppTextStyles.h1.copyWith(color: c.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    minFontSize: 16,
                  ),
                  Gap(12),
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

/// Small pill showing the target platform (e.g. "Android").
class _PlatformPill extends StatelessWidget {
  const _PlatformPill({required this.platform, required this.colors});

  final String platform;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.white8,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Text(
        _label(platform),
        style: AppTextStyles.med13.copyWith(color: colors.white66),
      ),
    );
  }

  String _label(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      case 'linux':
        return 'Linux';
      case 'macos':
        return 'macOS';
      case 'windows':
        return 'Windows';
      default:
        return platform;
    }
  }
}
