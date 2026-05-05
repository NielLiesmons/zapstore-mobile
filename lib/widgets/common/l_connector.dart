import 'package:flutter/material.dart';

/// L-shaped connector that links a parent avatar to a reply row below it.
///
/// Replicates the SVG path used in both `RootComment.svelte` and
/// `ForumPostCard.svelte` in the webapp:
///
///   `.connector-vertical` + `.connector-corner`
///   → `M1 0 L1 12 Q1 H 16 H L27 H`  (H = height - 1px)
///
/// Usage:
/// ```dart
/// SizedBox(
///   width: 27,
///   height: 28,
///   child: LabLConnector(color: c.white16),
/// )
/// ```
class LabLConnector extends StatelessWidget {
  const LabLConnector({
    super.key,
    required this.color,
    this.strokeWidth = 1.5,
  });

  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _LConnectorPainter(color, strokeWidth));
  }
}

class _LConnectorPainter extends CustomPainter {
  const _LConnectorPainter(this.color, this.strokeWidth);

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The horizontal arm sits 1px from the bottom so the stroke doesn't clip.
    final hY = size.height - 1;

    final path = Path()
      ..moveTo(0.75, 0)
      ..lineTo(0.75, 12)
      ..quadraticBezierTo(0.75, hY, 16, hY)
      ..lineTo(size.width, hY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LConnectorPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
