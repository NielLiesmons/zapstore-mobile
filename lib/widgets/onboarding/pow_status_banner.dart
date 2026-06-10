import 'package:flutter/material.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Compact live readout of background profile PoW mining.
class PowStatusBanner extends StatelessWidget {
  const PowStatusBanner({
    super.key,
    required this.snapshot,
  });

  final ProfilePowSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    final rate = snapshot.elapsed.inMilliseconds > 0
        ? (snapshot.attempts * 1000 / snapshot.elapsed.inMilliseconds).round()
        : 0;

    final statusLabel = switch ((snapshot.isRunning, snapshot.meetsMinimum)) {
      (true, false) => 'Mining proof of work…',
      (true, true) =>
        'Minimum reached — still mining for a stronger proof',
      (false, _) => 'Mining paused',
    };

    final bitsLabel = snapshot.meetsMinimum
        ? '${snapshot.bestBits} bits (min ${snapshot.targetBits})'
        : '${snapshot.bestBits}/${snapshot.targetBits} bits';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.gray33,
        borderRadius: BorderRadius.circular(LabRadius.r11),
        border: LabBorder.all(color: c.white8, width: LabStroke.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusLabel,
            style: LabTextStyles.semibold13.copyWith(color: c.white),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: snapshot.progressTowardMinimum,
                    minHeight: 6,
                    backgroundColor: c.white8,
                    color: snapshot.meetsMinimum
                        ? c.blurpleLightColor
                        : c.white66,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                bitsLabel,
                style: LabTextStyles.med11.copyWith(color: c.white66),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatAttempts(snapshot.attempts)} attempts'
            '${rate > 0 ? ' · ~${_formatAttempts(rate)}/s' : ''}'
            ' · ${_formatDuration(snapshot.elapsed)}',
            style: LabTextStyles.reg11.copyWith(color: c.white33),
          ),
        ],
      ),
    );
  }

  String _formatAttempts(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    }
    return '${d.inSeconds}s';
  }
}
