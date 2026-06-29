import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/main.dart' show onSignInSuccess;
import 'package:zapstore/services/local_signer_service.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/utils/key_generator.dart';
import 'package:zapstore/services/notification_service.dart';
import 'package:zapstore/widgets/common/modal.dart';
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
      showSpinKeyModal(
        context,
        profileName: name,
        nsec: nsec,
        miner: miner,
        onCompleteProfile: (spinCtx) => _openCompleteProfile(
          spinCtx,
          ref,
          displayName: name,
          nsec: nsec,
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

Future<void> _openCompleteProfile(
  BuildContext spinContext,
  WidgetRef ref, {
  required String displayName,
  required String nsec,
  required ProfilePowMiner miner,
}) async {
  ModalNestScope.setNested(spinContext, isOpen: true);
  try {
    await _ensureOnboardingSignIn(ref, nsec: nsec);

    if (!spinContext.mounted) return;
    if (ref.read(Signer.activePubkeyProvider) == null) {
      spinContext.showError(
        'Profile setup failed',
        description: 'Could not sign in with your new key.',
        technicalDetails: 'activePubkey is null after onboarding sign-in',
      );
      return;
    }

    final saved = await showCompleteProfileModal(
      spinContext,
      ref,
      initialName: displayName,
      miner: miner,
      nestedModal: true,
      publishOnSave: false,
    );

    if (saved && spinContext.mounted) {
      Navigator.of(spinContext).pop();
      if (spinContext.mounted) spinContext.go('/');
    }
  } catch (e) {
    if (spinContext.mounted) {
      spinContext.showError(
        'Profile setup failed',
        technicalDetails: '$e',
      );
    }
  } finally {
    if (spinContext.mounted) {
      ModalNestScope.setNested(spinContext, isOpen: false);
    }
  }
}

/// Local sign-in so the complete-profile modal can open without relay publish.
Future<void> _ensureOnboardingSignIn(
  WidgetRef ref, {
  required String nsec,
}) async {
  if (ref.read(Signer.activePubkeyProvider) != null) return;

  await ref.read(localSignerServiceProvider).saveNsec(nsec);
  final hex = KeyGenerator.nsecToHex(nsec);
  final signer = Bip340PrivateKeySigner(hex, ref.asRef);
  await signer.signIn();
  await onSignInSuccess(ref.asRef);
}
