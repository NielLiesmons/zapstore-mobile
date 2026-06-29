import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zapstore/services/notification_service.dart';
import 'package:zapstore/services/onboarding_profile_service.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Copy + download row shown under the spin-key reel grid after reveal.
///
/// Parent controls visibility via [Opacity] — this widget always occupies
/// its layout slot at full size.
class SecretKeyActionsRow extends HookWidget {
  const SecretKeyActionsRow({
    super.key,
    required this.nsec,
  });

  final String nsec;

  @override
  Widget build(BuildContext context) {
    final copied = useState(false);

    Future<void> onCopy() async {
      await Clipboard.setData(ClipboardData(text: nsec));
      copied.value = true;
      if (context.mounted) {
        context.showInfo('Copied to clipboard');
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!context.mounted) return;
      copied.value = false;
    }

    return Row(
      children: [
        Expanded(
          child: _SecretKeyActionPanel(
            icon: LabIcons.copy,
            label: copied.value ? 'Copied' : 'Copy',
            onTap: onCopy,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SecretKeyActionPanel(
            icon: LabIcons.download,
            iconThick: true,
            label: 'Download',
            onTap: () => shareNsecBackup(nsec),
          ),
        ),
      ],
    );
  }
}

class _SecretKeyActionPanel extends StatefulWidget {
  const _SecretKeyActionPanel({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconThick = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final bool iconThick;

  @override
  State<_SecretKeyActionPanel> createState() => _SecretKeyActionPanelState();
}

class _SecretKeyActionPanelState extends State<_SecretKeyActionPanel> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final enabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.white8,
            borderRadius: BorderRadius.circular(LabRadius.r11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              LabIcon(
                widget.icon,
                size: 16,
                color: c.white33,
                thick: widget.iconThick,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: LabTextStyles.med13.copyWith(color: c.white66),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
