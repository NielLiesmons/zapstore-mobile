import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/utils/url_utils.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/app_pic.dart';

class NoteParser {
  static final RegExp nip19Regex = RegExp(
    r'(?:nostr:)?(npub|nsec|note|nprofile|nevent|naddr|nrelay)1[02-9ac-hj-np-z]+',
    caseSensitive: false,
  );

  static final RegExp httpUrlPattern = RegExp(
    r'https?://[^\s<>"\[\]{}|\\^`]+',
    caseSensitive: false,
  );

  static final RegExp _hashtagPattern = RegExp(
    r'#[a-zA-Z0-9_]+',
    caseSensitive: false,
  );

  /// Matches :shortcode: custom emoji markers (1–100 non-space chars between colons).
  /// Mirrors the EMOJI_REGEX in webapp/src/lib/utils/short-text-parser.js.
  static final RegExp _emojiPattern = RegExp(
    r':([^:\s]{1,100}):',
    caseSensitive: false,
  );

  /// Extracts a `{shortcode → url}` map from a Nostr event's raw tag list.
  ///
  /// Custom emoji tags have the form `["emoji", "shortcode", "https://..."]`.
  /// Matches webapp's `emojiMap()` helper in short-text-parser.js.
  static Map<String, String> extractEmojiTags(List<List<String>> eventTags) {
    final map = <String, String>{};
    for (final tag in eventTags) {
      if (tag.length >= 3 && tag[0] == 'emoji') {
        final key = tag[1].toLowerCase();
        map.putIfAbsent(key, () => tag[2]);
      }
    }
    return map;
  }

