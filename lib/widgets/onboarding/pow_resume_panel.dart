import 'package:flutter/material.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';

/// Frozen summary of onboarding PoW — shown before publish/sign-in.
class PowResumePanel extends StatelessWidget {
  const PowResumePanel({
    super.key,
    required this.snapshot,
    required this.profileName,
  });

  final ProfilePowSnapshot snapshot;
  final String profileName;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    final rate = snapshot.elapsed.inMilliseconds > 0
        ? (snapshot.attempts * 1000 / snapshot.elapsed.inMilliseconds).round()
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.gray33,
        borderRadius: BorderRadius.circular(LabRadius.r16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proof of work summary',
            style: LabTextStyles.semibold17.copyWith(color: c.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Profile “$profileName” — mined while you set up your key.',
            style: LabTextStyles.reg13.copyWith(color: c.white66),
          ),
          const SizedBox(height: 14),
          _Row(label: 'Best difficulty', value: '${snapshot.bestBits} bits'),
          _Row(
            label: 'Relay minimum',
            value: snapshot.meetsMinimum ? 'Met (${snapshot.targetBits} bits)' : 'Not met yet',
            valueColor: snapshot.meetsMinimum ? c.blurpleLightColor : c.rougeColor,
          ),
          _Row(label: 'Hash attempts', value: _formatAttempts(snapshot.attempts)),
          if (rate > 0)
            _Row(label: 'Average speed', value: '~${_formatAttempts(rate)}/s'),
          _Row(label: 'Mining time', value: _formatDuration(snapshot.elapsed)),
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

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: LabTextStyles.reg13.copyWith(color: c.white33),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: LabTextStyles.semibold13.copyWith(
                color: valueColor ?? c.white,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
