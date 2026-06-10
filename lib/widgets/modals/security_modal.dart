import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SecurityModal — matches webapp's Security modal in +page.svelte
//
// Three items separated by white16 dividers:
//   1. Published by Developer / Published by Indexer (check or dash)
//      → publisher profile pic + name
//   2. Open Source / Closed Source (check or dash)
//      → repository link
//   3. Trusted Catalog (always check)
//      → catalog profile pic + name
// ─────────────────────────────────────────────────────────────────────────────

class SecurityModal {
  static Future<void> show(
    BuildContext context, {
    required bool publishedByDeveloper,
    required bool hasRepository,
    required App app,
    Profile? author,
    Profile? catalogProfile,
  }) {
    return showModal<void>(
      context,
      title: 'Security',
      description: 'More security metrics coming soon.',
      maxHeightFactor: 0.72,
      builder: (ctx) => _SecurityModalContent(
        publishedByDeveloper: publishedByDeveloper,
        hasRepository: hasRepository,
        app: app,
        author: author,
        catalogProfile: catalogProfile,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SecurityModalContent extends StatelessWidget {
  const _SecurityModalContent({
    required this.publishedByDeveloper,
    required this.hasRepository,
    required this.app,
    this.author,
    this.catalogProfile,
  });

  final bool publishedByDeveloper;
  final bool hasRepository;
  final App app;
  final Profile? author;
  final Profile? catalogProfile;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    final publisherName = author?.name ?? _shortenPubkey(app.pubkey);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Divider(c),

        // 1 — Published by Developer / Indexer
        _SecurityItem(
          isCheck: publishedByDeveloper,
          title: publishedByDeveloper
              ? 'Published by Developer'
              : 'Published by Indexer',
          description: publishedByDeveloper
              ? 'This app is published directly by its developer, ensuring authenticity and direct updates from the source.'
              : "This app is published by a Zapstore indexer. While vetted, it's not directly from the developer.",
          footer: _ProfileRow(
            label: 'Profile',
            child: Row(
              children: [
                ProfilePic(
                  profile: author,
                  pubkey: app.pubkey,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    publisherName,
                    style: LabTextStyles.med13.copyWith(color: c.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        _Divider(c),

        // 2 — Open Source / Closed Source
        _SecurityItem(
          isCheck: hasRepository,
          title: hasRepository ? 'Open Source' : 'Closed Source',
          description: hasRepository
              ? 'The source code is publicly available for review, allowing community audits and transparency.'
              : 'The source code is not publicly available. Exercise caution and verify the publisher\'s reputation.',
          footer: _ProfileRow(
            label: 'Repository',
            child: hasRepository && app.repository != null
                ? GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse(app.repository!),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(
                      _stripUrl(app.repository!),
                      style: LabTextStyles.med13.copyWith(
                        color: c.blurpleLightColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Text(
                    '—',
                    style: LabTextStyles.med13.copyWith(color: c.white33),
                  ),
          ),
        ),

        _Divider(c),

        // 3 — Trusted Catalog (always a check)
        _SecurityItem(
          isCheck: true,
          title: 'Trusted Catalog',
          description:
              'This app is listed in the official Zapstore catalog, which is curated and maintained by the Zapstore team.',
          footer: _ProfileRow(
            label: 'Catalog',
            child: Row(
              children: [
                ProfilePic(
                  profile: catalogProfile,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    catalogProfile?.name ?? 'Zapstore',
                    style: LabTextStyles.med13.copyWith(color: c.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _shortenPubkey(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 6)}…${pubkey.substring(pubkey.length - 4)}';
  }

  static String _stripUrl(String url) =>
      url.replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/$'), '');
}

// ─────────────────────────────────────────────────────────────────────────────
// _SecurityItem — one row: [icon box] | [title + description + footer]
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityItem extends StatelessWidget {
  const _SecurityItem({
    required this.isCheck,
    required this.title,
    required this.description,
    required this.footer,
  });

  final bool isCheck;
  final String title;
  final String description;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon box: 36×36, white8 bg, r12
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.white8,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: isCheck
                  ? LabIcon(
                      LabIcons.check,
                      size: 15,
                      color: c.blurpleColor,
                      thick: true,
                    )
                  : Container(
                      width: 20,
                      height: 2.8,
                      decoration: BoxDecoration(
                        color: c.white33,
                        borderRadius: BorderRadius.circular(1.4),
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 14),

          // Body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: LabTextStyles.semibold18.copyWith(color: c.white),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: LabTextStyles.reg13.copyWith(
                    color: c.white66,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                footer,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProfileRow — "Label  [content]" row used at the foot of each security item
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Row(
      children: [
        Text(
          label,
          style: LabTextStyles.reg13.copyWith(color: c.white33),
        ),
        const SizedBox(width: 10),
        Flexible(child: child),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Divider — 1px white16 full-width separator
// ─────────────────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider(this.c);
  final LabColors c;

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: c.white16);
}