  /// Returns true for URLs that are likely direct image embeds.
  /// Mirrors webapp's `isLikelyDirectMediaUrl` (image branch).
  static bool _isImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      if (RegExp(r'\.(jpg|jpeg|png|gif|webp|avif|bmp|ico)$').hasMatch(path)) {
        return true;
      }
      final host = uri.host.toLowerCase();
      return host == 'nostr.build' ||
          host.endsWith('.nostr.build') ||
          host == 'image.nostr.build' ||
          host == 'void.cat';
    } catch (_) {
      return false;
    }
  }

  /// Returns true for URLs that are likely direct video files.
  static bool _isVideoUrl(String url) {
    try {
      return RegExp(r'\.(mp4|webm|ogg|mov)$')
          .hasMatch(Uri.parse(url).path.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  /// Returns true when content contains only 1–2 known custom emoji and nothing else.
  /// Mirrors webapp's `isShortTextOnlyOneOrTwoEmojis` (custom emoji path only).
  static bool _isFewCustomEmojis(
      String content, Map<String, String>? emojiTags) {
    if (emojiTags == null || emojiTags.isEmpty) return false;
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    int count = 0;
    final remaining = trimmed.replaceAllMapped(_emojiPattern, (m) {
      final sc = m.group(1)!.toLowerCase();
      if (emojiTags.containsKey(sc)) {
        count++;
        return '';
      }
      return m.group(0)!;
    });
    return remaining.trim().isEmpty && count >= 1 && count <= 2;
  }

  /// Strips the protocol prefix (https://) and trailing slashes for display.
  /// Mirrors webapp's `stripUrlForDisplay` in url.js.
  static String _stripUrlForDisplay(String url) {
    return url
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/+$'), '');
  }

  /// Derives a legible mention color from a pubkey hex string.
  /// Uses the first 3 bytes as an RGB seed, then clamps lightness to 65–85%
  /// so the color reads clearly on dark backgrounds.
  /// Mirrors webapp's `hexToColor` + `getProfileTextColor` pipeline.
  static Color _pubkeyToMentionColor(String pubkey) {
    if (pubkey.length < 6) return const Color(0xFF818CF8);
    final r = int.parse(pubkey.substring(0, 2), radix: 16);
    final g = int.parse(pubkey.substring(2, 4), radix: 16);
    final b = int.parse(pubkey.substring(4, 6), radix: 16);
    final base = Color.fromARGB(255, r, g, b);
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness(hsl.lightness.clamp(0.65, 0.85)).toColor();
  }

  static Widget parse(
    BuildContext context,
    String content, {
    /// Shortcode → URL map from the event's emoji tags (NIP-30).
    /// Build with [extractEmojiTags] from the raw event tag list.
    Map<String, String>? emojiTags,
    Widget? Function(String entity)? onNostrEntity,
    Widget? Function(String httpUrl)? onHttpUrl,
    Widget? Function(String hashtag)? onHashtag,
    void Function(String hashtag)? onHashtagTap,
    TextStyle? textStyle,
    TextStyle? linkStyle,
  }) {
    if (content.isEmpty) {
      return Text('', style: textStyle);
    }

    // Detect 1–2 custom emoji magnification (matches webapp's --few-emoji class).
    final magnify = _isFewCustomEmojis(content, emojiTags);
    final emojiSize = magnify ? 40.0 : 19.0;

    final List<_EntityMatch> matches = [];

    for (final match in nip19Regex.allMatches(content)) {
      final entity = match.group(0)!;
      final nip19Entity = entity.replaceFirst('nostr:', '');
      matches.add(_EntityMatch(
        start: match.start,
        end: match.end,
        text: entity,
        type: _EntityType.nip19,
        cleanEntity: nip19Entity,
      ));
    }

    for (final match in httpUrlPattern.allMatches(content)) {
      final url = match.group(0)!;
      matches.add(_EntityMatch(
        start: match.start,
        end: match.end,
        text: url,
        type: _EntityType.http,
        cleanEntity: url,
      ));
    }

    for (final match in _hashtagPattern.allMatches(content)) {
      final hashtag = match.group(0)!;
      matches.add(_EntityMatch(
        start: match.start,
        end: match.end,
        text: hashtag,
        type: _EntityType.hashtag,
        cleanEntity: hashtag.substring(1),
      ));
    }

    if (emojiTags != null && emojiTags.isNotEmpty) {
      for (final match in _emojiPattern.allMatches(content)) {
        final shortcode = match.group(1)!.toLowerCase();
        final url = emojiTags[shortcode];
        if (url != null) {
          matches.add(_EntityMatch(
            start: match.start,
            end: match.end,
            text: match.group(0)!,
            type: _EntityType.emoji,
            cleanEntity: shortcode,
            url: url,
          ));
        }
      }
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    final filtered = <_EntityMatch>[];
    var lastEnd = -1;
    for (final m in matches) {
      if (m.start >= lastEnd) {
        filtered.add(m);
        lastEnd = m.end;
      }
    }

    // ── Mixed layout ──────────────────────────────────────────────────────────
    // nostr refs (nevent/naddr/note) render as full-width block cards (Column
    // children), matching webapp's block-level <NostrRefCard> placement.
    // Profile mentions and all other entities stay inline (WidgetSpan inside
    // Text.rich). Consecutive inline spans are grouped into one Text.rich.

    final parts = <Widget>[];
    var spans = <InlineSpan>[];
    int pos = 0;

    final blurpleLink = linkStyle ??
        textStyle?.copyWith(
          color: Theme.of(context).extension<LabColors>()!.blurpleLightColor,
        );
    final defaultColors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.primaryContainer,
    ];

    void flushSpans() {
      if (spans.isEmpty) return;
      parts.add(Text.rich(TextSpan(children: List.from(spans))));
      spans = [];
    }

    for (final m in filtered) {
      if (m.start > pos) {
        spans.add(TextSpan(
          text: content.substring(pos, m.start),
          style: textStyle,
        ));
      }

      switch (m.type) {
        case _EntityType.nip19:
          final customWidget = onNostrEntity?.call(m.cleanEntity);
          if (customWidget != null) {
            spans.add(WidgetSpan(
              child: customWidget,
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
            ));
          } else {
            try {
              final decoded = Utils.decodeShareableIdentifier(m.cleanEntity);
              if (decoded is ProfileData) {
                // Inline @mention chip
                spans.add(WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: ProfileEntityWidget(
                    profileData: decoded,
                    colorPair: defaultColors,
                  ),
                ));
              } else if (decoded is EventData) {
                // Block reference card
                flushSpans();
                parts.add(EventEntityWidget(
                  eventData: decoded,
                  colorPair: defaultColors,
                ));
              } else if (decoded is AddressData) {
                // Block reference card (app / stack)
                flushSpans();
                parts.add(AddressEntityWidget(
                  addressData: decoded,
                  colorPair: defaultColors,
                ));
              }
            } catch (_) {
              spans.add(TextSpan(text: m.text, style: blurpleLink));
            }
          }

        case _EntityType.http:
          final customWidget = onHttpUrl?.call(m.text);
          if (customWidget != null) {
            spans.add(WidgetSpan(
              child: customWidget,
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
            ));
          } else if (_isImageUrl(m.text)) {
            // Block image embed — matches webapp's MediaBlock / inline image display
            flushSpans();
            parts.add(_MediaImageBlock(url: m.text));
          } else if (_isVideoUrl(m.text)) {
            // Block video chip (no inline player; tap opens URL)
            flushSpans();
            parts.add(_VideoChip(url: m.text));
          } else {
            spans.add(TextSpan(
              // Display without protocol prefix (matches webapp's stripUrlForDisplay)
              text: _stripUrlForDisplay(m.text),
              style: blurpleLink,
              recognizer: TapGestureRecognizer()
                ..onTap = () => navigateToContent(context, m.text),
            ));
          }

        case _EntityType.hashtag:
          final customWidget = onHashtag?.call(m.cleanEntity);
          if (customWidget != null) {
            spans.add(WidgetSpan(
              child: customWidget,
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
            ));
          } else {
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: HashtagWidget(
                hashtag: m.cleanEntity,
                onTap: onHashtagTap != null
                    ? () => onHashtagTap(m.cleanEntity)
                    : null,
              ),
            ));
          }

        case _EntityType.emoji:
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Image.network(
                m.url!,
                width: emojiSize,
                height: emojiSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Text(':${m.cleanEntity}:', style: textStyle),
              ),
            ),
          ));
      }

      pos = m.end;
    }

    if (pos < content.length) {
      spans.add(TextSpan(text: content.substring(pos), style: textStyle));
    }
    flushSpans();

    Widget result;
    if (parts.isEmpty) {
      result = Text(content, style: textStyle);
    } else if (parts.length == 1) {
      result = parts.first;
    } else {
      result = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: parts,
      );
    }

    // Big emoji: wrap in 2.5× font size (matches webapp's --few-emoji modifier)
    if (magnify) {
      return DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 40, height: 1.2),
        child: result,
      );
    }
    return result;
  }
}

