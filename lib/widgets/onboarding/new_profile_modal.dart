import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/input_field.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/onboarding/pow_status_banner.dart';

/// Shows the new-profile modal (name input → create/existing).
///
/// [nsec] is pre-generated so PoW can start as soon as the user enters a name.
Future<void> showNewProfileModal(
  BuildContext context, {
  required ProfilePowMiner miner,
  required String nsec,
  required void Function(String name) onContinue,
  VoidCallback? onUseExistingKey,
}) {
  return showModal<void>(
    context,
    title: 'Add a Profile',
    builder: (ctx) => _NewProfileModalContent(
      miner: miner,
      nsec: nsec,
      onContinue: onContinue,
      onUseExistingKey: onUseExistingKey,
    ),
  );
}

class _NewProfileModalContent extends StatefulWidget {
  const _NewProfileModalContent({
    required this.miner,
    required this.nsec,
    required this.onContinue,
    this.onUseExistingKey,
  });

  final ProfilePowMiner miner;
  final String nsec;
  final void Function(String name) onContinue;
  final VoidCallback? onUseExistingKey;

  @override
  State<_NewProfileModalContent> createState() =>
      _NewProfileModalContentState();
}

class _NewProfileModalContentState extends State<_NewProfileModalContent> {
  final _ctrl = TextEditingController();
  bool _canContinue = false;
  Timer? _miningDebounce;
  ProfilePowSnapshot _powSnapshot = const ProfilePowSnapshot();

  @override
  void initState() {
    super.initState();
    _powSnapshot = widget.miner.snapshot.value;
    widget.miner.snapshot.addListener(_onPowUpdate);
    _ctrl.addListener(_onNameChanged);
    _onNameChanged();
  }

  @override
  void dispose() {
    _miningDebounce?.cancel();
    widget.miner.snapshot.removeListener(_onPowUpdate);
    _ctrl.dispose();
    super.dispose();
  }

  void _onPowUpdate() {
    if (mounted) setState(() => _powSnapshot = widget.miner.snapshot.value);
  }

  void _onNameChanged() {
    final name = _ctrl.text.trim();
    final ok = name.isNotEmpty;
    if (ok != _canContinue) setState(() => _canContinue = ok);

    _miningDebounce?.cancel();
    _miningDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (name.isEmpty) {
        widget.miner.stop();
      } else {
        widget.miner.start(displayName: name, nsec: widget.nsec);
      }
    });
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    final onContinue = widget.onContinue;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => onContinue(name));
  }

  void _handleExistingKey() {
    widget.miner.stop();
    Navigator.of(context).pop();
    widget.onUseExistingKey?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LabInputField(
            controller: _ctrl,
            label: 'Choose a Profile Name',
            placeholder: 'Profile Name',
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          PowStatusBanner(snapshot: _powSnapshot),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: LabButton.primary(
              text: 'Create Profile',
              onTap: _canContinue ? _submit : null,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: LabButton.secondary(
              color: c.black33,
              onTap: _handleExistingKey,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LabIcon(
                    LabIcons.nostr,
                    size: 18,
                    color: c.blurpleLightColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Already have a Profile?',
                    style: LabTextStyles.med15.copyWith(color: c.white66),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
