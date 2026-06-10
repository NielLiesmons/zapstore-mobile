import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/onboarding/pow_status_banner.dart';

Future<void> showKeyExplanationModal(
  BuildContext context, {
  required String profileName,
  required String nsec,
  required ProfilePowMiner miner,
  required VoidCallback onContinue,
}) {
  return showModal<void>(
    context,
    title: 'Your secret key',
    fillHeight: false,
    builder: (ctx) => _KeyExplanationModalContent(
      profileName: profileName,
      nsec: nsec,
      miner: miner,
      onContinue: onContinue,
    ),
  );
}

class _KeyExplanationModalContent extends HookWidget {
  const _KeyExplanationModalContent({
    required this.profileName,
    required this.nsec,
    required this.miner,
    required this.onContinue,
  });

  final String profileName;
  final String nsec;
  final ProfilePowMiner miner;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final powSnapshot = useState(miner.snapshot.value);
    useEffect(() {
      void listener() => powSnapshot.value = miner.snapshot.value;
      miner.snapshot.addListener(listener);
      return () => miner.snapshot.removeListener(listener);
    }, [miner]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This key controls $profileName on Nostr. Back it up somewhere safe — '
            'anyone with it can post as you.',
            style: LabTextStyles.reg15.copyWith(color: c.white66),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          PowStatusBanner(snapshot: powSnapshot.value),
          const SizedBox(height: 16),
          LabButton.primary(
            text: 'See proof of work summary',
            onTap: () {
              Navigator.of(context).pop();
              onContinue();
            },
          ),
        ],
      ),
    );
  }
}
