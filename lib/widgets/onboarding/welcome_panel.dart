import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/onboarding/onboarding_flow.dart';

/// Dismissible home prompt for users without a profile yet.
///
/// Matches the inbox preview main panel: [LabColors.gray66] + [LabRadius.r16].
class WelcomePanel extends HookConsumerWidget {
  const WelcomePanel({super.key});

  static const _panelRadius = BorderRadius.all(Radius.circular(LabRadius.r16));
  static const double _dismissButtonSize = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = useState(false);
    if (dismissed.value) return const SizedBox(height: 14);

    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ClipRRect(
        borderRadius: _panelRadius,
        child: Material(
          color: c.gray66,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Welcome',
                        style: LabTextStyles.semibold17.copyWith(color: c.white),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => dismissed.value = true,
                      child: Container(
                        width: _dismissButtonSize,
                        height: _dismissButtonSize,
                        decoration: BoxDecoration(
                          color: c.white8,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: LabIcon(
                            LabIcons.cross,
                            size: 12,
                            color: c.white66,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => launchProfileOnboarding(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        LabIcon(
                          LabIcons.profile,
                          size: 18,
                          thick: true,
                          color: c.white33,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Add a Profile',
                          style: LabTextStyles.med15.copyWith(color: c.white66),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(height: LabStroke.thin, color: c.white16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      children: [
                        LabIcon(
                          LabIcons.qr,
                          size: 18,
                          thick: true,
                          color: c.white33,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Scan Code',
                          style: LabTextStyles.med15.copyWith(color: c.white66),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
