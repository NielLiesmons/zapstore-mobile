import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'emoji_picker_modal.dart';
import 'nostr_text_controller.dart';
import 'suggestion_panel.dart';

// ── Size enum ─────────────────────────────────────────────────────────────────

/// Matches webapp's `sizeMap`: small / medium / large.
enum ComposerSize {
  small(minHeight: 40, maxHeight: 120, minLines: 1, maxLines: 4),
  medium(minHeight: 80, maxHeight: 200, minLines: 3, maxLines: 8),
  large(minHeight: 160, maxHeight: 400, minLines: 5, maxLines: null);

  const ComposerSize({
    required this.minHeight,
    required this.maxHeight,
    required this.minLines,
    required this.maxLines,
  });

  final double minHeight;
  final double maxHeight;
  final int minLines;
  final int? maxLines;
}

// ── Main widget ───────────────────────────────────────────────────────────────

/// Flutter port of webapp's `ShortTextInput.svelte`.
///
/// Renders an editor area + optional action row (camera / emoji / plus / send)
/// ALL inside a single black33 `border-radius: 16` container — exactly matching
/// the `.input-container` + `ShortTextInput` structure used in
/// `CommentModal.svelte` and `ZapSlider.svelte`.
///
/// The suggestion panel (@ / :) slides in *above* the container so it stays
/// visible above the keyboard without changing the container's own layout.
class NostrComposer extends HookConsumerWidget {
  const NostrComposer({
    super.key,
    this.placeholder = 'Write something…',
    this.size = ComposerSize.small,
    this.showActionRow = true,
    this.autofocus = false,
    this.allowEmptySubmit = false,
    this.hideTipButton = false,
    this.nested = false,
    this.quotedContent,
    this.onSubmit,
    this.onCameraTap,
    this.onAddTap,
    this.onTipTap,
    this.onClose,
    this.controller,
  });

  final String placeholder;
  final ComposerSize size;
  final bool showActionRow;
  final bool autofocus;
  final bool allowEmptySubmit;
  final bool hideTipButton;

  /// When true, removes the composer's own black33 background and border so
  /// it can sit flush inside a parent container that already provides styling
  /// (e.g. the zap slider's .input-container).
  final bool nested;

  /// Optional widget rendered above the text field (e.g. quoted post preview).
  final Widget? quotedContent;

  /// Called with serialized content on send.
  final void Function(ComposerResult result)? onSubmit;

  /// Fired when the camera button is tapped (caller handles media picking).
  final VoidCallback? onCameraTap;

  /// Fired when the + button is tapped.
  final VoidCallback? onAddTap;

  /// Fired when the tip (zap) button is tapped — opens tip amount picker.
  final VoidCallback? onTipTap;

  /// When non-null, a × close button appears inside the field.
  final VoidCallback? onClose;

  /// Provide an external controller to read / clear content from outside.
  /// If null, an internal controller is created and managed.
  final NostrTextEditingController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    final internalCtrl = useMemoized(() => NostrTextEditingController());
    final ctrl = controller ?? internalCtrl;
    // Only auto-dispose the controller we created internally — never touch an
    // external controller (the caller owns it and will dispose it themselves).
    useEffect(() {
      if (controller != null) return null;
      return internalCtrl.dispose;
    }, const []);

    final focused = useState(false);
    final hasContent = useState(false);
    final activeTrigger = useState<String?>(null); // '@' | ':' | null
    final triggerQuery = useState('');

    // OverlayPortal for a floating suggestion panel that renders above
    // all widgets (including modals) — no clipping from parent containers.
    final layerLink = useMemoized(() => LayerLink());
    final overlayPortalCtrl = useMemoized(() => OverlayPortalController());

