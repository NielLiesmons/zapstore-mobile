import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zapstore/models/forum_post.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/floating_overflow_menu.dart'
    show getAppShareUrl, getStackShareUrl;
import 'package:zapstore/widgets/modals/actions_modal.dart' show ActionsContentType;
import 'package:zapstore/widgets/social/details_tab.dart';

const _kSiteUrl = 'https://zapstore.dev';

/// Zapstore moderation pubkey — matches webapp `ReportModal.svelte`.
const _kZapstoreReportPubkey =
    '78ce6faa72264387284e647ba6938995735ec8c7d5c5a65737e55f2fe2202182';

/// Resolved target for Details / Share / Report sub-modals.
class ActionsTarget {
  const ActionsTarget({
    required this.contentType,
    this.eventId,
    this.authorPubkey,
    this.authorName,
    this.appName,
    this.event,
    this.repository,
    this.app,
    this.stack,
    this.forumPost,
  });

  final ActionsContentType contentType;
  final String? eventId;
  final String? authorPubkey;
  final String? authorName;
  final String? appName;
  final EventBase? event;
  final String? repository;
  final App? app;
  final AppStack? stack;
  final ForumPost? forumPost;

  factory ActionsTarget.fromModal({
    required ActionsContentType contentType,
    Comment? comment,
    Zap? zap,
    App? app,
    AppStack? stack,
    ForumPost? forumPost,
    String? authorName,
  }) {
    if (comment != null) {
      return ActionsTarget(
        contentType: ActionsContentType.comment,
        eventId: comment.event.id,
        authorPubkey: comment.event.pubkey,
        authorName: authorName,
        event: comment.event,
      );
    }
    if (zap != null) {
      return ActionsTarget(
        contentType: ActionsContentType.zap,
        eventId: zap.event.id,
        authorPubkey: zap.event.pubkey,
        authorName: authorName,
        event: zap.event,
      );
    }
    if (app != null) {
      return ActionsTarget(
        contentType: ActionsContentType.app,
        eventId: app.event.id,
        authorPubkey: app.pubkey,
        authorName: authorName,
        appName: app.name,
        event: app.event,
        repository: app.repository,
        app: app,
      );
    }
    if (stack != null) {
      return ActionsTarget(
        contentType: ActionsContentType.stack,
        eventId: stack.event.id,
        authorPubkey: stack.pubkey,
        authorName: authorName,
        event: stack.event,
        stack: stack,
      );
    }
    if (forumPost != null) {
      return ActionsTarget(
        contentType: ActionsContentType.forum,
        eventId: forumPost.event.id,
        authorPubkey: forumPost.pubkey,
        authorName: authorName,
        event: forumPost.event,
        forumPost: forumPost,
      );
    }

    return ActionsTarget(contentType: contentType, authorName: authorName);
  }

  String get publicationLabel => switch (contentType) {
        ActionsContentType.app => 'App',
        ActionsContentType.stack => 'Stack',
        ActionsContentType.forum => 'Post',
        ActionsContentType.zap => 'Tip receipt',
        _ => 'Comment',
      };

  String get reportContentType => switch (contentType) {
        ActionsContentType.app => 'app',
        ActionsContentType.stack => 'stack',
        ActionsContentType.forum => 'forum',
        ActionsContentType.zap => 'zap',
        _ => 'comment',
      };

  String get reportContentNoun => switch (contentType) {
        ActionsContentType.app => 'App',
        ActionsContentType.stack => 'Stack',
        ActionsContentType.forum => 'Post',
        ActionsContentType.zap => 'Tip',
        _ => 'Comment',
      };

  String get reportDescription {
    if (contentType == ActionsContentType.app) {
      final name = appName?.trim();
      if (name != null && name.isNotEmpty) {
        final author = authorName?.trim();
        if (author != null && author.isNotEmpty) {
          return '$name, published by $author';
        }
        return name;
      }
    }
    final author = authorName?.trim();
    if (author != null && author.isNotEmpty) {
      return "$author's $reportContentNoun";
    }
    return reportContentNoun;
  }

  String? get shareableNevent {
    final id = eventId;
    if (id == null || id.isEmpty) return null;
    try {
      return Utils.encodeShareableFromString(id, type: 'nevent');
    } catch (_) {
      return null;
    }
  }

  String? get shareEmbedLink {
    final nevent = shareableNevent;
    return nevent != null ? 'nostr:$nevent' : null;
  }

