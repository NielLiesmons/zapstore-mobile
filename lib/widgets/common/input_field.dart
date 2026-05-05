import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Styled single-line text input matching webapp's InputTextField.svelte.
///
/// Spec:
///   • 40px height, r17 border-radius
///   • black33 background, 0.33px white33 border (LabStroke.thin)
///   • 14px horizontal padding
///   • Inter reg15, white text, white33 placeholder, white cursor
///   • Optional [label] above (reg15, 8px gap)
///   • Optional [warning] bubble below (white16 bg, alert icon)
class LabInputField extends StatefulWidget {
  const LabInputField({
    super.key,
    this.controller,
    this.placeholder = '',
    this.label,
    this.warning,
    this.obscureText = false,
    this.autoCapitalize = true,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.keyboardType,
  });

  final TextEditingController? controller;
  final String placeholder;
  final String? label;
  final String? warning;
  final bool obscureText;
  final bool autoCapitalize;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;

  @override
  State<LabInputField> createState() => _LabInputFieldState();
}

class _LabInputFieldState extends State<LabInputField> {
  late final TextEditingController _ctrl;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ctrl = TextEditingController();
      _ownsController = true;
    } else {
      _ctrl = widget.controller!;
    }
  }

  @override
  void dispose() {
    if (_ownsController) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              widget.label!,
              style: LabTextStyles.reg15.copyWith(color: c.white),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.black33,
            borderRadius: BorderRadius.circular(17),
            border: LabBorder.all(color: c.white33, width: 0.33),
          ),
          child: TextField(
            controller: _ctrl,
            obscureText: widget.obscureText,
            autofocus: widget.autofocus,
            textCapitalization: widget.autoCapitalize
                ? TextCapitalization.words
                : TextCapitalization.none,
            textInputAction: widget.textInputAction,
            keyboardType: widget.keyboardType,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            style: LabTextStyles.reg15.copyWith(color: c.white),
            cursorColor: c.white,
            cursorWidth: 1.6,
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: LabTextStyles.reg15.copyWith(color: c.white33),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              // Explicit transparent fill prevents Material 3 from injecting
              // a surface-variant fill color from the theme.
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              isDense: true,
              isCollapsed: true,
            ),
          ),
        ),
        if (widget.warning != null) ...[
          const SizedBox(height: 0),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Small triangle pointer
                Container(
                  width: 0,
                  height: 0,
                  margin: const EdgeInsets.only(left: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(width: 12, color: Colors.transparent),
                      right: BorderSide(width: 12, color: Colors.transparent),
                      bottom: BorderSide(width: 10, color: Color(0x29FFFFFF)),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x29FFFFFF), // white16
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(
                    children: [
                      LabIcon(LabIcons.alert, size: 18, color: c.white66),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.warning!,
                          style: LabTextStyles.reg13.copyWith(color: c.white66),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
