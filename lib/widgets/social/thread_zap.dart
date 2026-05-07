import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/common/time_utils.dart';

/// Flat (non-bubble) root zap display for the top of a thread modal.
///
/// Mirrors webapp's ThreadZap.svelte:
///   [ProfilePic 36]  [author-name (gold gradient)]  [timestamp]  [⚡ amount right]
///                    [optional message content below]
///
/// Used in [_ThreadBody] as the root item when a zap-with-message is the
/// target of a thread, instead of [ZapBubble].
class ThreadZap extends StatelessWidget {
  const ThreadZap({
    super.key,
    required this.name,
    required this.amount,
    this.profile,
    this.pubkey,
    this.message,
    this.timestamp,
  });

  final String name;
  final int amount;
  final Profile? profile;
  final String? pubkey;
  final String? message;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Author row: avatar + name + timestamp + zap amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfilePic(profile: profile, pubkey: pubkey, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Name + timestamp
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: ShaderMask(
                              shaderCallback: (bounds) =>
                                  c.gold.createShader(bounds),
                              child: Text(
                                name,
                                style: LabTextStyles.semibold15
                                    .copyWith(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (timestamp != null) ...[
                            const SizedBox(width: 8),
                            TimeAgoText(
                              timestamp!,
                              style:
                                  LabTextStyles.reg13.copyWith(color: c.white33),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Zap amount — right-aligned, matches webapp .top-right-amount
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LabIcon(LabIcons.zap, size: 18, gradient: c.gold),
                        const SizedBox(width: 5),
                        Text(
                          _formatAmount(amount),
                          style: LabTextStyles.semibold17.copyWith(color: c.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Optional message
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message!,
              style: LabTextStyles.reg15.copyWith(
                color: c.white.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatAmount(int val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(val % 1000000 == 0 ? 0 : 1)}M';
    }
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(val % 1000 == 0 ? 0 : 1)}K';
    }
    return val.toString();
  }
}
