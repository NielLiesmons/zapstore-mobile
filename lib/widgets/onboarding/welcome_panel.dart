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
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
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
              _WelcomeOption(
                icon: LabIcons.profile,
                title: 'Add a Profile',
                description: 'To enjoy our social features',
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                onTap: () => launchProfileOnboarding(context, ref),
              ),
              Container(height: LabStroke.thin, color: c.white16),
              _WelcomeOption(
                icon: LabIcons.qr,
                title: 'Scan Code',
                description: 'For Apps and Invite codes',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeOption extends StatelessWidget {
  const _WelcomeOption({
    required this.icon,
    required this.title,
    required this.description,
    this.padding = const EdgeInsets.fromLTRB(10, 8, 10, 8),
    this.onTap,
  });

  final String icon;
  final String title;
  final String description;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  static const double _iconBoxSize = 40;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _iconBoxSize,
                height: _iconBoxSize,
                decoration: BoxDecoration(
                  color: c.black33,
                  borderRadius: BorderRadius.circular(LabRadius.r11),
                ),
                child: Center(
                  child: LabIcon(
                    icon,
                    size: 20,
                    thick: true,
                    color: c.white33,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: LabTextStyles.med13.copyWith(color: c.white66),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      description,
                      style: LabTextStyles.reg13.copyWith(color: c.white33),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
