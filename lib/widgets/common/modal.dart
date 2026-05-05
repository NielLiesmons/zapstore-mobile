import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppModal — the single modal surface (matches webapp Modal.svelte + CommentModal.svelte)
// ─────────────────────────────────────────────────────────────────────────────
//
// Visual spec (modal-bottom on mobile, same as webapp):
//   • background:    gray66 + backdrop blur 14px
//   • border:        0.33px white8 (top, left, right — no bottom)
//   • top radius:    32px
//   • barrier:       65% black (matches webapp .bg-overlay)
//   • No drag handle
//   • Dismissible by tapping the barrier
//
// Modal-in-modal (matches .comment-sheet.child-modal-open CSS):
//   When [nestedOpen] is true the surface:
//     • Scales to 0.96 with transform-origin at top center
//     • Translates Y by +8px
//     • Shows a black33 overlay on top of the content
//   Use [ModalNestScope.setNested(context, isOpen: true)] from within any child
//   before calling [showModal] for the nested modal, then reset it on close.
//
// Usage:
//   await showModal(context, builder: (_) => MyContent());
//   await showModal(context, title: 'Title', footer: MyFooter(), builder: ...);

/// Barrier color used by every [showModal] call (65% black = webapp .bg-overlay).
const _kBarrierColor = Color(0xA6000000); // ~65% black

/// Pixels of tappable overlay left visible above the modal when the keyboard
/// is open, so the user can still dismiss by tapping the barrier.
const _kKeyboardTopZone = 70.0;

