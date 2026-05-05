import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:zapstore/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LabDropdownMenu + LabDropdownItem
//
// Flutter port of webapp's DropdownMenu.svelte — provides the shared styling
// for ALL small floating menus in the app (suggestion panels, context menus,
// action sheets, etc.).
//
// Container:  gray66 + blur(24) backdrop, 0.33px white16 border, r16,
//             0 8px 32px black33 shadow — matches .dropdown-menu-container.
//
// Item:       10px 14px padding, 14px w500 white text, white4 press feedback,
//             0.33px white16 auto-divider between adjacent items — matches
//             .dropdown-item.
// ─────────────────────────────────────────────────────────────────────────────

/// Styled floating menu container. Place [LabDropdownItem] children inside.
///
/// Handles clipping, blur, border, and shadow. The parent is responsible for
/// positioning (absolute / overlay / CompositedTransformFollower).
class LabDropdownMenu extends StatelessWidget {
  const LabDropdownMenu({
    super.key,
    required this.children,
    this.constraints,
  });

  final List<Widget> children;

  /// Optional max-height / max-width constraints for scrollable menus.
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    Widget content = Container(
      constraints: constraints,
      decoration: BoxDecoration(
        // .dropdown-menu-container { background: var(--gray66) }
        color: c.gray66,
        borderRadius: BorderRadius.circular(16),
        border: LabBorder.all(
          // .dropdown-menu-container { border: 0.33px solid var(--white16) }
          color: c.white16,
          width: LabStroke.thin,
        ),
        boxShadow: [
          // .dropdown-menu-container { box-shadow: 0 8px 32px var(--black33) }
          BoxShadow(
            color: Colors.black.withOpacity(0.33),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    // IntrinsicWidth constrains the widget to its content width so the
    // BackdropFilter region doesn't expand to fill the Overlay/Align parent.
    return IntrinsicWidth(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: content,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// A single tappable row inside a [LabDropdownMenu].
///
/// Auto-divider: a 0.33px white16 border-top is added between adjacent items
/// (i.e. on every item except the first). Pass [isFirst] = true to suppress it.
///
/// Variants:
///   [isDanger]  — rouge-tinted label (e.g. "Sign out", "Delete")
///   [isActive]  — white w600 label (selected state)
///   [chevron]   — optional trailing chevron widget (pass [LabIcons.chevronRight])
class LabDropdownItem extends StatefulWidget {
  const LabDropdownItem({
    super.key,
    required this.child,
    this.onTap,
    this.isFirst = false,
    this.isDanger = false,
    this.isActive = false,
    this.trailing,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Suppress the top divider (use for the first item in the menu).
  final bool isFirst;

  /// Renders label in rouge color — danger / destructive action.
  final bool isDanger;

  /// Renders label in white w600 — selected/active state.
  final bool isActive;

  /// Optional trailing widget (e.g. a chevron icon).
  final Widget? trailing;

  @override
  State<LabDropdownItem> createState() => _LabDropdownItemState();
}

class _LabDropdownItemState extends State<LabDropdownItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    final labelColor = widget.isDanger
        ? c.rougeColor.withOpacity(0.9)
        : c.white;

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: double.infinity,
        // .dropdown-item { padding: 10px 14px }
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          // .dropdown-item:hover { background-color: var(--white4) }
          color: _pressed ? c.white4 : Colors.transparent,
          // .dropdown-item + .dropdown-item { border-top: 0.33px white16 }
          border: widget.isFirst
              ? null
              : Border(
                  top: BorderSide(color: c.white16, width: LabStroke.thin),
                ),
        ),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle(
                style: TextStyle(
                  // .dropdown-item { font-size: 14px; font-weight: 500; color: white }
                  // .dropdown-item--active { font-weight: 600 }
                  fontSize: 14,
                  fontWeight:
                      widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: labelColor,
                  height: 1.3,
                ),
                child: widget.child,
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 8),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
