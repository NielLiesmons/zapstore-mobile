import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/expandable_markdown.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReleasesModal — matches webapp's Releases modal in +page.svelte
//
// Layout:
//   Title / description (handled by showModal)
//   ── DETAILS section ─────────────────────────────────────────────────────
//   Repository row
//   Website row
//   App identifier row
//   Naddr row (copy button)
//   ── RELEASE NOTES section ───────────────────────────────────────────────
//   Per-release panels: version + date header / divider / collapsible notes
// ─────────────────────────────────────────────────────────────────────────────

class ReleasesModal {
  static Future<void> show(
    BuildContext context, {
    required App app,
  }) {
    return showModal<void>(
      context,
      title: 'Releases',
      description: 'Application details & Release Notes',
      fillHeight: true,
      maxHeightFactor: 0.80,
      builder: (ctx) => _ReleasesModalContent(app: app),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ReleasesModalContent extends HookConsumerWidget {
  const _ReleasesModalContent({required this.app});

  final App app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    final releasesState = ref.watch(
      query<Release>(
        tags: app.event.addressableIdTagMap,
        and: (release) => {release.latestMetadata.query()},
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: false),
        subscriptionPrefix: 'releases-modal-${app.identifier}',
      ),
    );

    final releases = switch (releasesState) {
      StorageData(:final models) => models.toList(),
      _ => <Release>[],
    };

    final naddr = app.event.shareableId;
    final naddrDisplay = _formatNaddr(naddr);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModalDivider(c),

        // ── DETAILS ────────────────────────────────────────────────────────
        _SectionHeading('DETAILS', c),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            children: [
              _DetailRow(
                label: 'Repository',
                child: app.repository != null
                    ? GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse(app.repository!),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(
                          _stripUrl(app.repository!),
                          style: LabTextStyles.reg13.copyWith(
                            color: c.blurpleLightColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : _MutedText('—', c),
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Website',
                child: app.url != null
                    ? GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse(app.url!),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(
                          _stripUrl(app.url!),
                          style: LabTextStyles.reg13.copyWith(
                            color: c.blurpleLightColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : _MutedText('—', c),
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Identifier',
                child: Text(
                  app.identifier,
                  style: LabTextStyles.reg13.copyWith(color: c.white66),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              _NaddrRow(naddr: naddr, naddrDisplay: naddrDisplay),
            ],
          ),
        ),

        _ModalDivider(c),

        // ── RELEASE NOTES ──────────────────────────────────────────────────
        _SectionHeading('RELEASE NOTES', c),

        if (releasesState is StorageLoading)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Loading releases…',
                style: LabTextStyles.reg13.copyWith(color: c.white33),
              ),
            ),
          )
        else if (releases.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              'No releases found.',
              style: LabTextStyles.reg13.copyWith(color: c.white33),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                for (final release in releases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReleasePanel(release: release),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static String _formatNaddr(String naddr) {
    if (naddr.length < 20) return naddr;
    if (!naddr.startsWith('naddr1')) {
      return '${naddr.substring(0, 10)}...${naddr.substring(naddr.length - 6)}';
    }
    return 'naddr1${naddr.substring(7, 11)}...${naddr.substring(naddr.length - 6)}';
  }

  static String _stripUrl(String url) =>
      url.replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/$'), '');
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReleasePanel — one release entry: version+date header, divider, notes
// ─────────────────────────────────────────────────────────────────────────────

class _ReleasePanel extends StatelessWidget {
  const _ReleasePanel({required this.release});

  final Release release;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final date = _formatDate(release.event.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: c.white4,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: version (left) + date (right)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      release.version,
                      style: LabTextStyles.semibold15.copyWith(color: c.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    date,
                    style: LabTextStyles.reg13.copyWith(color: c.white33),
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Container(height: 1, color: c.white16),

          // Release notes
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: release.releaseNotes != null &&
                    release.releaseNotes!.isNotEmpty
                ? ExpandableMarkdown(
                    data: release.releaseNotes!,
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      Theme.of(context),
                    ).copyWith(
                      p: LabTextStyles.reg13.copyWith(
                        color: c.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                : Text(
                    'No release notes.',
                    style: LabTextStyles.reg13.copyWith(color: c.white33),
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 365) {
      final years = diff.inDays ~/ 365;
      return '$years year${years != 1 ? 's' : ''} ago';
    } else if (diff.inDays > 30) {
      final months = diff.inDays ~/ 30;
      return '$months month${months != 1 ? 's' : ''} ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays != 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours != 1 ? 's' : ''} ago';
    }
    return 'just now';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NaddrRow — identifier row with inline copy-to-clipboard button
// ─────────────────────────────────────────────────────────────────────────────

class _NaddrRow extends HookWidget {
  const _NaddrRow({required this.naddr, required this.naddrDisplay});

  final String naddr;
  final String naddrDisplay;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final copied = useState(false);

    Future<void> handleCopy() async {
      await Clipboard.setData(ClipboardData(text: naddr));
      copied.value = true;
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      copied.value = false;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            'Naddr',
            style: LabTextStyles.reg13.copyWith(color: c.white66),
          ),
        ),
        Expanded(
          child: Text(
            naddrDisplay,
            style: LabTextStyles.reg13.copyWith(color: c.white66),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: handleCopy,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: copied.value
                  ? Icon(
                      Icons.check,
                      key: const ValueKey('check'),
                      size: 16,
                      color: c.blurpleLightColor,
                    )
                  : Icon(
                      Icons.copy_outlined,
                      key: const ValueKey('copy'),
                      size: 16,
                      color: c.white33,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label, this.c);
  final String label;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Text(
        label,
        style: LabTextStyles.eyebrow13.copyWith(color: c.white33),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: LabTextStyles.reg13.copyWith(color: c.white66),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text, this.c);
  final String text;
  final LabColors c;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: LabTextStyles.reg13.copyWith(color: c.white33),
      );
}

class _ModalDivider extends StatelessWidget {
  const _ModalDivider(this.c);
  final LabColors c;

  @override
  Widget build(BuildContext context) => Container(height: 1, color: c.white16);
}
