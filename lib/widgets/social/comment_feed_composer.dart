import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';

/// Profile pic + bubble comment trigger above the comments feed — port of
/// webapp `CommentFeedComposer.svelte`.
class CommentFeedComposer extends ConsumerWidget {
  const CommentFeedComposer({
    super.key,
    this.ctaLabel = 'Your Comment',
    this.onTap,
  });

  final String ctaLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final pubkey = ref.watch(Signer.activePubkeyProvider);
    if (pubkey == null) return const SizedBox.shrink();

    final profile = ref.watch(
      query<Profile>(
        authors: {pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          stream: false,
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'feed-composer-profile-$pubkey',
      ),
    ).models.firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 21, 14),
      child: Row(
        children: [
          ProfilePic(profile: profile, pubkey: pubkey, size: 35),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 35,
                padding: const EdgeInsets.fromLTRB(12, 0, 13, 0),
                decoration: BoxDecoration(
                  color: c.gray33,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                  ),
                  border: LabBorder.all(color: c.white16, width: LabStroke.thin),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  ctaLabel,
                  style: LabTextStyles.reg15.copyWith(color: c.white33),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
