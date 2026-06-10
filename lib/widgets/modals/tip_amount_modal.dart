import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/modal.dart';

const _kTipPresets = [21, 100, 500, 1000, 5000, 10000];

/// Simple tip amount picker — port of webapp `TipAmountModal.svelte`.
Future<int?> showTipAmountModal(
  BuildContext context, {
  int? initialAmount,
}) {
  return showModal<int>(
    context,
    title: 'Add a Tip',
    builder: (_) => _TipAmountContent(initialAmount: initialAmount),
  );
}

class _TipAmountContent extends StatefulWidget {
  const _TipAmountContent({this.initialAmount});

  final int? initialAmount;

  @override
  State<_TipAmountContent> createState() => _TipAmountContentState();
}

class _TipAmountContentState extends State<_TipAmountContent> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialAmount != null ? '${widget.initialAmount}' : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm([int? preset]) {
    final amount = preset ?? int.tryParse(_ctrl.text.trim()) ?? 0;
    if (amount < 1) return;
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in _kTipPresets)
                GestureDetector(
                  onTap: () => _confirm(n),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.gray33,
                      borderRadius: BorderRadius.circular(LabRadius.r17),
                      border: LabBorder.all(color: c.white16, width: LabStroke.thin),
                    ),
                    child: Text(
                      '$n sats',
                      style: LabTextStyles.med15.copyWith(color: c.white66),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            style: LabTextStyles.reg15.copyWith(color: c.white),
            decoration: InputDecoration(
              hintText: 'Custom amount',
              hintStyle: LabTextStyles.reg15.copyWith(color: c.white33),
              filled: true,
              fillColor: c.black33,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LabRadius.r11),
                borderSide: BorderSide(color: c.white16, width: LabStroke.thin),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LabRadius.r11),
                borderSide: BorderSide(color: c.white16, width: LabStroke.thin),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LabRadius.r11),
                borderSide: BorderSide(color: c.white33, width: LabStroke.thin),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LabButton.primary(
            onTap: () => _confirm(),
            text: 'Add Tip',
          ),
        ],
      ),
    );
  }
}
