import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Tab selector matching webapp's Selector.svelte / zaplab_design's LabSelector.
///
/// Renders a rounded container with a row of [SelectorButton]s.
/// The selected button gets a white16 fill (default) or blurple gradient
/// when [emphasized] is true.
///
/// Set [dark] to true when placing the selector inside a gray-backgrounded
/// surface (e.g. modals) — the container background becomes [black33] and
/// the selection fill becomes [white8] for better contrast.
class Selector extends StatefulWidget {
  const Selector({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.emphasized = false,
    this.small = false,
    this.dark = false,
    this.onChanged,
  });

  final List<SelectorTab> tabs;
  final int initialIndex;

  /// When true the selected tab gets the blurple gradient instead of white16.
  final bool emphasized;

  /// Smaller height (26px instead of 30px).
  final bool small;

  /// Dark variant — black33 container bg + white8 selection fill.
  /// Use this inside gray-backgrounded surfaces like modals.
  final bool dark;

  final ValueChanged<int>? onChanged;

  @override
  State<Selector> createState() => _SelectorState();
}

class _SelectorState extends State<Selector> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: widget.dark ? c.black33 : c.gray66,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (int i = 0; i < widget.tabs.length; i++)
            Expanded(
              child: SelectorButton(
                selected: widget.tabs[i].selectedContent,
                unselected: widget.tabs[i].unselectedContent,
                isSelected: i == _selectedIndex,
                emphasized: widget.emphasized,
                small: widget.small,
                dark: widget.dark,
                onTap: () {
                  setState(() => _selectedIndex = i);
                  widget.onChanged?.call(i);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// A single button inside a [Selector].
class SelectorButton extends StatefulWidget {
  const SelectorButton({
    super.key,
    required this.selected,
    required this.unselected,
    required this.isSelected,
    this.emphasized = false,
    this.small = false,
    this.dark = false,
    this.onTap,
  });

  final List<Widget> selected;
  final List<Widget> unselected;
  final bool isSelected;
  final bool emphasized;

  /// Smaller height (26px instead of 30px).
  final bool small;

  /// Matches [Selector.dark] — uses white8 fill instead of white16.
  final bool dark;

  final VoidCallback? onTap;

  @override
  State<SelectorButton> createState() => _SelectorButtonState();
}

class _SelectorButtonState extends State<SelectorButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final height = widget.small ? 26.0 : 30.0;
    final fillColor = widget.dark ? c.white8 : c.white16;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: widget.isSelected && widget.emphasized ? c.blurple : null,
            color: widget.isSelected && !widget.emphasized ? fillColor : null,
            borderRadius: BorderRadius.circular(widget.emphasized ? 14 : 8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                widget.isSelected ? widget.selected : widget.unselected,
          ),
        ),
      ),
    );
  }
}

/// Data class for a [Selector] tab.
class SelectorTab {
  const SelectorTab({
    required this.label,
    this.count,
    this.isLoading = false,
  });

  final String label;
  final int? count;
  final bool isLoading;

  List<Widget> get selectedContent => _buildContent(selected: true);
  List<Widget> get unselectedContent => _buildContent(selected: false);

  List<Widget> _buildContent({required bool selected}) {
    return [
      _SelectorLabel(label: label, selected: selected),
      if (isLoading) ...[
        const SizedBox(width: 6),
        const _SelectorSpinner(),
      ] else if (count != null) ...[
        const SizedBox(width: 6),
        _SelectorCount(count: count!, selected: selected),
      ],
    ];
  }
}

class _SelectorLabel extends StatelessWidget {
  const _SelectorLabel({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Text(
      label,
      style: LabTextStyles.med15.copyWith(
        color: selected ? c.white : c.white66,
      ),
    );
  }
}

class _SelectorCount extends StatelessWidget {
  const _SelectorCount({required this.count, required this.selected});
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final display = count > 999 ? '999+' : count > 99 ? '99+' : '$count';
    return Text(
      display,
      style: LabTextStyles.med13.copyWith(
        color: selected ? c.white66 : c.white33,
      ),
    );
  }
}

class _SelectorSpinner extends StatelessWidget {
  const _SelectorSpinner();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return SizedBox(
      width: 10,
      height: 10,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        color: c.blurpleLightColor,
      ),
    );
  }
}
