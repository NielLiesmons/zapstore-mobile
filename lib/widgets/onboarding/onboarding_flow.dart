import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/utils/key_generator.dart';
import 'package:zapstore/widgets/onboarding/complete_profile_modal.dart';
import 'package:zapstore/widgets/onboarding/new_profile_modal.dart';
import 'package:zapstore/widgets/onboarding/spin_key_modal.dart';
import 'package:zapstore/widgets/onboarding/use_existing_key_modal.dart';

/// Profile-creation onboarding: name → spin key → complete profile.
void launchProfileOnboarding(BuildContext context, WidgetRef ref) {
  final miner = ProfilePowMiner();
  final nsec = KeyGenerator.generate().nsec;

  void cancelForExistingKey() {
    miner.stop();
    miner.dispose();
  }

  showNewProfileModal(
    context,
    miner: miner,
    nsec: nsec,
    onContinue: (name) {
      if (!context.mounted) return;
      final parentContext = context;
      showSpinKeyModal(
        context,
        profileName: name,
        nsec: nsec,
        miner: miner,
        onCompleteProfile: (spinContext) => _openCompleteProfile(
          parentContext: parentContext,
          spinContext: spinContext,
          displayName: name,
          miner: miner,
        ),
        onUseExistingKey: () {
          cancelForExistingKey();
          showUseExistingKeyModal(context);
        },
      );
    },
    onUseExistingKey: () {
      cancelForExistingKey();
      showUseExistingKeyModal(context);
    },
  );
}

Future<void> _openCompleteProfile({
  required BuildContext parentContext,
  required BuildContext spinContext,
  required String displayName,
  required ProfilePowMiner miner,
}) async {
  Navigator.of(spinContext).pop();

  if (!parentContext.mounted) return;
  final saved = await showCompleteProfileModal(
    parentContext,
    initialName: displayName,
    miner: miner,
    nestedModal: false,
    publishOnSave: false,
  );

  if (saved && parentContext.mounted) {
    Navigator.of(parentContext).pop();
    if (parentContext.mounted) parentContext.go('/');
  }
}
