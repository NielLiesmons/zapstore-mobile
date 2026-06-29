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
  final finaleProgress = ValueNotifier(0.0);
  final revealed = ValueNotifier(false);

  return showModal<void>(
    context,
    fillHeight: false,
    footerEdgeFade: false,
    footer: (ctx) => _SpinKeyMorphFooter(
      context: ctx,
      finaleProgress: finaleProgress,
      revealed: revealed,
      miner: miner,
      onCompleteProfile: () => onCompleteProfile(ctx),
      onUseExistingKey: onUseExistingKey,
    ),
    builder: (ctx) => _SpinKeyModalContent(
      profileName: profileName,
      nsec: nsec,
      finaleProgress: finaleProgress,
      revealed: revealed,
    ),
  ).whenComplete(() {
    finaleProgress.dispose();
    revealed.dispose();
  });
}

/// Pinned CTA — morphs [LabButton.secondary] → [LabButton.primary] in place.
class _SpinKeyMorphFooter extends HookWidget {
  const _SpinKeyMorphFooter({
    required this.context,
    required this.finaleProgress,
    required this.revealed,
    required this.miner,
    required this.onCompleteProfile,
    this.onUseExistingKey,
  });

  final BuildContext context;
  final ValueNotifier<double> finaleProgress;
  final ValueNotifier<bool> revealed;
  final ProfilePowMiner miner;
  final Future<void> Function() onCompleteProfile;
  final VoidCallback? onUseExistingKey;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final rawT = useValueListenable(finaleProgress);
    final isRevealed = useValueListenable(revealed);
    final t = Curves.easeInOutCubic.transform(rawT);

    VoidCallback? onUseExisting;
    if (!isRevealed && rawT < 0.01) {
      onUseExisting = () {
        miner.stop();
        Navigator.of(this.context).pop();
        onUseExistingKey?.call();
      };
    }

    return ModalFooterBar(
      showTopDivider: false,
      padding: const EdgeInsets.fromLTRB(
        kModalInset,
        20,
        kModalInset,
        kModalInset,
      ),
      child: SizedBox(
        height: 41,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: IgnorePointer(
                ignoring: t > 0.5,
                child: LabButton.secondary(
                  onTap: onUseExisting,
                  child: Text(
                    'I already have a secret key',
                    style: LabTextStyles.med15.copyWith(color: c.white66),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: IgnorePointer(
                ignoring: t < 0.5 || !isRevealed,
                child: LabButton.primary(
                  text: 'Complete Profile',
                  onTap: isRevealed ? onCompleteProfile : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpinKeyModalContent extends HookWidget {
  const _SpinKeyModalContent({
    required this.profileName,
    required this.nsec,
    required this.finaleProgress,
    required this.revealed,
  });

  final String profileName;
  final String nsec;
  final ValueNotifier<double> finaleProgress;
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
    final rawT = useValueListenable(finaleProgress);
    final t = Curves.easeInOutCubic.transform(rawT);
    final slotMachineKey = useMemoized(
      () => GlobalKey<SpinKeySlotMachineState>(),
      const [],
    );
    final learnMoreRecognizer = useMemoized(
      () => TapGestureRecognizer(),
      const [],
    );
    useEffect(() {
      learnMoreRecognizer.onTap = () => _showLearnMore(context);
      return learnMoreRecognizer.dispose;
    }, [learnMoreRecognizer]);

    // Same tokens as [ModalTitleBlock] — rendered in-body so we can crossfade.
    final titleStyle = LabTextStyles.semibold23.copyWith(
      color: c.white,
      fontSize: 26,
      letterSpacing: -0.4,
      height: 1.2,
    );
    final bodyStyle = LabTextStyles.reg15.copyWith(color: c.white66);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            kModalInset,
            kModalInset + 10,
            kModalInset,
            0,
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
                Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Hey $profileName!',
                        style: titleStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Spin up a secret key to secure\nyour profile and publications.',
                        style: bodyStyle,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: IgnorePointer(
                    ignoring: t < 0.85,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Great! 🎉',
                          style: titleStyle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            style: bodyStyle,
                            children: [
                              const TextSpan(
                                text:
                                    'This is your secret key. Download it or copy it '
                                    'into a password manager before continuing. ',
                              ),
                              TextSpan(
                                text: 'Learn more.',
                                style: bodyStyle.copyWith(
                                  decoration: TextDecoration.underline,
                                  decorationColor: c.white33,
                                ),
                                recognizer: learnMoreRecognizer,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kModalInset),
          child: Center(
            child: SpinKeySlotMachine(
              key: slotMachineKey,
              initialNsec: nsec,
              onFinaleProgress: (progress) => finaleProgress.value = progress,
              onFinaleComplete: () => revealed.value = true,
            ),
          ),
        ),
      ],
    );
  }
}
