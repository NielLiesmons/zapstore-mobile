import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/widgets/social/zap_bubble.dart';

/// Fetches the sender [Profile] for a [Zap] that carries a comment and renders
/// a [ZapBubble].  Used in both the app/stack comments feed and the forum post
/// comments feed.
class ZapCommentItem extends ConsumerWidget {
  const ZapCommentItem({super.key, required this.zap, this.topPadding = 4});

  final Zap zap;
  final double topPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // NIP-57: 'P' tag = original sender pubkey; fallback to processMetadata author.
    final senderPubkey = zap.event.getFirstTagValue('P') ??
        (zap.event.metadata['author'] as String?);

    final profileState = senderPubkey != null
        ? ref.watch(
            query<Profile>(
              authors: {senderPubkey},
              source: const LocalAndRemoteSource(
                relays: {'social', 'vertex'},
                stream: false,
                cachedFor: Duration(hours: 2),
              ),
              subscriptionPrefix: 'zap-comment-sender-$senderPubkey',
            ),
          )
        : null;

    final profile = profileState?.models.firstOrNull;
    final name = profile?.name?.trim().isNotEmpty == true
        ? profile!.name!
        : (senderPubkey != null
            ? Utils.encodeShareableFromString(
                senderPubkey,
                type: 'npub',
              ).abbreviateNpub()
            : 'Unknown');

    return ZapBubble(
      name: name,
      amount: zap.amount,
      profile: profile,
      pubkey: senderPubkey,
      message: zap.event.content.isEmpty ? null : zap.event.content,
      timestamp: zap.createdAt,
      topPadding: topPadding,
    );
  }
}
