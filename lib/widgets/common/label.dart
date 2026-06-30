import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LabLabel
// ─────────────────────────────────────────────────────────────────────────────
//
// Pixel-faithful port of webapp's Label.svelte and zaplab_design's LabLabel.
//
// Layout: [label-content][house-shape]
//   label-content: left-rounded rect filled with baseColor @ 16% or 40%
//   house-shape:   CustomPaint arrow matching the SVG:
//                  M0 0 L4 0 Q9 2 14 6 Q19 10 23 14 Q23.5 16 23 18
//                  Q19 22 14 26 Q9 30 4 32 L0 32 Z
//
// Sizes: default (32px), small (24px), xs (20px)
//
// Selected state: background at 40% opacity, white text, leading check icon
// (matches webapp's .label-content.is-selected with the check SVG).
//
// Color: derived deterministically from [text] via stringToColor(),
//        matching the webapp and zaplab_design colour logic exactly.

enum LabLabelSize { defaultSize, small, xs }

/// Layout tokens shared by [LabLabel] and label-shaped controls (e.g. forum
/// post modal labels trigger).
class LabLabelMetrics {
  const LabLabelMetrics({
    required this.height,
    required this.houseWidth,
    required this.leftRadius,
    required this.paddingLeft,
    required this.paddingRight,
  });

  final double height;
  final double houseWidth;
  final double leftRadius;
  final double paddingLeft;
  final double paddingRight;

  static LabLabelMetrics forSize(LabLabelSize size) => switch (size) {
        LabLabelSize.xs => const LabLabelMetrics(
            height: 20,
            houseWidth: 14,
            leftRadius: 5,
            paddingLeft: 6,
            paddingRight: 4,
          ),
        LabLabelSize.small => const LabLabelMetrics(
            height: 24,
            houseWidth: 18,
            leftRadius: 8,
            paddingLeft: 8,
            paddingRight: 4,
          ),
        LabLabelSize.defaultSize => const LabLabelMetrics(
            height: 32,
            houseWidth: 24,
            leftRadius: 12,
            paddingLeft: 12,
            paddingRight: 4,
          ),
      };
}

/// Label body + house tip — same geometry as [LabLabel], arbitrary [child].
class LabLabelChrome extends StatelessWidget {
  const LabLabelChrome({
    super.key,
    required this.backgroundColor,
    required this.child,
    this.size = LabLabelSize.defaultSize,
    this.paddingLeft,
    this.maxBodyWidth,
  });

  final Color backgroundColor;
  final Widget child;
  final LabLabelSize size;
  final double? paddingLeft;
  final double? maxBodyWidth;

  @override
  Widget build(BuildContext context) {
    final m = LabLabelMetrics.forSize(size);
    final effectiveLeft = paddingLeft ?? m.paddingLeft;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: m.height,
          constraints: maxBodyWidth != null
              ? BoxConstraints(maxWidth: maxBodyWidth!)
              : null,
          padding: EdgeInsets.only(left: effectiveLeft, right: m.paddingRight),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(m.leftRadius),
            ),
          ),
          alignment: Alignment.centerLeft,
          child: child,
        ),
        LabelHouseTip(
          color: backgroundColor,
          height: m.height,
          width: m.houseWidth,
        ),
      ],
    );
  }
}

class LabLabel extends StatelessWidget {
  const LabLabel(
    this.text, {
    super.key,
    this.size = LabLabelSize.defaultSize,
    this.isSelected = false,
    this.isEmphasized = false,
    this.onTap,
  });

  final String text;
  final LabLabelSize size;
  final bool isSelected;
  final bool isEmphasized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    final baseColor = stringToColor(text);
    final bgColor = (isSelected || isEmphasized)
        ? baseColor.withValues(alpha: 0.40)
        : baseColor.withValues(alpha: 0.16);
    final textColor = (isSelected || isEmphasized) ? c.white : c.white66;

    final double checkIconSize;
    final double checkGap;
    final TextStyle textStyle;
    final double selectedPaddingLeft;

    switch (size) {
      case LabLabelSize.xs:
        checkIconSize = 8;
        checkGap = 2;
        textStyle = LabTextStyles.reg11;
        selectedPaddingLeft = 4;
      case LabLabelSize.small:
        checkIconSize = 10;
        checkGap = 3;
        textStyle = LabTextStyles.reg11;
        selectedPaddingLeft = 6;
      case LabLabelSize.defaultSize:
        checkIconSize = 12;
        checkGap = 5;
        textStyle = LabTextStyles.reg13;
        selectedPaddingLeft = 8;
    }

    final metrics = LabLabelMetrics.forSize(size);
    final effectivePaddingLeft =
        isSelected ? selectedPaddingLeft : metrics.paddingLeft;

    return GestureDetector(
      onTap: onTap,
      child: IntrinsicWidth(
        child: LabLabelChrome(
          backgroundColor: bgColor,
          size: size,
          paddingLeft: effectivePaddingLeft,
          maxBodyWidth: 200,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isSelected) ...[
                LabIcon(
                  LabIcons.check,
                  size: checkIconSize,
                  color: textColor,
                ),
                SizedBox(width: checkGap),
              ],
              Text(
                text,
                style: textStyle.copyWith(color: textColor),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Label / tag arrow tip — webapp `labels-trigger-tip` SVG (24×32 reference).
class LabelHouseTip extends StatelessWidget {
  const LabelHouseTip({
    super.key,
    required this.color,
    this.height = 32,
    this.width = 24,
  });

  final Color color;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _HouseShapePainter(color: color, totalHeight: height),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HouseShapePainter
// ─────────────────────────────────────────────────────────────────────────────
//
// Scales the webapp's fixed 24×32 path proportionally to any [size].
// Reference path (24×32):
//   M0 0 L4 0 Q9 2 14 6 Q19 10 23 14 Q23.5 16 23 18
//   Q19 22 14 26 Q9 30 4 32 L0 32 Z

class _HouseShapePainter extends CustomPainter {
  const _HouseShapePainter({required this.color, required this.totalHeight});

  final Color color;
  final double totalHeight;

  @override
  void paint(Canvas canvas, Size size) {
    // Scale factor relative to reference 32px height
    final sy = size.height / 32.0;
    final sx = size.width / 24.0;

    double x(double v) => v * sx;
    double y(double v) => v * sy;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(x(0), y(0))
      ..lineTo(x(4), y(0))
      ..quadraticBezierTo(x(9), y(2), x(14), y(6))
      ..quadraticBezierTo(x(19), y(10), x(23), y(14))
      ..quadraticBezierTo(x(23.5), y(16), x(23), y(18))
      ..quadraticBezierTo(x(19), y(22), x(14), y(26))
      ..quadraticBezierTo(x(9), y(30), x(4), y(32))
      ..lineTo(x(0), y(32))
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HouseShapePainter old) =>
      old.color != color || old.totalHeight != totalHeight;
}
