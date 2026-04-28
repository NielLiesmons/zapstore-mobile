import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';

/// Chat-style zap bubble matching webapp's ZapBubble.svelte.
///
/// Gold-tinted radial background, author name in gold gradient,
/// zap icon + formatted amount on the right.
class ZapBubble extends StatelessWidget {
  const ZapBubble({
    super.key,
    required this.name,
    required this.amount,
    this.avatarUrl,
    this.pubkey,
    this.message,
    this.timestamp,
    this.isPending = false,
    this.avatarSize = 36,
  });

  final String name;
  final int amount;
  final String? avatarUrl;
  final String? pubkey;
  final String? message;
  final DateTime? timestamp;
  final bool isPending;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ProfilePic(
            pubkey: pubkey,
            size: avatarSize,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(minWidth: 160),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.4,
                  colors: [
                    const Color(0xFFFFC736).withAlpha(26),
                    const Color(0xFFFFA037).withAlpha(26),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header: name + time | zap amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: ShaderMask(
                                shaderCallback: (bounds) => c.gold.createShader(bounds),
                                child: Text(
                                  name,
                                  style: LabTextStyles.bold15.copyWith(
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isPending)
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.blurpleColor,
                                ),
                              )
                            else if (timestamp != null)
                              Text(
                                _formatTime(timestamp!),
                                style: LabTextStyles.reg13.copyWith(
                                  color: c.white33,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LabIcon(
                            LabIcons.zap,
                            size: 14,
                            gradient: c.gold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatAmount(amount),
                            style: LabTextStyles.med17.copyWith(color: c.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Message body
                  if (message != null && message!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message!,
                      style: LabTextStyles.reg15.copyWith(
                        color: c.white.withAlpha(217),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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

  static String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }
}
