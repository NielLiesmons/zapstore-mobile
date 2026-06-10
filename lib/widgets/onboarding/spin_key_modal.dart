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
    title: 'Hey $profileName!',
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
    final slotKey = useMemoized(() => GlobalKey<SpinKeySlotMachineState>());
    final powSnapshot = useState(miner.snapshot.value);

    useEffect(() {
      void listener() => powSnapshot.value = miner.snapshot.value;
      miner.snapshot.addListener(listener);
      return () => miner.snapshot.removeListener(listener);
    }, [miner]);

    void onNsecReady(String key) {
      // Only restart PoW when the user picks a new key ("Spin again").
      if (key == nsec) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        miner.start(displayName: profileName, nsec: key);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                  text: ' to secure your profile and publications',
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          PowStatusBanner(snapshot: powSnapshot.value),
          const SizedBox(height: 16),
          SpinKeySlotMachine(
            key: slotKey,
            initialNsec: nsec,
            onNsecReady: onNsecReady,
            onSpinComplete: (nsec) {
              Navigator.of(context).pop();
              onSpinComplete?.call(nsec);
            },
          ),
          const SizedBox(height: 12),
          LabButton.secondary(
            text: 'Spin again (new key)',
            onTap: () => slotKey.currentState?.regenerateKey(),
          ),
          const SizedBox(height: 24),
          Container(height: 0.33, color: c.white11),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: LabButton.secondary(
              text: 'I already have a key',
              onTap: () {
                miner.stop();
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
