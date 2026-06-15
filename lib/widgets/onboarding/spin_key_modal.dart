import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/onboarding/pow_status_banner.dart';
import 'package:zapstore/widgets/onboarding/slot_machine.dart';

Future<void> showSpinKeyModal(
  BuildContext context, {
  required String profileName,
  required String nsec,
  required ProfilePowMiner miner,
  void Function(String nsec)? onSpinComplete,
  VoidCallback? onUseExistingKey,
}) {
  return showModal<void>(
    context,
    fillHeight: false,
    builder: (ctx) => _SpinKeyModalContent(
      profileName: profileName,
      nsec: nsec,
      miner: miner,
      onSpinComplete: onSpinComplete,
      onUseExistingKey: onUseExistingKey,
    ),
  );
}

enum _SpinKeyModalPhase { intro, revealed }

class _SpinKeyModalContent extends HookWidget {
  const _SpinKeyModalContent({
    required this.profileName,
    required this.nsec,
    required this.miner,
    this.onSpinComplete,
    this.onUseExistingKey,
  });

  final String profileName;
  final String nsec;
  final ProfilePowMiner miner;
  final void Function(String nsec)? onSpinComplete;
  final VoidCallback? onUseExistingKey;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final phase = useState(_SpinKeyModalPhase.intro);
    final powSnapshot = useState(miner.snapshot.value);

    useEffect(() {
      void listener() => powSnapshot.value = miner.snapshot.value;
      miner.snapshot.addListener(listener);
      return () => miner.snapshot.removeListener(listener);
    }, [miner]);

    final isRevealed = phase.value == _SpinKeyModalPhase.revealed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: isRevealed
                  ? _RevealedHeader(
                      key: const ValueKey('revealed-header'),
                      colors: c,
                    )
                  : _IntroHeader(
                      key: const ValueKey('intro-header'),
                      profileName: profileName,
                      colors: c,
                      onUseExistingKey: () {
                        miner.stop();
                        Navigator.of(context).pop();
                        onUseExistingKey?.call();
                      },
                    ),
            ),
            const SizedBox(height: 16),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              opacity: isRevealed ? 0 : 1,
              child: IgnorePointer(
                ignoring: isRevealed,
                child: PowStatusBanner(snapshot: powSnapshot.value),
              ),
            ),
            SizedBox(height: isRevealed ? 0 : 16),
            SpinKeySlotMachine(
              initialNsec: nsec,
              revealFinale: isRevealed,
              onSettled: (_) => phase.value = _SpinKeyModalPhase.revealed,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              ),
              child: isRevealed
                  ? _RevealedFooter(
                      key: const ValueKey('revealed-footer'),
                      profileName: profileName,
                      colors: c,
                      powSnapshot: powSnapshot.value,
                      onContinue: () {
                        Navigator.of(context).pop();
                        onSpinComplete?.call(nsec);
                      },
                    )
                  : _IntroFooter(
                      key: const ValueKey('intro-footer'),
                      colors: c,
                      onUseExistingKey: () {
                        miner.stop();
                        Navigator.of(context).pop();
                        onUseExistingKey?.call();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroHeader extends StatelessWidget {
  const _IntroHeader({
    super.key,
    required this.profileName,
    required this.colors,
    required this.onUseExistingKey,
  });

  final String profileName;
  final LabColors colors;
  final VoidCallback onUseExistingKey;

  @override
  Widget build(BuildContext context) {
    final c = colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Hey $profileName!',
          style: LabTextStyles.semibold23.copyWith(color: c.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: LabTextStyles.reg15.copyWith(color: c.white66),
            children: [
              const TextSpan(text: 'Spin up a '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: onUseExistingKey,
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
                text: ' to secure your profile and publications',
              ),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
        ),
      ],
    );
  }
}

class _RevealedHeader extends StatelessWidget {
  const _RevealedHeader({super.key, required this.colors});

  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Great!',
          style: LabTextStyles.semibold23.copyWith(color: c.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'You now have a secret key to secure your profile and publications.',
          style: LabTextStyles.reg15.copyWith(color: c.white66),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _IntroFooter extends StatelessWidget {
  const _IntroFooter({
    super.key,
    required this.colors,
    required this.onUseExistingKey,
  });

  final LabColors colors;
  final VoidCallback onUseExistingKey;

  @override
  Widget build(BuildContext context) {
    final c = colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        Container(height: 0.33, color: c.white11),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: LabButton.secondary(
            onTap: onUseExistingKey,
            child: Text(
              'I already have a secret key',
              style: LabTextStyles.med15.copyWith(color: c.white66),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _RevealedFooter extends StatelessWidget {
  const _RevealedFooter({
    super.key,
    required this.profileName,
    required this.colors,
    required this.powSnapshot,
    required this.onContinue,
  });

  final String profileName;
  final LabColors colors;
  final ProfilePowSnapshot powSnapshot;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          'This key controls $profileName on Nostr. Back it up somewhere safe — '
          'anyone with it can post as you.',
          style: LabTextStyles.reg15.copyWith(color: c.white66),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        PowStatusBanner(snapshot: powSnapshot),
        const SizedBox(height: 16),
        LabButton.primary(
          text: 'See proof of work summary',
          onTap: onContinue,
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
