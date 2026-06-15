import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/widgets/common/empty_state.dart';
import 'package:zapstore/widgets/common/shimmer.dart';
import 'package:zapstore/widgets/social/zap_bubble.dart';

/// Zap list for a given Nostr entity — matches webapp's ZapBubble / BubbleSkeleton
/// pattern used in the Zaps tab of SocialTabs.
///
/// Pass [tags] matching the Nostr event:
///   • Addressable (app, stack):  `{'#a': {model.id}}`
///   • Regular event (forum post): `{'#e': {event.id}}`
/// [subscriptionId] should uniquely identify the subscription prefix.
class ZapsSection extends ConsumerWidget {
  const ZapsSection({
    super.key,
    required this.tags,
    required this.subscriptionId,
  });

  final Map<String, Set<String>> tags;
  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zapsState = ref.watch(
      query<Zap>(
        tags: tags,
        source: const LocalAndRemoteSource(
          relays: 'AppCatalog',
          stream: true,
        ),
        subscriptionPrefix: 'zaps-$subscriptionId',
      ),
    );

    final zaps = switch (zapsState) {
      StorageData(:final models) =>
        (models.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt))),
      _ => <Zap>[],
    };

    if (zapsState is StorageLoading && zaps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: BubbleSkeletonList(),
      );
    }

    if (zaps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
        child: EmptyState(message: 'No tips yet', minHeight: 160),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < zaps.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _ZapItem(zap: zaps[i]),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Fetches the sender profile for a single [Zap] and renders a [ZapBubble].
class _ZapItem extends ConsumerWidget {
  const _ZapItem({required this.zap});

  final Zap zap;

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
              subscriptionPrefix: 'zap-sender-$senderPubkey',
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
    );
  }
}