class _EntityMatch {
  final int start;
  final int end;
  final String text;
  final _EntityType type;
  final String cleanEntity;

  /// URL for [_EntityType.emoji] matches.
  final String? url;

  _EntityMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.type,
    required this.cleanEntity,
    this.url,
  });
}

enum _EntityType { nip19, http, hashtag, emoji }

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Dispatches a raw nip19 entity string to the correct widget variant.
/// Used by callers that pass a custom `onNostrEntity` handler (currently none).
class NostrEntityWidget extends StatelessWidget {
  final String entity;
  final List<Color> colorPair;

  const NostrEntityWidget({
    super.key,
    required this.entity,
    required this.colorPair,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final decoded = Utils.decodeShareableIdentifier(entity);

      return switch (decoded) {
        ProfileData() => ProfileEntityWidget(
            profileData: decoded,
            colorPair: colorPair,
          ),
        EventData() => EventEntityWidget(
            eventData: decoded,
            colorPair: colorPair,
          ),
        AddressData() => AddressEntityWidget(
            addressData: decoded,
            colorPair: colorPair,
          ),
      };
    } catch (e) {
      return GenericNip19Widget(entity: entity, colorPair: colorPair);
    }
  }
}

// ── Profile mention ───────────────────────────────────────────────────────────

/// Inline @mention chip. Loads the author name and colors it from the pubkey.
/// Matches webapp's colored mention style (hexToColor + getProfileTextColor).
class ProfileEntityWidget extends ConsumerWidget {
  final ProfileData profileData;
  final List<Color> colorPair;

