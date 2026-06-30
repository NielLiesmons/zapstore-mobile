import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/utils/url_utils.dart';
import 'package:zapstore/widgets/common/app_pic.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'package:zapstore/widgets/modals/releases_modal.dart';
import 'package:zapstore/widgets/split_install_button.dart';

/// Flat update-list row — no card chrome, divider-separated.
///
///   [AppPic] | name + Update button
///            | version pill (opens releases)
class UpdateAppRow extends ConsumerWidget {
  const UpdateAppRow({
    super.key,
    required this.app,
    this.showActionButton = true,
  });

  final App app;
  final bool showActionButton;

  static const double iconSize = 64;
  static const double horizontalPadding = 14;
  static const double verticalPadding = 14;

  void _openAppDetail(BuildContext context) => pushApp(
        context,
        app.identifier,
        author: app.pubkey,
        kind: app.event.kind,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final operation = ref.watch(installOperationProvider(app.identifier));
    final isInstalled = ref.watch(installedPackageProvider(app.identifier)) != null;
    final isActiveOp = isActiveInstallOperation(operation, isInstalled: isInstalled);

    final installedVersion = app.installedPackage?.version;
    final availableVersion = app.installable?.version;
    final installedCode = app.installedPackage?.versionCode;
    final availableCode = app.installable?.versionCode;
    final showVersionPill =
        (installedVersion != null && installedVersion.isNotEmpty) ||
        (availableVersion != null && availableVersion.isNotEmpty) ||
        installedCode != null ||
        availableCode != null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openAppDetail(context),
            child: AppPic(
              iconUrl: firstValidHttpUrl(app.icons),
              name: app.name,
              identifier: app.identifier,
              size: iconSize,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActiveOp)
                  SplitInstallButton(
                    app: app,
                    showOptionsChevron: false,
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openAppDetail(context),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            app.name ?? app.identifier,
                            style: LabTextStyles.semibold17.copyWith(
                              color: c.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (showActionButton) ...[
                        const SizedBox(width: 8),
                        SplitInstallButton(
                          app: app,
                          showOptionsChevron: false,
                        ),
                      ],
                    ],
                  ),
                if (showVersionPill) ...[
                  const SizedBox(height: 8),
                  _VersionPill(
                    installedVersion: installedVersion,
                    availableVersion: availableVersion,
                    installedCode: installedCode,
                    availableCode: availableCode,
                    hasUpdate: app.hasUpdate,
                    onTap: app.installable != null
                        ? () => ReleasesModal.show(context, app: app)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill({
    required this.installedVersion,
    required this.availableVersion,
    required this.installedCode,
    required this.availableCode,
    required this.hasUpdate,
    this.onTap,
  });

  final String? installedVersion;
  final String? availableVersion;
  final int? installedCode;
  final int? availableCode;
  final bool hasUpdate;
  final VoidCallback? onTap;

  static const _kMaxVersionChars = 8;

  String _trim(String value) {
    if (value.length <= _kMaxVersionChars) return value;
    return '${value.substring(0, _kMaxVersionChars - 1)}…';
  }

  String _displayVersion(String? version, int? code, {required bool showCode}) {
    final trimmed = version?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return code == null ? '' : _trim(code.toString());
    }
    if (showCode && code != null) {
      return _trim('$trimmed ($code)');
    }
    return _trim(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final textStyle = LabTextStyles.reg13.copyWith(color: c.white66);

    final showCodes = hasUpdate &&
        installedVersion != null &&
        availableVersion != null &&
        installedVersion!.trim() == availableVersion!.trim() &&
        installedCode != null &&
        availableCode != null &&
        installedCode != availableCode;

    final Widget label;
    if (hasUpdate &&
        installedVersion != null &&
        availableVersion != null &&
        (installedVersion!.trim() != availableVersion!.trim() || showCodes)) {
      label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _displayVersion(
              installedVersion,
              installedCode,
              showCode: showCodes,
            ),
            style: textStyle,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 7, right: 9),
            child: Transform.rotate(
              angle: 1.5708,
              child: LabIcon(LabIcons.arrowUp, size: 12, color: c.white33),
            ),
          ),
          Text(
            _displayVersion(
              availableVersion,
              availableCode,
              showCode: showCodes,
            ),
            style: textStyle,
          ),
          if (onTap != null) ...[
            const SizedBox(width: 10),
            LabIcon(LabIcons.chevronDown, size: 7, color: c.white33),
          ],
        ],
      );
    } else {
      final version = installedVersion ?? availableVersion;
      final code = installedCode ?? availableCode;
      final display = _displayVersion(version, code, showCode: false);
      if (display.isEmpty) return const SizedBox.shrink();
      label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(display, style: textStyle),
          if (onTap != null) ...[
            const SizedBox(width: 10),
            LabIcon(LabIcons.chevronDown, size: 7, color: c.white33),
          ],
        ],
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.white8,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: label,
          ),
        ),
      ),
    );
  }
}

/// Divider between update rows.
class UpdateAppRowDivider extends StatelessWidget {
  const UpdateAppRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: UpdateAppRow.horizontalPadding),
      child: Container(height: LabStroke.thin, color: c.white11),
    );
  }
}

/// Shimmer placeholder matching [UpdateAppRow] layout.
class UpdateAppRowSkeleton extends StatelessWidget {
  const UpdateAppRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UpdateAppRow.horizontalPadding,
        vertical: UpdateAppRow.verticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Shimmer(
            width: UpdateAppRow.iconSize,
            height: UpdateAppRow.iconSize,
            radius: LabRadius.r12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    Expanded(
                      child: Shimmer(width: double.infinity, height: 16, radius: LabRadius.r8),
                    ),
                    SizedBox(width: 8),
                    Shimmer(width: 72, height: 34, radius: LabRadius.r17),
                  ],
                ),
                SizedBox(height: 8),
                Shimmer(width: 88, height: 26, radius: LabRadius.r17),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