  String? get shareZapstoreUrl {
    if (contentType == ActionsContentType.app && app != null) {
      return getAppShareUrl(app!);
    }
    if (contentType == ActionsContentType.stack && stack != null) {
      return getStackShareUrl(stack!);
    }
    final nevent = shareableNevent;
    if (nevent != null) {
      return '$_kSiteUrl/community/forum/$nevent';
    }
    return null;
  }

  bool get canShare =>
      shareZapstoreUrl != null || shareEmbedLink != null;
}

Future<void> openActionsNestedModal(
  BuildContext context,
  Future<void> Function() open,
) async {
  ModalNestScope.setNested(context, isOpen: true);
  try {
    await open();
  } finally {
    if (context.mounted) {
      ModalNestScope.setNested(context, isOpen: false);
    }
  }
}

Future<void> openActionsDetailsModal(
  BuildContext context, {
  required ActionsTarget target,
}) {
  return showModal<void>(
    context,
    nestedModal: true,
    title: 'Details',
    builder: (ctx) => _ActionsDetailsBody(target: target),
  );
}

Future<void> openActionsShareModal(
  BuildContext context, {
  required ActionsTarget target,
}) {
  return showModal<void>(
    context,
    nestedModal: true,
    title: 'Share',
    builder: (ctx) => _ActionsShareBody(target: target),
  );
}

Future<void> openActionsReportModal(
  BuildContext context,
  WidgetRef ref, {
  required ActionsTarget target,
}) {
  return showModal<void>(
    context,
    nestedModal: true,
    title: 'Report',
    description: target.reportDescription,
    builder: (ctx) => _ActionsReportBody(target: target),
  );
}

Future<EventBase?> _loadEventById(WidgetRef ref, String eventId) async {
  final comment = await ref.storage.query(
    RequestFilter<Comment>(ids: {eventId}).toRequest(),
    source: const LocalSource(),
  );
  if (comment.isNotEmpty) return comment.first.event;

  final zap = await ref.storage.query(
    RequestFilter<Zap>(ids: {eventId}).toRequest(),
    source: const LocalSource(),
  );
  if (zap.isNotEmpty) return zap.first.event;

  final app = await ref.storage.query(
    RequestFilter<App>(ids: {eventId}).toRequest(),
    source: const LocalSource(),
  );
  if (app.isNotEmpty) return app.first.event;

  final stack = await ref.storage.query(
    RequestFilter<AppStack>(ids: {eventId}).toRequest(),
    source: const LocalSource(),
  );
  if (stack.isNotEmpty) return stack.first.event;

  final post = await ref.storage.query(
    RequestFilter<ForumPost>(ids: {eventId}).toRequest(),
    source: const LocalSource(),
  );
  if (post.isNotEmpty) return post.first.event;

  return null;
}

class _ActionsDetailsBody extends HookConsumerWidget {
  const _ActionsDetailsBody({required this.target});

  final ActionsTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final eventId = target.eventId;
    final loaded = useState<EventBase?>(target.event);
    final loading = useState(target.event == null && eventId != null);

    useEffect(() {
      if (target.event != null || eventId == null) return null;
      var cancelled = false;
      Future<void>(() async {
        try {
          final event = await _loadEventById(ref, eventId);
          if (!cancelled) loaded.value = event;
        } catch (_) {
          if (!cancelled) loaded.value = null;
        } finally {
          if (!cancelled) loading.value = false;
        }
      });
      return () => cancelled = true;
    }, [eventId]);

    final event = loaded.value ?? target.event;

    String? shareableId;
    String? pk = target.authorPubkey;
    if (event is ImmutableEvent) {
      shareableId = event.shareableId;
      pk ??= event.pubkey;
      if (shareableId.isEmpty) {
        try {
          shareableId =
              Utils.encodeShareableFromString(event.id, type: 'nevent');
        } catch (_) {}
      }
    }

    String? npub;
    if (pk != null && pk.isNotEmpty) {
      try {
        npub = Utils.encodeShareableFromString(pk, type: 'npub');
      } catch (_) {}
    }

    String? rawJson;
    if (event != null) {
      try {
        rawJson = const JsonEncoder.withIndent('  ').convert(event.toMap());
      } catch (_) {}
    }

