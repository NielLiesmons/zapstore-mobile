import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/main.dart';
import 'package:zapstore/services/local_signer_service.dart';
import 'package:zapstore/services/notification_service.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/key_generator.dart';
import 'package:zapstore/widgets/onboarding/new_profile_modal.dart';
import 'package:zapstore/widgets/onboarding/pow_resume_modal.dart';
import 'package:zapstore/widgets/onboarding/spin_key_modal.dart';
import 'package:zapstore/widgets/onboarding/use_existing_key_modal.dart';

/// Profile-creation onboarding: name → spin key → key explainer → PoW resume → publish.
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
        onSpinComplete: (completedNsec) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            miner.stop();
            final resumeSnapshot = miner.snapshot.value;
            showPowResumeModal(
              context,
              profileName: name,
              snapshot: resumeSnapshot,
              onPublish: () => _finishNewProfileOnboarding(
                context,
                ref,
                displayName: name,
                nsec: completedNsec,
                miner: miner,
              ),
            );
          });
        },
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

Future<void> _finishNewProfileOnboarding(
  BuildContext context,
  WidgetRef ref, {
  required String displayName,
  required String nsec,
  required ProfilePowMiner miner,
}) async {
  try {
    await ref.read(localSignerServiceProvider).saveNsec(nsec);
    final hex = KeyGenerator.nsecToHex(nsec);
    final signer = Bip340PrivateKeySigner(hex, ref.asRef);
    await signer.signIn();

    final pow = miner.snapshot.value.best;
    miner.stop();

    final partial = PartialProfile(name: displayName.trim());
    if (pow != null) {
      partial.event.createdAt =
          DateTime.fromMillisecondsSinceEpoch(pow.createdAtSeconds * 1000);
      partial.event.addTag('nonce', [
        '${pow.nonce}',
        '${miner.targetBits}',
      ]);
    }

    final signed = await partial.signWith(signer);
    await ref.storage.save({signed});
    await ref.storage.publish({signed}, relays: {'social', 'vertex'});

    await onSignInSuccess(ref.asRef);
    if (context.mounted) context.go('/');
  } catch (e) {
    if (context.mounted) {
      context.showError(
        'Profile setup failed',
        technicalDetails: '$e',
      );
    }
  } finally {
    miner.dispose();
  }
}
