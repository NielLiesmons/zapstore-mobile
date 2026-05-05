import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Eyebrow / section label matching LabSectionTitle — ALL-CAPS, white33, h3 style.
///
/// Use above panels or groups of content: "IDENTIFIERS", "LATEST RELEASES", etc.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: LabTextStyles.eyebrow13.copyWith(color: c.white33),
      ),
    );
  }
}

/// Section header matching webapp's SectionHeader.svelte:
/// title (semibold20 = h2) on the left, optional "See more" with stroked
/// chevron icon on the right.
class SectionHeader extends StatefulWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.linkText,
    this.onLinkTap,
  });

  final String title;
  final String? linkText;
  final VoidCallback? onLinkTap;

  @override
  State<SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<SectionHeader> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final hasLink = widget.linkText != null && widget.onLinkTap != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              widget.title,
              // Matches webapp .section-title: 22px, weight 650, line-height 100%
              style: TextStyle(
                fontFamily: kFontFamily,
                fontVariations: const [FontVariation('wght', 650)],
                fontSize: 22,
                height: 1.0,
                letterSpacing: 0.15,
                leadingDistribution: TextLeadingDistribution.even,
                decoration: TextDecoration.none,
                color: c.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasLink)
            GestureDetector(
              onTap: widget.onLinkTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              // Pill button: no fixed height (Row height = title height = 20px),
              // horizontal padding 8px, background flash on press.
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _pressed ? c.white8 : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      widget.linkText!,
                      style: LabTextStyles.reg13.copyWith(
                        color: _pressed ? c.white66 : c.white33,
                      ),
                    ),
                    const SizedBox(width: 10),
                    LabIcon(
                      LabIcons.chevronRight,
                      size: 14,
                      color: _pressed ? c.white66 : c.white33,
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
