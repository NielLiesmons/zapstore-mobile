import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/input_field.dart';
import 'package:zapstore/widgets/common/modal.dart';

/// Shows the get-started onboarding modal (name input → create/existing).
Future<void> showGetStartedModal(
  BuildContext context, {
  required void Function(String name) onContinue,
  VoidCallback? onUseExistingKey,
}) {
  return showModal<void>(
    context,
    builder: (ctx) => _GetStartedModalContent(
      onContinue: onContinue,
      onUseExistingKey: onUseExistingKey,
    ),
  );
}

class _GetStartedModalContent extends StatefulWidget {
  const _GetStartedModalContent({
    required this.onContinue,
    this.onUseExistingKey,
  });
  final void Function(String name) onContinue;
  final VoidCallback? onUseExistingKey;

  @override
  State<_GetStartedModalContent> createState() =>
      _GetStartedModalContentState();
}

class _GetStartedModalContentState extends State<_GetStartedModalContent> {
  final _ctrl = TextEditingController();
  bool _canContinue = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final ok = _ctrl.text.trim().isNotEmpty;
      if (ok != _canContinue) setState(() => _canContinue = ok);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop();
    widget.onContinue(name);
  }

  void _handleExistingKey() {
    Navigator.of(context).pop();
    widget.onUseExistingKey?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Title ───────────────────────────────────────────────────────────
          Text(
            'Welcome!',
            style: LabTextStyles.semibold23.copyWith(
              color: c.white,
              fontSize: 26,
              letterSpacing: -0.4,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // ── Description ─────────────────────────────────────────────────────
          Text.rich(
            TextSpan(
              style: LabTextStyles.reg15.copyWith(color: c.white66),
              children: [
                const TextSpan(text: 'Create or add a '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: _handleExistingKey,
                    child: Text(
                      'Profile',
                      style: LabTextStyles.reg15.copyWith(
                        color: c.white66,
                        decoration: TextDecoration.underline,
                        decorationColor: c.white33,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' to get started'),
              ],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // ── Input field with label ───────────────────────────────────────────
          LabInputField(
            controller: _ctrl,
            label: 'Choose a Profile Name',
            placeholder: 'Profile Name',
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),

          const SizedBox(height: 14),

          // ── Primary button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: LabButton.primary(
              text: 'Create Profile',
              onTap: _canContinue ? _submit : null,
            ),
          ),

          const SizedBox(height: 10),

          // ── Secondary: already have a profile ───────────────────────────────
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

