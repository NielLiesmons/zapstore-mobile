import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/onboarding/slot_machine.dart';

Future<void> showSpinKeyModal(
  BuildContext context, {
  required String profileName,
  required String nsec,
  required ProfilePowMiner miner,
  required Future<void> Function(BuildContext context) onCompleteProfile,
  VoidCallback? onUseExistingKey,
}) {
  final revealed = ValueNotifier(false);

  return showModal<void>(
    context,
    fillHeight: false,
    footer: (ctx) => ValueListenableBuilder<bool>(
      valueListenable: revealed,
      builder: (_, isRevealed, __) {
        if (!isRevealed) {
          return ModalFooterBar(
            showTopDivider: false,
            child: LabButton.secondary(
              onTap: () {
                miner.stop();
                Navigator.of(ctx).pop();
                onUseExistingKey?.call();
              },
              child: Text(
                'I already have a secret key',
                style: LabTextStyles.med15.copyWith(
                  color: Theme.of(ctx).extension<LabColors>()!.white66,
                ),
              ),
            ),
          );
        }
        return ModalFooterBar(
          child: LabButton.primary(
            text: 'Complete Profile',
            onTap: () => onCompleteProfile(ctx),
          ),
        );
      },
    ),
    builder: (ctx) => _SpinKeyModalContent(
      profileName: profileName,
      nsec: nsec,
      miner: miner,
      revealed: revealed,
    ),
  ).whenComplete(revealed.dispose);
}

class _SpinKeyModalContent extends HookWidget {
  const _SpinKeyModalContent({
    required this.profileName,
    required this.nsec,
    required this.miner,
    required this.revealed,
  });

  final String profileName;
  final String nsec;
  final ProfilePowMiner miner;
  final ValueNotifier<bool> revealed;

  void _showLearnMore(BuildContext context) {
    ModalNestScope.setNested(context, isOpen: true);
    showModal<void>(
      context,
      nestedModal: true,
      title: 'Secret key',
      description:
          'Your secret key (nsec) is your Nostr account password. Anyone who '
          'has it can sign in as you. Store it offline in a password manager '
          'or encrypted backup. Never share it or paste it into untrusted apps.',
      builder: (_) => const SizedBox.shrink(),
    ).whenComplete(() {
      if (context.mounted) {
        ModalNestScope.setNested(context, isOpen: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final isRevealed = useValueListenable(revealed);
    final learnMoreRecognizer = useMemoized(
      () => TapGestureRecognizer(),
      const [],
    );
    useEffect(() {
      learnMoreRecognizer.onTap = () => _showLearnMore(context);
      return learnMoreRecognizer.dispose;
    }, [learnMoreRecognizer]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModalTitleBlock(
          title: isRevealed ? 'Great! 🎉' : 'Hey $profileName!',
          description: isRevealed
              ? null
              : 'Spin up a secret key to secure\nyour profile and publications.',
        ),
        if (isRevealed)
          Padding(
            padding: const EdgeInsets.fromLTRB(kModalInset, 10, kModalInset, 0),
            child: Text.rich(
              TextSpan(
                style: LabTextStyles.reg15.copyWith(color: c.white66),
                children: [
                  const TextSpan(
                    text:
                        'This is your secret key. Download it or copy it '
                        'into a password manager before continuing. ',
                  ),
                  TextSpan(
                    text: 'Learn more.',
                    style: LabTextStyles.reg15.copyWith(
                      color: c.white66,
                      decoration: TextDecoration.underline,
                      decorationColor: c.white33,
                    ),
                    recognizer: learnMoreRecognizer,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kModalInset),
          child: Center(
            child: SpinKeySlotMachine(
              key: const ValueKey('spin-key-slot-machine'),
              initialNsec: nsec,
              onFinaleStarted: () => revealed.value = true,
            ),
          ),
        ),
        if (!isRevealed) const SizedBox(height: 24),
        const SizedBox(height: 8),
      ],
    );
  }
}