/// Opens a bottom-sheet modal matching webapp's Modal.svelte.
///
/// - No drag handle
/// - Dismissible by tapping the barrier
/// - [title] and [description] rendered inside the scrollable area at the top
/// - [footer] rendered pinned BELOW the scrollable content (use for action bars)
/// - [fillHeight] makes the sheet take [maxHeightFactor] of screen height
Future<T?> showModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  String? description,
  WidgetBuilder? footer,
  bool isDismissible = true,
  bool fillHeight = false,
  double maxHeightFactor = 0.618,
}) {
  final c = Theme.of(context).extension<LabColors>()!;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: false,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: _kBarrierColor,
    builder: (ctx) {
      return _AppModalSurface(
        title: title,
        description: description,
        footer: footer,
        fillHeight: fillHeight,
        maxHeightFactor: maxHeightFactor,
        colors: c,
        child: builder(ctx),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ModalNestScope — InheritedWidget that exposes the nested-modal state controller
// ─────────────────────────────────────────────────────────────────────────────
// NOTE: Named ModalNestScope (not ModalScope) to avoid shadowing Flutter's
// own ModalScope widget from package:flutter/widgets.dart.

/// Provides the ability to trigger the modal-in-modal scale effect from
/// anywhere inside a modal's widget tree.
///
/// ```dart
/// // Inside modal content, before opening a child modal:
/// ModalNestScope.setNested(context, isOpen: true);
/// await showModal(context, builder: (_) => ChildModal());
/// ModalNestScope.setNested(context, isOpen: false);
/// ```
class ModalNestScope extends InheritedWidget {
  const ModalNestScope({
    super.key,
    required super.child,
    required this.onNestedChange,
  });

  /// Callback to control whether this modal should enter its nested-open state.
  final void Function(bool isOpen) onNestedChange;

  /// Returns the nearest [ModalNestScope], or null if not inside a [showModal] surface.
  static ModalNestScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ModalNestScope>();

  /// Signal the enclosing modal surface that a nested modal is opening/closing.
  /// No-op if called outside a modal opened with [showModal].
  static void setNested(BuildContext context, {required bool isOpen}) =>
      maybeOf(context)?.onNestedChange(isOpen);

  @override
  bool updateShouldNotify(ModalNestScope old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// _AppModalSurface — the stateful surface that owns the animation state
// ─────────────────────────────────────────────────────────────────────────────

class _AppModalSurface extends StatefulWidget {
  const _AppModalSurface({
    required this.child,
    required this.colors,
    this.title,
    this.description,
    this.footer,
    this.fillHeight = false,
    this.maxHeightFactor = 0.618,
  });

  final Widget child;
  final LabColors colors;
  final String? title;
  final String? description;
  final WidgetBuilder? footer;
  final bool fillHeight;
  final double maxHeightFactor;

  @override
  State<_AppModalSurface> createState() => _AppModalSurfaceState();
}

class _AppModalSurfaceState extends State<_AppModalSurface>
    with SingleTickerProviderStateMixin {
  bool _nestedOpen = false;
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _translateAnim;
  late final Animation<double> _overlayAnim;

  /// Tracks the primary scroll offset inside the modal's child, used to drive
  /// the top-edge fade mask.
  late final ValueNotifier<double> _scrollValue;

  @override
  void initState() {
    super.initState();
    _scrollValue = ValueNotifier<double>(0.0);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    // scale 1.0 → 0.96
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic),
    );
    // translateY 0 → 8px (expressed as fraction; we apply via Transform.translate)
    _translateAnim = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic),
    );
    // overlay 0 → 1
    _overlayAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scrollValue.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _setNested(bool isOpen) {
    if (_nestedOpen == isOpen) return;
    setState(() => _nestedOpen = isOpen);
    if (isOpen) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final screenH = MediaQuery.sizeOf(context).height;
    // With edge-to-edge, sizeOf returns the full physical height.
    // We subtract the status-bar height so the modal never covers the very top,
    // then apply the caller's maxHeightFactor against the remaining space.
    final topPad = MediaQuery.paddingOf(context).top;
    final keyboardH = MediaQuery.viewInsetsOf(context).bottom;

    // When the keyboard is open we expand to almost full height, leaving only
    // _kKeyboardTopZone px of visible barrier so the user can still tap to
    // dismiss. Without the keyboard we cap at the caller's maxHeightFactor.
    final maxH = keyboardH > 0
        ? screenH - topPad - _kKeyboardTopZone
        : (screenH - topPad) * widget.maxHeightFactor;

    // ── Scroll-driven top-edge fade ────────────────────────────────────────
    // NotificationListener catches scroll events from the primary scrollable
    // inside widget.child (depth == 0 filters out nested scrollables).
    // ValueListenableBuilder drives a ShaderMask without rebuilding the child.
    // We always return ShaderMask (never swap widget types) to avoid detaching
    // the ScrollPosition — same pattern as TopScrollFader.
    final scrollableChild = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) {
          _scrollValue.value = notification.metrics.pixels;
        }
        return false;
      },
      child: ValueListenableBuilder<double>(
        valueListenable: _scrollValue,
        builder: (_, offset, inner) {
          // Fade reaches full intensity over 4 px after the 4 px trigger.
          final t = ((offset - 4.0) / 4.0).clamp(0.0, 1.0);
          return ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 1.0 - t),
                Colors.black,
              ],
            ).createShader(Rect.fromLTWH(0, 0, bounds.width, 17.0)),
            blendMode: BlendMode.dstIn,
            child: inner!,
          );
        },
        child: widget.child,
      ),
    );

    // The inner column: [optional title block] + [scrollable content] + [footer]
    Widget contentColumn = Column(
      mainAxisSize:
          widget.fillHeight ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Title block ───────────────────────────────────────────────────
        if (widget.title != null) _TitleBlock(widget.title!, widget.description, c),

        // ── Scrollable body ───────────────────────────────────────────────
        if (widget.fillHeight)
          Expanded(child: scrollableChild)
        else
          Flexible(child: scrollableChild),

        // ── Pinned footer ─────────────────────────────────────────────────
        if (widget.footer != null)
          widget.footer!(context)
        else
          // Automatic bottom safe-area pad when no custom footer is used.
          // When the keyboard is up the outer Padding(bottom: keyboardH) has
          // already raised the sheet clear of the home indicator, so we only
          // need this space when the keyboard is absent.
          SizedBox(height: keyboardH > 0 ? 0.0 : MediaQuery.paddingOf(context).bottom),
      ],
    );

    Widget sheet = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH - keyboardH),
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: c.gray66,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                top: BorderSide(color: c.white8, width: 0.33),
                left: BorderSide(color: c.white8, width: 0.33),
                right: BorderSide(color: c.white8, width: 0.33),
              ),
            ),
            // Wrap column + child-overlay in a Stack so the overlay can
            // render on top of the content (matches webapp .child-overlay).
            // IMPORTANT: the overlay must be Positioned.fill so it doesn't
            // influence the Stack's intrinsic size (which would force small
            // modals to expand to maxHeight).
            child: Stack(
              children: [
                contentColumn,
                // ── Child-modal overlay (black33, fades in when nested) ──────
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _overlayAnim,
                      builder: (_, __) => Opacity(
                        opacity: _overlayAnim.value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.black33,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(32),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // ── Animate scale + translateY (matches .comment-sheet.child-modal-open) ──
    sheet = AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.identity()
          ..scale(_scaleAnim.value)
          ..translate(0.0, _translateAnim.value),
        child: child,
      ),
      child: sheet,
    );

    // ── Keyboard padding ─────────────────────────────────────────────────────
    sheet = Padding(
      padding: EdgeInsets.only(bottom: keyboardH),
      child: sheet,
    );

    return ModalNestScope(
      onNestedChange: _setNested,
      child: sheet,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TitleBlock — title + optional description (matches .modal-title-block)
// ─────────────────────────────────────────────────────────────────────────────

class _TitleBlock extends StatelessWidget {
  const _TitleBlock(this.title, this.description, this.c);

  final String title;
  final String? description;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: LabTextStyles.semibold22.copyWith(color: c.white),
          ),
          if (description != null) ...[
            const SizedBox(height: 10),
            Text(
              description!,
              style: LabTextStyles.reg15.copyWith(color: c.white66),
              textAlign: TextAlign.start,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ModalFooterBar — standardized pinned footer bar for modals (e.g. comment input)
// ─────────────────────────────────────────────────────────────────────────────

/// A container that pins content at the bottom of an [AppModal], outside the
/// scrollable area. Provides the standard modal footer surface styling.
///
/// Use as the [footer] argument of [showModal].
class ModalFooterBar extends StatelessWidget {
  const ModalFooterBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 0.33, color: c.white8),
        Padding(padding: padding, child: child),
        // Safe area for home indicator — omitted when keyboard is up since
        // the outer sheet is already raised by keyboardH at that point.
        SizedBox(
          height: MediaQuery.viewInsetsOf(context).bottom > 0
              ? 0.0
              : MediaQuery.paddingOf(context).bottom,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Convenience variants
// ─────────────────────────────────────────────────────────────────────────────

/// Confirm/cancel variant of [showModal].
/// Returns `true` when confirmed, `false`/`null` when cancelled.
Future<bool?> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  Widget? icon,
  Color? iconColor,
}) {
  return showModal<bool>(
    context,
    builder: (_) => _ConfirmContent(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
      icon: icon,
      iconColor: iconColor,
    ),
  );
}

class _ConfirmContent extends StatelessWidget {
  const _ConfirmContent({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final Widget? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  DefaultTextStyle.merge(
                    style: TextStyle(color: iconColor ?? c.rouge33 as Color?, fontSize: 18),
                    child: icon!,
                  ),
                  const SizedBox(width: 8),
                  Text(title, style: LabTextStyles.semibold22.copyWith(color: c.white)),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(title, style: LabTextStyles.semibold22.copyWith(color: c.white)),
            ),

          Text(message, style: LabTextStyles.reg15.copyWith(color: c.white66)),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.white66,
                    side: BorderSide(color: c.white16, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(cancelLabel,
                      style: LabTextStyles.semibold15.copyWith(color: c.white66)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDestructive ? const Color(0xFFFF005C) : c.blurpleColor,
                    foregroundColor: c.whiteEnforced,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(confirmLabel,
                      style: LabTextStyles.semibold15.copyWith(color: c.whiteEnforced)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legacy compatibility — existing code that calls these keeps compiling
// ─────────────────────────────────────────────────────────────────────────────

/// Backward-compat — prefer [showModal].
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = false,
  bool showDragHandle = false,
  double maxHeightFactor = 0.618,
}) =>
    showModal<T>(context,
        isDismissible: isDismissible,
        maxHeightFactor: maxHeightFactor,
        builder: builder);

/// Backward-compat — prefer [showConfirm].
Future<bool?> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  Widget? icon,
  Color? iconColor,
}) =>
    showConfirm(context,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        icon: icon,
        iconColor: iconColor);

/// Show any widget inside a [showModal] surface. Backward-compat alias.
Future<T?> showBaseDialog<T>({
  required BuildContext context,
  required Widget dialog,
  bool barrierDismissible = true,
}) =>
    showModal<T>(context,
        isDismissible: barrierDismissible, builder: (_) => dialog);

// ─────────────────────────────────────────────────────────────────────────────
// Legacy dialog widgets (used by existing screens)
// ─────────────────────────────────────────────────────────────────────────────

class BaseDialog extends StatelessWidget {
  const BaseDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.titleIcon,
    this.titleIconColor,
    this.maxWidth = 560,
    this.applyFontSizeFactor = false,
    this.fontSizeFactor = 1.16,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final Widget? titleIcon;
  final Color? titleIconColor;
  final double maxWidth;
  final bool applyFontSizeFactor;
  final double fontSizeFactor;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    Widget body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DefaultTextStyle(
            style: LabTextStyles.semibold22.copyWith(color: c.white),
            child: titleIcon != null
                ? Row(children: [
                    DefaultTextStyle.merge(
                        style: TextStyle(color: titleIconColor, fontSize: 18),
                        child: titleIcon!),
                    const SizedBox(width: 8),
                    Flexible(child: title),
                  ])
                : title,
          ),
          const SizedBox(height: 12),
          DefaultTextStyle(
            style: LabTextStyles.reg15.copyWith(color: c.white66),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(child: content),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions
                  .map((a) => Padding(
                      padding: const EdgeInsets.only(left: 8), child: a))
                  .toList(),
            ),
          ],
        ],
      ),
    );

    if (applyFontSizeFactor) {
      body = Theme(
        data: Theme.of(context).copyWith(
            textTheme: Theme.of(context)
                .textTheme
                .apply(fontSizeFactor: fontSizeFactor)),
        child: body,
      );
    }

    return body;
  }
}

class BaseDialogTitle extends StatelessWidget {
  const BaseDialogTitle(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, style: style ?? LabTextStyles.semibold22.copyWith(color: c.white)),
    );
  }
}

class BaseDialogContent extends StatelessWidget {
  const BaseDialogContent({
    super.key,
    required this.children,
    this.mainAxisSize = MainAxisSize.min,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.padding,
  });
  final List<Widget> children;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: crossAxisAlignment,
        children: children);
    if (padding != null) content = Padding(padding: padding!, child: content);
    return content;
  }
}

class BaseDialogAction extends StatelessWidget {
  const BaseDialogAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.isPrimary = false,
    this.padding,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final bool isPrimary;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    Widget button = TextButton(onPressed: onPressed, child: child);
    if (padding != null) button = Padding(padding: padding!, child: button);
    return button;
  }
}