    // Show/hide the floating overlay based on whether a trigger is active.
    // Deferred to post-frame to avoid calling show()/hide() during build.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (activeTrigger.value != null) {
          if (!overlayPortalCtrl.isShowing) overlayPortalCtrl.show();
        } else {
          if (overlayPortalCtrl.isShowing) overlayPortalCtrl.hide();
        }
      });
      return null;
    }, [activeTrigger.value]);

    useEffect(() {
      void listener() => hasContent.value = ctrl.hasContent;
      ctrl.addListener(listener);
      return () => ctrl.removeListener(listener);
    }, [ctrl]);

    // Trigger detection — mirrors webapp's createProfileSuggestion /
    // createEmojiExtension logic.
    useEffect(() {
      void onTextChanged() {
        final text = ctrl.text;
        final cursor =
            ctrl.selection.isValid ? ctrl.selection.extentOffset : text.length;
        if (cursor <= 0) {
          activeTrigger.value = null;
          return;
        }
        final before = text.substring(0, cursor);
        final match = RegExp(r'([@:])(\S*)$').firstMatch(before);
        if (match != null) {
          activeTrigger.value = match.group(1);
          triggerQuery.value = match.group(2) ?? '';
        } else {
          activeTrigger.value = null;
          triggerQuery.value = '';
        }
      }

      ctrl.addListener(onTextChanged);
      return () => ctrl.removeListener(onTextChanged);
    }, [ctrl]);

    void handleSubmit() {
      if (!allowEmptySubmit && !ctrl.hasContent) return;
      onSubmit?.call(ctrl.serialize());
    }

    // ── .input-container (black33, r16, animated border) ────────────────────
    // Structure mirrors CommentModal.svelte / ZapSlider.svelte:
    //   .editor-wrapper   → text field
    //   .action-row       → camera / emoji / plus / send  (INSIDE container)
    final composerContainer = Focus(
      onFocusChange: (hasFocus) => focused.value = hasFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: nested
            ? const BoxDecoration()
            : BoxDecoration(
                color: c.black33,
                borderRadius: BorderRadius.circular(16),
                border: LabBorder.all(
                  color: focused.value ? c.white33 : c.white16,
                  width: LabStroke.thin,
                ),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Optional quoted content
            if (quotedContent != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: quotedContent!,
              ),

            // Text field area (scrollable, constrained by size)
            Stack(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: size.minHeight,
                    maxHeight: size.maxHeight,
                  ),
                  child: SingleChildScrollView(
                    // Avoid primary-controller conflicts when the composer sits
                    // inside another vertical scrollable (e.g. comment modal).
                    primary: false,
                    child: TextField(
                      controller: ctrl,
                      autofocus: autofocus,
                      minLines: size.minLines,
                      maxLines: size.maxLines,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: LabTextStyles.reg15.copyWith(color: c.white),
                      cursorColor: c.white,
                      cursorWidth: 1.6,
                      decoration: InputDecoration(
                        hintText: placeholder,
                        hintStyle:
                            LabTextStyles.reg15.copyWith(color: c.white33),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.fromLTRB(
                          12,
                          10,
                          onClose != null ? 36 : 8,
                          10,
                        ),
                        isDense: true,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                ),

                // × close button (top-right, matching .inline-close-btn)
                if (onClose != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: c.white4,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child:
                            LabIcon(LabIcons.cross, size: 10, color: c.white33),
                      ),
                    ),
                  ),
              ],
            ),

            // Action row — INSIDE the container, matching
            // .action-row { padding: 0 12px 12px 12px } in ShortTextInput.svelte
            if (showActionRow)
              _ActionRow(
                hasContent: hasContent.value,
                allowEmptySubmit: allowEmptySubmit,
                hideTipButton: hideTipButton,
                onCameraTap: onCameraTap,
                onTipTap: onTipTap,
                onEmojiTap: () async {
                  final result = await showEmojiPicker(context);
                  if (result == null) return;
                  if (result.source == EmojiSource.unicode) {
                    ctrl.insertUnicodeEmoji(result.display);
                  } else {
                    ctrl.insertCustomEmoji(
                        shortcode: result.shortcode, url: result.display);
                  }
                },
                onAddTap: onAddTap,
                onSubmit: handleSubmit,
                colors: c,
              ),
          ],
        ),
      ),
    );

    // ── OverlayPortal wraps the entire composer ───────────────────────────────
    // CompositedTransformFollower gives its child BoxConstraints() — completely
    // unconstrained. maxHeight/ConstrainedBox/ClipRect all fail to cap the gray
    // panel because they need a finite parent constraint to work.
    //
    // Fix: give CTF a TIGHT SizedBox(w, h:280). Tight constraints always
    // propagate correctly regardless of how CTF constructs the compositing layer.
    // Align(bottomLeft) inside the 280px box lets the panel grow to its natural
    // height and sit flush at the bottom of the transparent window.
    return OverlayPortal(
      controller: overlayPortalCtrl,
      overlayChildBuilder: (overlayCtx) {
        final panelWidth =
            (MediaQuery.sizeOf(context).width - 100).clamp(200.0, 260.0);
        return CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -4),
          // Tight SizedBox: CTF child constraints are always exact (never
          // unconstrained), so the gray Container can't expand to overlay bounds.
          child: SizedBox(
            width: panelWidth,
            height: 280,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: SuggestionPanel(
                trigger: activeTrigger.value ?? '',
                query: triggerQuery.value,
                onSelectMention: (pubkey, name) {
                  ctrl.insertMention(pubkey: pubkey, displayName: name);
                  activeTrigger.value = null;
                },
                onSelectEmoji: (entry) {
                  if (entry.source == EmojiSource.unicode) {
                    ctrl.insertUnicodeEmoji(entry.display);
                  } else {
                    ctrl.insertCustomEmoji(
                        shortcode: entry.shortcode, url: entry.display);
                  }
                  activeTrigger.value = null;
                },
              ),
            ),
          ),
        );
      },
      // CompositedTransformTarget makes the composer's position trackable by
      // the CompositedTransformFollower in the overlay.
      child: CompositedTransformTarget(
        link: layerLink,
        child: composerContainer,
      ),
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.hasContent,
    required this.allowEmptySubmit,
    required this.hideTipButton,
    required this.onEmojiTap,
    required this.onSubmit,
    required this.colors,
    this.onCameraTap,
    this.onAddTap,
    this.onTipTap,
  });

  final bool hasContent;
  final bool allowEmptySubmit;
  final bool hideTipButton;
  final VoidCallback onEmojiTap;
  final VoidCallback onSubmit;
  final LabColors colors;
  final VoidCallback? onCameraTap;
  final VoidCallback? onAddTap;
  final VoidCallback? onTipTap;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final canSend = allowEmptySubmit || hasContent;

    // padding: 0 12px 12px 12px — matches .action-row in ShortTextInput.svelte
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left cluster: camera / emoji / plus — gap 8px (.action-buttons-left)
          Row(
            children: [
              if (!hideTipButton) ...[
                _ActionBtn(
                  icon: LabIcons.zap,
                  iconSize: 16,
                  onTap: onTipTap,
                  colors: c,
                ),
                const SizedBox(width: 8),
              ],
              _ActionBtn(
                icon: LabIcons.camera,
                iconSize: 15,
                onTap: onCameraTap,
                colors: c,
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: LabIcons.emojiFill,
                iconSize: 18,
                onTap: onEmojiTap,
                colors: c,
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: LabIcons.plus,
                iconSize: 15,
                thick: true, // 3.2px stroke variant
                onTap: onAddTap,
                colors: c,
              ),
            ],
          ),

          // Right: blurple send button + chevron divider (.send-button-container)
          _SendButton(
            canSend: canSend,
            onSend: onSubmit,
            colors: c,
          ),
        ],
      ),
    );
  }
}

