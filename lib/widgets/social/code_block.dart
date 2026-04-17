import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Code display widget matching webapp's CodeBlock.svelte.
///
/// Rounded container with optional language label, horizontally scrollable
/// code, and a copy-to-clipboard button.
class CodeBlock extends StatefulWidget {
  const CodeBlock({
    super.key,
    required this.code,
    this.language,
    this.useBlackBackground = false,
  });

  final String code;
  final String? language;
  final bool useBlackBackground;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final bgColor = widget.useBlackBackground ? c.black33 : c.gray33;

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: AppBorder.all(color: c.white16, width: 0.33),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.language != null && widget.language!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      widget.language!,
                      style: AppTextStyles.reg13.copyWith(color: c.white33),
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    widget.code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      letterSpacing: 0.15,
                      color: c.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 2,
            right: 0,
            child: GestureDetector(
              onTap: _handleCopy,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.white8,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: _copied
                      ? AppIcon(AppIcons.check, size: 14, color: c.blurpleColor)
                      : AppIcon(AppIcons.copy, size: 16,
                          outlineColor: c.white66, outlineThickness: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