  const ProfileEntityWidget({
    super.key,
    required this.profileData,
    required this.colorPair,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Color derived from pubkey — matches webapp's per-user tint.
    final mentionColor = NoteParser._pubkeyToMentionColor(profileData.pubkey);

    final profileState = ref.watch(
      query<Profile>(
        authors: {profileData.pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'app-note-profile',
      ),
    );

    void handleTap() => pushUser(context, profileData.pubkey);

    final displayText = switch (profileState) {
      StorageData(:final models) when models.isNotEmpty =>
        '@${models.first.nameOrNpub}',
      _ => '@npub1${profileData.pubkey.substring(0, 8)}…',
    };

    final isLoading = profileState is StorageLoading;

    return GestureDetector(
      onTap: handleTap,
      child: isLoading
          ? _AnimatedLoadingChip(
              text: displayText,
              color: mentionColor,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: mentionColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  displayText,
                  style: context.textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: mentionColor,
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Event reference card (nevent / note) ─────────────────────────────────────

/// Block-level card for a referenced Nostr event (nevent/note).
/// Matches webapp's NostrRefCard forum/comment card style:
/// white8 background, 12px radius, author row + content preview.
class EventEntityWidget extends StatelessWidget {
  final EventData eventData;
  final List<Color> colorPair;

  const EventEntityWidget({
    super.key,
    required this.eventData,
    required this.colorPair,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final shortId = eventData.eventId.length >= 8
        ? '${eventData.eventId.substring(0, 8)}…'
        : eventData.eventId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: c.white8,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LabIcon(LabIcons.nostr, size: 13, color: c.white33),
          const SizedBox(width: 6),
          Text(
            'Nostr note · $shortId',
            style: LabTextStyles.reg13.copyWith(color: c.white33),
          ),
        ],
      ),
    );
  }
}

// ── Address reference card (naddr) ────────────────────────────────────────────

/// Block-level card for a referenced Nostr address (naddr).
/// For apps (kind 32267): fetches the App and shows icon + name.
/// For stacks or others: tappable chip matching the existing style.
class AddressEntityWidget extends ConsumerWidget {
  final AddressData addressData;
  final List<Color> colorPair;

  const AddressEntityWidget({
    super.key,
    required this.addressData,
    required this.colorPair,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    if (addressData.kind == 32267) {
      final appState = ref.watch(
        query<App>(
          tags: {'#d': {addressData.identifier}},
          authors: addressData.author != null ? {addressData.author!} : {},
          source: const LocalAndRemoteSource(relays: 'AppCatalog'),
          subscriptionPrefix: 'ref-app-${addressData.identifier}',
        ),
      );
      final app = appState.models.firstOrNull;

      return GestureDetector(
        onTap: () => pushApp(context, addressData.identifier),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          decoration: BoxDecoration(
            color: c.white8,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppPic(
                iconUrl:
                    app != null ? firstValidHttpUrl(app.icons) : null,
                name: app?.name,
                identifier: app?.identifier ?? addressData.identifier,
                size: 36,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  app?.name ?? addressData.identifier,
                  style: LabTextStyles.med15.copyWith(color: c.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Stack or other addressable kind — tappable text chip
    return GestureDetector(
      onTap: () {
        if (addressData.kind == 30267) {
          pushStack(context, addressData.identifier);
        } else {
          pushApp(context, addressData.identifier);
        }
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorPair[0].withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            addressData.identifier,
            style: context.textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w500,
              color: colorPair[0],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Generic fallback ──────────────────────────────────────────────────────────

class GenericNip19Widget extends StatelessWidget {
  final String entity;
  final List<Color> colorPair;

  const GenericNip19Widget({
    super.key,
    required this.entity,
    required this.colorPair,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorPair[0].withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          entity,
          style: context.textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w500,
            color: colorPair[0],
          ),
        ),
      ),
    );
  }
}

// ── Hashtag ───────────────────────────────────────────────────────────────────

/// Inline hashtag pill using blurple color — matches webapp's tag style.
class HashtagWidget extends StatelessWidget {
  final String hashtag;
  final VoidCallback? onTap;

  const HashtagWidget({
    super.key,
    required this.hashtag,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.blurpleColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
        child: Text(
          '#$hashtag',
          style: context.textTheme.bodyMedium!.copyWith(
            color: c.blurpleLightColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Loading chip ──────────────────────────────────────────────────────────────

class _AnimatedLoadingChip extends StatefulWidget {
  final String text;
  final Color color;

  const _AnimatedLoadingChip({required this.text, required this.color});

  @override
  State<_AnimatedLoadingChip> createState() => _AnimatedLoadingChipState();
}

class _AnimatedLoadingChipState extends State<_AnimatedLoadingChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.08, end: 0.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              widget.text,
              style: context.textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w500,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Media blocks ──────────────────────────────────────────────────────────────

/// Full-width inline image block rendered when a URL points to a direct image.
/// Matches webapp's MediaBlock / inline image embed behavior.
class _MediaImageBlock extends StatelessWidget {
  const _MediaImageBlock({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return GestureDetector(
      onTap: () => navigateToContent(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        // Fixed width so IntrinsicWidth in MessageBubble gets a finite value.
        // BoxFit.cover crops the image to fill the 240×180 frame.
        child: SizedBox(
          width: 240,
          height: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return ColoredBox(
                  color: c.white8,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      color: c.white33,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: c.white8,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LabIcon(LabIcons.camera, size: 14, color: c.white33),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          NoteParser._stripUrlForDisplay(url),
                          style: LabTextStyles.reg13.copyWith(color: c.white33),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable chip for video URLs — no inline player, tap opens URL.
class _VideoChip extends StatelessWidget {
  const _VideoChip({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return GestureDetector(
      onTap: () => navigateToContent(context, url),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: BoxDecoration(
          color: c.white8,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LabIcon(LabIcons.play, size: 15, color: c.white66),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                NoteParser._stripUrlForDisplay(url),
                style: LabTextStyles.reg13.copyWith(color: c.white66),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
