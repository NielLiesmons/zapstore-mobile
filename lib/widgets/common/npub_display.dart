import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Compact npub identity display.
///
/// Shows a colored 8px dot (deterministically derived from the pubkey),
/// a trimmed bech32 npub string (`npub1xxxx…yyyy`), and a copy icon.
/// Tapping copies the full npub to the clipboard and briefly shows
/// a "Copied!" confirmation.
class NpubDisplay extends StatefulWidget {
  const NpubDisplay({
    super.key,
    required this.pubkey,
    this.profile,
    this.copyable = true,
  });

  /// Raw 64-char hex pubkey.
  final String pubkey;

  /// Optional resolved profile — not currently used for display logic
  /// but kept so callers can pass it forward for future use.
  final Profile? profile;

  /// Whether tapping copies the npub to the clipboard.
  final bool copyable;

  @override
  State<NpubDisplay> createState() => _NpubDisplayState();
}

class _NpubDisplayState extends State<NpubDisplay> {
  bool _showCheck = false;

  String get _npub =>
      Utils.encodeShareableFromString(widget.pubkey, type: 'npub');

  // Deterministic color from the hex pubkey.
  Color get _dotColor => hexToColor(widget.pubkey);

  // Show first 9 chars + … + last 4 chars, e.g. "npub1abc1…xyz9".
  String get _trimmedNpub {
    final npub = _npub;
    if (npub.length <= 14) return npub;
    return '${npub.substring(0, 9)}…${npub.substring(npub.length - 4)}';
  }

  void _handleCopy() {
    if (!widget.copyable) return;
    Clipboard.setData(ClipboardData(text: _npub));
    setState(() => _showCheck = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showCheck = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Colored dot ──────────────────────────────────────────────────────
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _dotColor,
            shape: BoxShape.circle,
            border: Border.all(color: c.white16, width: 0.5),
          ),
        ),
        const SizedBox(width: 6),

        // ── npub text (or "Copied!" feedback) ────────────────────────────────
        Text(
          _showCheck ? 'Copied!' : _trimmedNpub,
          style: LabTextStyles.reg13.copyWith(
            color: _showCheck ? c.white66 : c.white33,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(width: 5),

        // ── Trailing icon ─────────────────────────────────────────────────────
        if (_showCheck)
          LabIcon(LabIcons.check, size: 12, color: c.blurpleLightColor)
        else if (widget.copyable)
          LabIcon(LabIcons.copy, size: 12, color: c.white33),
      ],
    );

    if (!widget.copyable) return row;

    return GestureDetector(
      onTap: _handleCopy,
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}
