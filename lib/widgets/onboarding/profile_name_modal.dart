import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/input_field.dart';
import 'package:zapstore/widgets/common/modal.dart';

/// Shows the profile-name input step of the onboarding flow.
///
/// Presents a [LabInputField] for the user's display name and a "Continue"
/// primary button. Returns the entered name via [onContinue].
///
/// Usage:
/// ```dart
/// await showProfileNameModal(context, onContinue: (name) {
///   showSpinKeyModal(context, profileName: name, ...);
/// });
/// ```
Future<void> showProfileNameModal(
  BuildContext context, {
  required void Function(String name) onContinue,
}) {
  return showModal<void>(
    context,
    builder: (ctx) => _ProfileNameModalContent(onContinue: onContinue),
  );
}

class _ProfileNameModalContent extends StatefulWidget {
  const _ProfileNameModalContent({required this.onContinue});
  final void Function(String name) onContinue;

  @override
  State<_ProfileNameModalContent> createState() =>
      _ProfileNameModalContentState();
}

class _ProfileNameModalContentState extends State<_ProfileNameModalContent> {
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

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Zapstore logo
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: _ZapstoreLogo(color: c.white),
          ),
          Text(
            'Create your profile',
            style: LabTextStyles.semibold22.copyWith(color: c.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a display name for your Nostr profile',
            style: LabTextStyles.reg15.copyWith(color: c.white66),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          LabInputField(
            controller: _ctrl,
            placeholder: 'Your name',
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: LabButton.primary(
              text: 'Continue',
              onTap: _canContinue ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZapstoreLogo extends StatelessWidget {
  const _ZapstoreLogo({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: CustomPaint(painter: _ZapstoreLogoPainter(color)),
    );
  }
}

class _ZapstoreLogoPainter extends CustomPainter {
  const _ZapstoreLogoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // Scaled version of the Zapstore lightning bolt SVG path
    final path = Path();
    final s = size.width / 19.0;
    path.moveTo(18.8379 * s, 13.9711 * s);
    path.lineTo(8.84956 * s, 0.356086 * s);
    path.cubicTo(8.30464 * s, -0.386684 * s, 7.10438 * s, 0.128479 * s,
        7.30103 * s, 1.02073 * s);
    path.lineTo(9.04686 * s, 8.94232 * s);
    path.cubicTo(9.16268 * s, 9.46783 * s, 8.74887 * s, 9.96266 * s,
        8.19641 * s, 9.9593 * s);
    path.lineTo(0.871032 * s, 9.91477 * s);
    path.cubicTo(0.194934 * s, 9.91066 * s, -0.223975 * s, 10.6293 * s,
        0.126748 * s, 11.1916 * s);
    path.lineTo(7.69743 * s, 23.3297 * s);
    path.cubicTo(7.99957 * s, 23.8141 * s, 7.73264 * s, 24.4447 * s,
        7.16744 * s, 24.5816 * s);
    path.lineTo(5.40958 * s, 25.0076 * s);
    path.cubicTo(4.70199 * s, 25.179 * s, 4.51727 * s, 26.0734 * s,
        5.10186 * s, 26.4974 * s);
    path.lineTo(12.4572 * s, 31.8326 * s);
    path.cubicTo(12.9554 * s, 32.194 * s, 13.6711 * s, 31.9411 * s,
        13.8147 * s, 31.3529 * s);
    path.lineTo(15.8505 * s, 23.0152 * s);
    path.cubicTo(16.0137 * s, 22.3465 * s, 15.3281 * s, 21.7801 * s,
        14.6762 * s, 22.0452 * s);
    path.lineTo(13.0661 * s, 22.7001 * s);
    path.cubicTo(12.5619 * s, 22.9052 * s, 11.991 * s, 22.6092 * s,
        11.8849 * s, 22.0877 * s);
    path.lineTo(10.7521 * s, 16.5224 * s);
    path.cubicTo(10.6486 * s, 16.014 * s, 11.038 * s, 15.5365 * s,
        11.5704 * s, 15.5188 * s);
    path.lineTo(18.1639 * s, 15.2998 * s);
    path.cubicTo(18.8529 * s, 15.2769 * s, 19.2383 * s, 14.517 * s,
        18.8379 * s, 13.9711 * s);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ZapstoreLogoPainter old) => old.color != color;
}
