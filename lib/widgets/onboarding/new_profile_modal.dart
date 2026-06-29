import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/input_field.dart';
import 'package:zapstore/widgets/common/modal.dart';

/// Callbacks registered by modal body — footer sits outside the body tree.
class _NewProfileModalActions {
  VoidCallback? submit;
  VoidCallback? useExistingKey;
}

/// Shows the new-profile modal (name input → create/existing).
///
/// [nsec] is pre-generated so PoW mining can start as soon as the user enters a name.
Future<void> showNewProfileModal(
  BuildContext context, {
  required ProfilePowMiner miner,
  required String nsec,
  required void Function(String name) onContinue,
  VoidCallback? onUseExistingKey,
}) {
  final canContinue = ValueNotifier(false);
  final actions = _NewProfileModalActions();

  return showModal<void>(
    context,
    title: 'Add a Profile',
    fillHeight: false,
    footer: (ctx) => ValueListenableBuilder<bool>(
      valueListenable: canContinue,
      builder: (_, can, __) {
        final c = Theme.of(ctx).extension<LabColors>()!;
        return ModalFooterBar(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabButton.primary(
                text: 'Create Profile',
                onTap: can ? actions.submit : null,
              ),
              const SizedBox(height: 10),
              LabButton.secondary(
                color: c.black33,
                onTap: actions.useExistingKey,
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
            ],
          ),
        );
      },
    ),
    builder: (ctx) => _NewProfileScope(
      miner: miner,
      nsec: nsec,
      canContinue: canContinue,
      actions: actions,
      onContinue: onContinue,
      onUseExistingKey: onUseExistingKey,
      child: const _NewProfileModalBody(),
    ),
  ).whenComplete(canContinue.dispose);
}

class _NewProfileScope extends StatefulWidget {
  const _NewProfileScope({
    required this.miner,
    required this.nsec,
    required this.canContinue,
    required this.actions,
    required this.onContinue,
    this.onUseExistingKey,
    required this.child,
  });

  final ProfilePowMiner miner;
  final String nsec;
  final ValueNotifier<bool> canContinue;
  final _NewProfileModalActions actions;
  final void Function(String name) onContinue;
  final VoidCallback? onUseExistingKey;
  final Widget child;

  static _NewProfileScopeState of(BuildContext context) {
    return context.findAncestorStateOfType<_NewProfileScopeState>()!;
  }

  @override
  State<_NewProfileScope> createState() => _NewProfileScopeState();
}

class _NewProfileScopeState extends State<_NewProfileScope> {
  final _ctrl = TextEditingController();
  Timer? _miningDebounce;

  @override
  void initState() {
    super.initState();
    widget.actions.submit = _submit;
    widget.actions.useExistingKey = _useExistingKey;
    _ctrl.addListener(_onNameChanged);
    _onNameChanged();
  }

  @override
  void dispose() {
    _miningDebounce?.cancel();
    widget.actions.submit = null;
    widget.actions.useExistingKey = null;
    _ctrl.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final name = _ctrl.text.trim();
    widget.canContinue.value = name.isNotEmpty;

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

  void _useExistingKey() {
    widget.miner.stop();
    Navigator.of(context).pop();
    widget.onUseExistingKey?.call();
  }

  TextEditingController get nameController => _ctrl;

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NewProfileModalBody extends StatelessWidget {
  const _NewProfileModalBody();

  @override
  Widget build(BuildContext context) {
    final scope = _NewProfileScope.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(kModalInset, 16, kModalInset, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabInputField(
            controller: scope.nameController,
            label: 'Choose a Profile Name',
            placeholder: 'Profile Name',
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _NewProfileScope.of(context).widget.actions.submit?.call(),
          ),
        ],
      ),
    );
  }
}
