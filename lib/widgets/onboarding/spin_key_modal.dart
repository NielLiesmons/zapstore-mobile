import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
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
  /// Title + footer morph at finale start — must not insert siblings above slot.
  final finaleActive = ValueNotifier(false);
  /// Description + complete-profile action after the finale animation ends.
  final revealed = ValueNotifier(false);

  return showModal<void>(
    context,
    fillHeight: false,
    footer: (ctx) => _SpinKeyMorphFooter(
      context: ctx,
      finaleActive: finaleActive,
      revealed: revealed,
      miner: miner,
      onCompleteProfile: () => onCompleteProfile(ctx),
      onUseExistingKey: onUseExistingKey,
    ),
    builder: (ctx) => _SpinKeyModalContent(
      profileName: profileName,
      nsec: nsec,
      miner: miner,
      finaleActive: finaleActive,
      revealed: revealed,
    ),
  ).whenComplete(() {
    finaleActive.dispose();
    revealed.dispose();
  });
}

/// Single pinned CTA — morphs secondary → primary in place (no swap / pop-in).
class _SpinKeyMorphFooter extends HookWidget {
  const _SpinKeyMorphFooter({
    required this.context,
    required this.finaleActive,
    required this.revealed,
    required this.miner,
    required this.onCompleteProfile,
    this.onUseExistingKey,
  });

  final BuildContext context;
  final ValueNotifier<bool> finaleActive;
  final ValueNotifier<bool> revealed;
  final ProfilePowMiner miner;
  final Future<void> Function() onCompleteProfile;
  final VoidCallback? onUseExistingKey;

  static const _height = 40.0;
  static const _radius = 10.0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final isFinaleActive = useValueListenable(finaleActive);
    final isRevealed = useValueListenable(revealed);
    final pressed = useState(false);

    final morphCtrl = useAnimationController(
      duration: const Duration(milliseconds: kSpinKeyFinaleAnimMs),
    );

    useEffect(() {
      if (isFinaleActive) {
        morphCtrl.forward();
      }
      return null;
    }, [isFinaleActive]);

    return AnimatedBuilder(
      animation: morphCtrl,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(morphCtrl.value);
        final dividerOpacity = t.clamp(0.0, 1.0);

        VoidCallback? onTap;
        if (isRevealed) {
          onTap = () => onCompleteProfile();
        } else if (!isFinaleActive) {
          onTap = () {
            miner.stop();
            Navigator.of(this.context).pop();
            onUseExistingKey?.call();
          };
        }

        return ModalFooterBar(
          showTopDivider: dividerOpacity > 0.01,
          child: GestureDetector(
            onTapDown: onTap != null ? (_) => pressed.value = true : null,
            onTapUp: onTap != null
                ? (_) {
                    pressed.value = false;
                    onTap!();
                  }
                : null,
            onTapCancel: onTap != null ? () => pressed.value = false : null,
            child: AnimatedScale(
              scale: pressed.value ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: SizedBox(
                height: _height,
                width: double.infinity,
                child: ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(child: ColoredBox(color: c.gray66)),
                    Positioned.fill(
                      child: Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(gradient: c.blurple),
                        ),
                      ),
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: Text(
                            'I already have a secret key',
                            style: LabTextStyles.med15.copyWith(
                              color: c.white66,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Text(
                            'Complete Profile',
                            style: LabTextStyles.med15.copyWith(
                              color: c.whiteEnforced,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpinKeyModalContent extends HookWidget {
  const _SpinKeyModalContent({
    required this.profileName,
    required this.nsec,
    required this.miner,
    required this.finaleActive,
    required this.revealed,
  });

  final String profileName;
  final String nsec;
  final ProfilePowMiner miner;
  final ValueNotifier<bool> finaleActive;
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
    final isFinaleActive = useValueListenable(finaleActive);
    final isRevealed = useValueListenable(revealed);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModalTitleBlock(
          title: isFinaleActive ? 'Great! 🎉' : 'Hey $profileName!',
          description: isFinaleActive
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
              key: slotMachineKey,
              initialNsec: nsec,
              onFinaleStarted: () => finaleActive.value = true,
              onFinaleComplete: () => revealed.value = true,
            ),
          ),
        ),
        if (!isRevealed) const SizedBox(height: 24),
        const SizedBox(height: 8),
      ],
    );
  }
}
