import 'package:flutter/material.dart';
import 'package:models/models.dart';
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
    this.profile,
    this.pubkey,
    this.message,
    this.timestamp,
    this.isPending = false,
    this.avatarSize = 36,
    this.topPadding = 4,
  });

  final String name;
  final int amount;
  /// Optional loaded [Profile] — passed to [ProfilePic] for real avatars.
  final Profile? profile;
  final String? pubkey;
  final String? message;
  final DateTime? timestamp;
  final bool isPending;
  final double avatarSize;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: EdgeInsets.only(top: topPadding, left: 14, right: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Flexible+IntrinsicWidth mirrors MessageBubble's incoming layout:
          // the inner Flexible gives the bubble body finite constraints so
          // CrossAxisAlignment.stretch and spaceBetween work correctly, and
          // the bubble shrinks to fit its content like a chat bubble.
          Flexible(
            child: IntrinsicWidth(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ProfilePic(
                    pubkey: pubkey,
                    profile: profile,
                    size: avatarSize,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 120),
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
                      padding: const EdgeInsets.fromLTRB(11, 6, 11, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header: name + timestamp | zap amount
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: ShaderMask(
                                          shaderCallback: (bounds) =>
                                              c.gold.createShader(bounds),
                                          child: Text(
                                            name,
                                            style: LabTextStyles.semibold13
                                                .copyWith(color: Colors.white),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isPending)
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: c.blurpleLightColor,
                                          ),
                                        )
                                      else if (timestamp != null)
                                        Text(
                                          _formatTime(timestamp!),
                                          style: LabTextStyles.reg11
                                              .copyWith(color: c.white33),
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
                                      style: LabTextStyles.med17
                                          .copyWith(color: c.white),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Message body
                          if (message != null && message!.isNotEmpty)
                            DefaultTextStyle.merge(
                              style: LabTextStyles.reg15.copyWith(
                                color: c.white.withValues(alpha: 0.85),
                                height: 1.5,
                              ),
                              child: Text(message!),
                            ),
                        ],
                      ),
                    ),
                  ),
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
