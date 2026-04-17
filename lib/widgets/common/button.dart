import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Reusable button widget matching the webapp's button CSS classes and
/// zaplab_design's LabButton / LabSmallButton / LabTabButton patterns.
///
/// Named constructors map 1:1 to the webapp's `.btn-*` classes:
///   [AppButton.primary]       → .btn-primary        (38px, blurple gradient, rad16)
///   [AppButton.primarySmall]  → .btn-primary-small   (32px, blurple gradient, pill)
///   [AppButton.primaryXs]     → .btn-primary-xs      (24px, blurple gradient, pill)
///   [AppButton.secondary]     → .btn-secondary       (38px, gray66, rad16)
///   [AppButton.secondarySmall]→ .btn-secondary-small  (32px, gray66, pill)
///   [AppButton.secondaryXs]   → .btn-secondary-xs     (24px, gray66, pill)
///   [AppButton.tab]           → SocialTabs tab button  (32px, pill, blurple66 when selected)
class AppButton extends StatefulWidget {
  const AppButton({
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

  factory AppButton.primary({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
  }) {
    return AppButton(
      key: key,
      onTap: onTap,
      child: child,
      text: text,
      textStyle: AppTextStyles.med15,
      height: 42,
      horizontalPadding: 18,
      pill: false,
      isPrimary: true,
    );
  }

  factory AppButton.primarySmall({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
  }) {
    return AppButton(
      key: key,
      onTap: onTap,
      child: child,
      text: text,
      textStyle: AppTextStyles.med15,
      height: 36,
      horizontalPadding: 16,
      pill: true,
      isPrimary: true,
    );
  }

  factory AppButton.primaryXs({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
  }) {
    return AppButton(
      key: key,
      onTap: onTap,
      child: child,
      text: text,
      textStyle: AppTextStyles.med13,
      height: 26,
      horizontalPadding: 12,
      pill: true,
      isPrimary: true,
    );
  }

  // ── Secondary (gray66) ─────────────────────────────────────────────────

  factory AppButton.secondary({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
    Color? color,
  }) {
    return AppButton(
      key: key,
      onTap: onTap,
      child: child,
      text: text,
      textStyle: AppTextStyles.med15,
      gradient: null,
      color: color,
      height: 42,
      horizontalPadding: 18,
      pill: false,
    );
  }

  factory AppButton.secondarySmall({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
    Color? color,
  }) {
    return AppButton(
      key: key,
      onTap: onTap,
      child: child,
      text: text,
      textStyle: AppTextStyles.med15,
      gradient: null,
      color: color,
      height: 36,
      horizontalPadding: 16,
      pill: true,
    );
  }

  factory AppButton.secondaryXs({
    Key? key,
    required VoidCallback? onTap,
    Widget? child,
    String? text,
    Color? color,
  }) {
    return AppButton(
      key: key,
      onTap: onTap,
      child: child,
      text: text,
      textStyle: AppTextStyles.med13,
      gradient: null,
      color: color,
      height: 26,
      horizontalPadding: 12,
      pill: true,
    );
  }

  // ── Tab button (SocialTabs-style) ──────────────────────────────────────

  factory AppButton.tab({
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
      child: child,
      text: text,
    );
  }

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

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
        : (widget.borderRadius ?? BorderRadius.circular(18));

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: widget.height,
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
                  style: (widget.textStyle ?? AppTextStyles.med17).copyWith(
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
class _AppTabButton extends AppButton {
  final bool isSelected;

  _AppTabButton({
    super.key,
    required super.onTap,
    required this.isSelected,
    super.child,
    super.text,
  }) : super(
         textStyle: AppTextStyles.med15,
         height: 32,
         horizontalPadding: 14,
         pill: true,
       );

  @override
  State<AppButton> createState() => _AppTabButtonState();
}

class _AppTabButtonState extends State<_AppTabButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

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
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: bg,
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
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
                  style: AppTextStyles.med15.copyWith(color: fgColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
