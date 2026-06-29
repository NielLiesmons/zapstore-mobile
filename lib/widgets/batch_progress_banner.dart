import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/text_styles.dart';

Future<void> queueAllUpdates(WidgetRef ref, List<App> allUpdates) async {
  final pm = ref.read(packageManagerProvider.notifier);
  final pmState = ref.read(packageManagerProvider);
  final items = allUpdates
      .where((app) {
        final target = app.installable;
        if (target == null) return false;
        final installedHashes =
            pmState.installed[app.identifier]?.signatureHashes ?? const [];
        final targetHashes = target.certificateHashes;
        if (installedHashes.isNotEmpty &&
            targetHashes.isNotEmpty &&
            !installedHashes.any(targetHashes.contains)) {
          return false;
        }
        return true;
      })
      .map(
        (app) => (
          appId: app.identifier,
          target: app.installable!,
          displayName: app.name,
        ),
      )
      .toList();
  await pm.queueDownloads(items);
}

/// Compact "Update all" pill for the updates screen top bar.
class UpdateAllButton extends ConsumerWidget {
  const UpdateAllButton({super.key, required this.allUpdates});

  final List<App> allUpdates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (allUpdates.length < 2) {
      return const SizedBox.shrink();
    }

    final c = Theme.of(context).extension<LabColors>()!;
    final count = allUpdates.length;

    return GestureDetector(
      onTap: () => queueAllUpdates(ref, allUpdates),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.gray66,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Update all ',
                style: LabTextStyles.med13.copyWith(color: c.white),
              ),
              TextSpan(
                text: '$count',
                style: LabTextStyles.med13.copyWith(color: c.white33),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