    if (loading.value) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Loading…',
            style: LabTextStyles.reg15.copyWith(color: c.white33),
          ),
        ),
      );
    }

    if (event == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Could not load this event from your device.',
            style: LabTextStyles.reg15.copyWith(color: c.white33),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return DetailsTab(
      shareableId: shareableId,
      publicationLabel: target.publicationLabel,
      npub: npub,
      pubkey: pk,
      rawData: rawJson,
      repository: target.repository,
      panelBackground: PanelBg.black33,
    );
  }
}

class _ActionsShareBody extends HookWidget {
  const _ActionsShareBody({required this.target});

  final ActionsTarget target;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final embedLink = target.shareEmbedLink;
    final zapstoreUrl = target.shareZapstoreUrl;
    final linkCopied = useState(false);
    final urlCopied = useState(false);
    final feedback = useState<String?>(null);

    Future<void> copyEmbed() async {
      if (embedLink == null) return;
      feedback.value = null;
      await Clipboard.setData(ClipboardData(text: embedLink));
      linkCopied.value = true;
      feedback.value = 'Copied embed link';
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!context.mounted) return;
      linkCopied.value = false;
      feedback.value = null;
    }

    Future<void> copyUrl() async {
      if (zapstoreUrl == null) return;
      feedback.value = null;
      await Clipboard.setData(ClipboardData(text: zapstoreUrl));
      urlCopied.value = true;
      feedback.value = 'Copied zapstore.dev URL';
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!context.mounted) return;
      urlCopied.value = false;
      feedback.value = null;
    }

    if (!target.canShare) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Text(
          'No event id available',
          style: LabTextStyles.reg13.copyWith(color: c.white33),
          textAlign: TextAlign.center,
        ),
      );
    }

    final showEmbed = embedLink != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.black33,
              border: LabBorder.all(color: c.white33, width: LabStroke.thin),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                if (showEmbed) ...[
                  _ShareRow(
                    icon: LabIcons.details,
                    label: 'Embed link',
                    value: embedLink,
                    copied: linkCopied.value,
                    onCopy: copyEmbed,
                    onShare: () =>
                        SharePlus.instance.share(ShareParams(text: embedLink)),
                    c: c,
                  ),
                  if (zapstoreUrl != null)
                    Container(height: 1, color: c.white11),
                ],
                if (zapstoreUrl != null)
                  _ShareRow(
                    icon: LabIcons.share,
                    label: 'Zapstore URL',
                    value: zapstoreUrl.replaceFirst(RegExp(r'^https?://'), ''),
                    copied: urlCopied.value,
                    onCopy: copyUrl,
                    onShare: () => SharePlus.instance.share(
                      ShareParams(text: zapstoreUrl),
                    ),
                    c: c,
                  ),
              ],
            ),
          ),
          if (feedback.value != null) ...[
            const SizedBox(height: 8),
            Text(
              feedback.value!,
              style: LabTextStyles.reg13.copyWith(color: c.white33),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.copied,
    required this.onCopy,
    required this.onShare,
    required this.c,
  });

  final String icon;
  final String label;
  final String value;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Row(
              children: [
                LabIcon(icon, size: 18, color: c.white66),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: LabTextStyles.reg15.copyWith(color: c.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: onShare,
              child: Text(
                value,
                style: LabTextStyles.reg15.copyWith(color: c.white66),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onCopy,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.white8,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: copied
                    ? LabIcon(
                        LabIcons.check,
                        size: 14,
                        color: c.blurpleLightColor,
                      )
                    : LabIcon(LabIcons.copy, size: 16, color: c.white66),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _reportViolations = <String, List<({String id, String label})>>{
  'app': [
    (id: 'malware', label: 'Malware or security risk'),
    (id: 'spam', label: 'Spam'),
    (id: 'impersonation', label: 'Impersonation'),
    (id: 'illegal', label: 'Illegal content'),
    (id: 'other', label: 'Other'),
  ],
  'stack': [
    (id: 'spam', label: 'Spam'),
    (id: 'impersonation', label: 'Impersonation'),
    (id: 'illegal', label: 'Illegal content'),
    (id: 'other', label: 'Other'),
  ],
  'forum': [
    (id: 'nudity', label: 'Nudity or explicit content'),
    (id: 'profanity', label: 'Hateful speech or profanity'),
    (id: 'illegal', label: 'Illegal content'),
    (id: 'spam', label: 'Spam'),
    (id: 'other', label: 'Other'),
  ],
  'comment': [
    (id: 'nudity', label: 'Nudity or explicit content'),
    (id: 'profanity', label: 'Hateful speech or profanity'),
    (id: 'illegal', label: 'Illegal content'),
    (id: 'spam', label: 'Spam'),
    (id: 'other', label: 'Other'),
  ],
  'zap': [
    (id: 'spam', label: 'Spam'),
    (id: 'illegal', label: 'Illegal content'),
    (id: 'other', label: 'Other'),
  ],
};

class _ActionsReportBody extends HookConsumerWidget {
  const _ActionsReportBody({required this.target});

  final ActionsTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    final violations =
        _reportViolations[target.reportContentType] ?? _reportViolations['app']!;
    final selected = useState<Set<String>>({});
    final commentController = useTextEditingController();
    final submitting = useState(false);
    final submitted = useState(false);
    final error = useState<String?>(null);

    Future<void> submit() async {
      if (submitting.value || submitted.value) return;

      final text = commentController.text.trim();
      if (selected.value.isEmpty && text.isEmpty) return;

      final signer = ref.read(Signer.activeSignerProvider);
      if (signer == null) {
        error.value = 'Sign in to send a report.';
        return;
      }

      final eventId = target.eventId;
      final authorPubkey = target.authorPubkey;
      if (eventId == null || eventId.isEmpty) {
        error.value = 'No event id available.';
        return;
      }

      submitting.value = true;
      error.value = null;

      try {
        final selectedList = selected.value.toList();
        final primaryType = selectedList.isNotEmpty ? selectedList.first : 'other';
        final partial = PartialReport();

        if (authorPubkey != null && authorPubkey.isNotEmpty) {
          partial.event.addTag('p', [authorPubkey, primaryType]);
        }

        for (final violation in selectedList.isEmpty ? [primaryType] : selectedList) {
          partial.event.addTag('e', [eventId, violation]);
        }

        if (_kZapstoreReportPubkey != authorPubkey) {
          partial.event.addTag('p', [_kZapstoreReportPubkey]);
        }

        final contentLines = <String>[];
        if (selectedList.length > 1) {
          contentLines.add('Violations: ${selectedList.join(', ')}');
        }
        if (text.isNotEmpty) contentLines.add(text);
        partial.reason = contentLines.join('\n');

        final signed = await partial.signWith(signer);
        await ref.storage.publish({signed}, relays: {kDefaultRelay});

        submitted.value = true;
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (context.mounted) Navigator.of(context).pop();
      } catch (e) {
        error.value = 'Failed to send report. Please try again.';
      } finally {
        submitting.value = false;
      }
    }

    if (submitted.value) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
        child: Text(
          'Report sent. Thank you.',
          style: LabTextStyles.reg15.copyWith(color: c.white66),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.black33,
              border: LabBorder.all(color: c.white33, width: LabStroke.thin),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < violations.length; i++) ...[
                  if (i > 0) Container(height: 1, color: c.white8),
                  _ViolationRow(
                    label: violations[i].label,
                    selected: selected.value.contains(violations[i].id),
                    onTap: () {
                      final next = Set<String>.from(selected.value);
                      if (next.contains(violations[i].id)) {
                        next.remove(violations[i].id);
                      } else {
                        next.add(violations[i].id);
                      }
                      selected.value = next;
                    },
                    c: c,
                  ),
                ],
                Container(height: 1, color: c.white8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: TextField(
                    controller: commentController,
                    style: LabTextStyles.reg15.copyWith(color: c.white),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Add a comment (optional)',
                      hintStyle: LabTextStyles.reg15.copyWith(color: c.white33),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
              ],
            ),
          ),
          if (error.value != null) ...[
            const SizedBox(height: 8),
            Text(
              error.value!,
              style: LabTextStyles.reg13.copyWith(color: c.rougeColor),
            ),
          ],
          const SizedBox(height: 12),
          LabButton.primary(
            text: submitting.value ? 'Sending…' : 'Send report',
            onTap: submitting.value ? null : submit,
          ),
        ],
      ),
    );
  }
}

class _ViolationRow extends StatelessWidget {
  const _ViolationRow({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.c,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final LabColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: LabTextStyles.reg15.copyWith(color: c.white),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? c.blurpleColor : c.white8,
                borderRadius: BorderRadius.circular(6),
                border: selected
                    ? null
                    : LabBorder.all(color: c.white16, width: 1.4),
              ),
              child: selected
                  ? Center(
                      child: LabIcon(
                        LabIcons.check,
                        size: 12,
                        color: c.whiteEnforced,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