// ── Action button (camera / emoji / plus) ────────────────────────────────────

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.icon,
    required this.iconSize,
    required this.colors,
    this.onTap,
    this.thick = false,
  });

  final String icon;
  final double iconSize;
  final LabColors colors;
  final VoidCallback? onTap;
  final bool thick;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          // 30×30px — matches primaryXs/secondaryXs height tier.
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.white8,
            borderRadius: BorderRadius.circular(7),
          ),
          child: LabIcon(
            widget.icon,
            size: widget.iconSize,
            color: c.white33,
            thick: widget.thick,
          ),
        ),
      ),
    );
  }
}

// ── Send button (blurple gradient + chevron divider) ─────────────────────────

class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.canSend,
    required this.onSend,
    required this.colors,
  });

  final bool canSend;
  final VoidCallback onSend;
  final LabColors colors;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;

    return AnimatedOpacity(
      opacity: widget.canSend ? 1.0 : 0.38,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onTapDown:
            widget.canSend ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.canSend
            ? (_) {
                setState(() => _pressed = false);
                widget.onSend();
              }
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            // 30px height — matches the 30px action buttons in the same row.
            height: 30,
            decoration: BoxDecoration(
              gradient: c.blurple as LinearGradient?,
              color: c.blurple is! LinearGradient ? c.blurpleColor : null,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Send icon area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: LabIcon(LabIcons.send, size: 15, color: c.whiteEnforced),
                ),

                // .send-divider
                Container(
                  width: LabStroke.thin,
                  height: 30,
                  color: c.white33,
                ),

                // .chevron-btn — 1px top offset to optically centre the caret
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 1, 7, 0),
                  child: LabIcon(
                    LabIcons.chevronDown,
                    size: 7,
                    color: c.white66,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
