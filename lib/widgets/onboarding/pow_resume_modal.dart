import 'package:flutter/material.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/onboarding/pow_resume_panel.dart';

Future<void> showPowResumeModal(
  BuildContext context, {
  required String profileName,
  required ProfilePowSnapshot snapshot,
  required Future<void> Function() onPublish,
}) {
  return showModal<void>(
    context,
    title: 'Proof of work',
    fillHeight: false,
    builder: (ctx) => _PowResumeModalContent(
      profileName: profileName,
      snapshot: snapshot,
      onPublish: onPublish,
    ),
  );
}

class _PowResumeModalContent extends StatefulWidget {
  const _PowResumeModalContent({
    required this.profileName,
    required this.snapshot,
    required this.onPublish,
  });

  final String profileName;
  final ProfilePowSnapshot snapshot;
  final Future<void> Function() onPublish;

  @override
  State<_PowResumeModalContent> createState() => _PowResumeModalContentState();
}

class _PowResumeModalContentState extends State<_PowResumeModalContent> {
  var _isPublishing = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PowResumePanel(
            snapshot: widget.snapshot,
            profileName: widget.profileName,
          ),
          const SizedBox(height: 16),
          Text(
            widget.snapshot.meetsMinimum
                ? 'This proof will be attached when your minimal profile is published.'
                : 'Minimum proof was not reached — publish may fail on strict relays.',
            style: LabTextStyles.reg13.copyWith(color: c.white66),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          LabButton.primary(
            text: 'Publish profile',
            onTap: _isPublishing
                ? null
                : () async {
                    setState(() => _isPublishing = true);
                    final navigator = Navigator.of(context);
                    try {
                      await widget.onPublish();
                      if (mounted) navigator.pop();
                    } finally {
                      if (mounted) setState(() => _isPublishing = false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
