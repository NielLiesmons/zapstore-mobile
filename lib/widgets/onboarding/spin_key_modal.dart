import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/onboarding/slot_machine.dart';

/// Shows the slot-machine key-generation step of the onboarding flow.
///
/// Matches webapp SpinKeyModal.svelte:
///   • "Hey {name}!" title (semibold23)
///   • Description with tappable "secret key" underlined link
///   • [SpinKeySlotMachine] — drag handle down to spin
///   • Divider + "I already have a key" secondary button
///   • Auto-proceeds after spin via [onSpinComplete]
///
/// Usage:
/// ```dart
/// showSpinKeyModal(
///   context,
///   profileName: 'Alice',
///   onSpinComplete: (nsec) { /* save key, proceed */ },
///   onUseExistingKey: () { /* show key import modal */ },
/// );
/// ```
Future<void> showSpinKeyModal(
  BuildContext context, {
  required String profileName,
  void Function(String nsec)? onSpinComplete,
  VoidCallback? onUseExistingKey,
}) {
  return showModal<void>(
    context,
    title: 'Hey $profileName!',
    fillHeight: false,
    builder: (ctx) => _SpinKeyModalContent(
      profileName: profileName,
      onSpinComplete: onSpinComplete,
      onUseExistingKey: onUseExistingKey,
    ),
  );
}

class _SpinKeyModalContent extends StatelessWidget {
  const _SpinKeyModalContent({
    required this.profileName,
    this.onSpinComplete,
    this.onUseExistingKey,
  });

  final String profileName;
  final void Function(String nsec)? onSpinComplete;
  final VoidCallback? onUseExistingKey;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Description with tappable link ─────────────────────────────────
          Text.rich(
            TextSpan(
              style: LabTextStyles.reg15.copyWith(color: c.white66),
              children: [
                const TextSpan(text: 'Spin up a '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      onUseExistingKey?.call();
                    },
                    child: Text(
                      'secret key',
                      style: LabTextStyles.reg15.copyWith(
                        color: c.white66,
                        decoration: TextDecoration.underline,
                        decorationColor: c.white33,
                      ),
                    ),
                  ),
                ),
                const TextSpan(
                    text:
                        ' to secure your profile and publications'),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // ── Slot machine ────────────────────────────────────────────────────
          SpinKeySlotMachine(
            onSpinComplete: (nsec) {
              Navigator.of(context).pop();
              onSpinComplete?.call(nsec);
            },
          ),
          const SizedBox(height: 24),

          // ── Divider ─────────────────────────────────────────────────────────
          Container(height: 0.33, color: c.white11),
          const SizedBox(height: 16),

          // ── Footer: use existing key ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: LabButton.secondary(
              text: 'I already have a key',
              onTap: () {
                Navigator.of(context).pop();
                onUseExistingKey?.call();
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
