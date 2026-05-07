import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Reusable button widget matching the webapp's button CSS classes and
/// zaplab_design's LabButton / LabSmallButton / LabTabButton patterns.
///
/// Named constructors map 1:1 to the webapp's `.btn-*` classes:
///   [LabButton.primaryLarge]  → .btn-primary-large   (46px, blurple gradient, rad16)
///   [LabButton.primary]       → .btn-primary          (41px, blurple gradient, rad10)
///   [LabButton.primarySmall]  → .btn-primary-small    (34px, blurple gradient, pill)
///   [LabButton.primaryXs]     → .btn-primary-xs       (30px, blurple gradient, pill)
///   [LabButton.secondaryLarge]→ .btn-secondary-large  (46px, gray66, rad16)
///   [LabButton.secondary]     → .btn-secondary        (41px, gray66, rad10)
///   [LabButton.secondarySmall]→ .btn-secondary-small  (34px, gray66, pill)
///   [LabButton.secondaryXs]   → .btn-secondary-xs     (30px, gray66, pill)
///   [LabButton.tab]           → SocialTabs tab button  (34px, pill, blurple66 when selected)
class LabButton extends StatefulWidget {
  const LabButton({
    super.key,
    this.onTap,
    this.child,
    this.text,
    this.textStyle,
    this.textColor,
    this.gradient,
    this.color,
    this.height = 38,
    this.horizontalPadding = 18,
    this.borderRadius,
    this.pill = false,
    this.border,
    bool isPrimary = false,
  }) : _isPrimary = isPrimary,
       assert(child != null || text != null);

  final VoidCallback? onTap;
  final Widget? child;
  final String? text;
  final TextStyle? textStyle;
  final Color? textColor;
  final Gradient? gradient;
  final Color? color;
  final double height;
  final double horizontalPadding;
  final BorderRadius? borderRadius;
  final bool pill;
  final BoxBorder? border;
  // Internal flag set by the [primary] factory so the build can
  // distinguish "use theme blurple gradient" from "no color specified".
  final bool _isPrimary;

  // ── Primary (blurple gradient) ──────────────────────────────────────────

  factory LabButton.primaryLarge({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
  }) {
    return LabButton(
      key: key,
      onTap: onTap,
      text: text,
      textStyle: LabTextStyles.med17,
      height: 46,
      horizontalPadding: 22,
      borderRadius: BorderRadius.circular(16),
      pill: false,
      isPrimary: true,
      child: child,
    );
  }

  factory LabButton.primary({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
  }) {
    return LabButton(
      key: key,
      onTap: onTap,
      text: text,
      textStyle: LabTextStyles.med15,
      height: 41,
      horizontalPadding: 18,
      borderRadius: BorderRadius.circular(17),
      pill: false,
      isPrimary: true,
      child: child,
    );
  }

  factory LabButton.primarySmall({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
  }) {
    return LabButton(
      key: key,
      onTap: onTap,
      text: text,
      textStyle: LabTextStyles.med15,
      height: 34,
      horizontalPadding: 15,
      pill: true,
      isPrimary: true,
      child: child,
    );
  }

  factory LabButton.primaryXs({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
  }) {
    return LabButton(
      key: key,
      onTap: onTap,
      text: text,
      textStyle: LabTextStyles.med13,
      height: 30,
      horizontalPadding: 12,
      pill: true,
      isPrimary: true,
      child: child,
    );
  }

  // ── Secondary (gray66) ─────────────────────────────────────────────────

  factory LabButton.secondaryLarge({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
    Color? color,
  }) {
    return LabButton(
      key: key,
      onTap: onTap,
      text: text,
      textStyle: LabTextStyles.med17,
      gradient: null,
      color: color,
      height: 46,
      horizontalPadding: 22,
      borderRadius: BorderRadius.circular(16),
      pill: false,
      child: child,
    );
  }

  factory LabButton.secondary({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
    Color? color,
  }) {
    return LabButton(
      key: key,
      onTap: onTap,
      text: text,
      textStyle: LabTextStyles.med15,
      gradient: null,
      color: color,
      height: 41,
      horizontalPadding: 18,
      borderRadius: BorderRadius.circular(17),
      pill: false,
      child: child,
    );
  }

  factory LabButton.secondarySmall({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
    Color? color,
  }) {
    return LabButton(
      key: key,
      onTap: onTap,
      text: text,
      textStyle: LabTextStyles.med15,
      gradient: null,
      color: color,
      height: 34,
      horizontalPadding: 15,
      pill: true,
      child: child,
    );
  }

  factory LabButton.secondaryXs({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
    Color? color,
  }) {
    return LabButton(
      key: key,
      onTap: onTap,
      text: text,
      textStyle: LabTextStyles.med13,
      gradient: null,
      color: color,
      height: 30,
      horizontalPadding: 12,
      pill: true,
      child: child,
    );
  }

  // ── Tab button (SocialTabs-style) ──────────────────────────────────────

  factory LabButton.tab({
    Key? key,
    required VoidCallback? onTap,
    required bool isSelected,
    Widget? child,
    String? text,
  }) {
    return _AppTabButton(
      key: key,
      onTap: onTap,
      isSelected: isSelected,
      text: text,
      child: child,
    );
  }

  @override
  State<LabButton> createState() => _LabButtonState();
}

class _LabButtonState extends State<LabButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    // An explicit gradient prop always wins; the _isPrimary flag means "use
    // the theme blurple gradient"; everything else falls back to c.gray66.
    final effectiveGradient =
        widget.gradient ?? (widget._isPrimary ? c.blurple : null);
    final bgColor = effectiveGradient == null
        ? (widget.color ?? c.gray66)
        : null;
    final fgColor =
        widget.textColor ?? (widget._isPrimary ? c.whiteEnforced : c.white);

    final radius = widget.pill
        ? BorderRadius.circular(widget.height / 2)
        : (widget.borderRadius ?? BorderRadius.circular(10));

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child:         Container(
          height: widget.height,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
          decoration: BoxDecoration(
            gradient: effectiveGradient,
            color: bgColor,
            borderRadius: radius,
            border: widget.border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.child != null)
                widget.child!
              else
                Text(
                  widget.text!,
                  style: (widget.textStyle ?? LabTextStyles.med17).copyWith(
                    color: fgColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal tab-button variant with blurple66 selected state.
class _AppTabButton extends LabButton {
  final bool isSelected;

  const _AppTabButton({
    super.key,
    required super.onTap,
    required this.isSelected,
    super.child,
    super.text,
  }) : super(
         textStyle: LabTextStyles.med15,
         height: 34,
         horizontalPadding: 15,
         pill: true,
       );

  @override
  State<LabButton> createState() => _AppTabButtonState();
}

class _AppTabButtonState extends State<_AppTabButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    final Gradient? bg = widget.isSelected ? c.blurple66 : null;
    final Color? bgColor = widget.isSelected ? null : c.gray66;
    final Color fgColor = widget.isSelected ? c.whiteEnforced : c.white;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            gradient: bg,
            color: bgColor,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.child != null)
                widget.child!
              else
                Text(
                  widget.text!,
                  style: LabTextStyles.med15.copyWith(color: fgColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
