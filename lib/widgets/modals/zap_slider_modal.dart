import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/settings_service.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';
import 'package:zapstore/widgets/composer/nostr_composer.dart';
import 'package:zapstore/widgets/composer/nostr_text_controller.dart' show ComposerResult;
import 'package:zapstore/widgets/zap_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ZapSliderModal — 3-step zap flow matching webapp's ZapSliderModal.svelte
//
// Step 1  slider    circular arc amount picker + .input-container
//                   (amount row + divider + NostrComposer with send button)
// Step 2  invoice   QR code + copy link + back + waiting/done button
// Step 3  success   blurple circle + "Zap Sent!" + sats amount
// ─────────────────────────────────────────────────────────────────────────────

enum _ZapStep { slider, invoice, success }

class ZapSliderModal {
  static Future<void> show(
    BuildContext context, {
    required App app,
    Profile? author,
  }) {
    return showModal<void>(
      context,
      builder: (ctx) => _ZapSliderContent(app: app, author: author),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ZapSliderContent extends HookConsumerWidget {
  const _ZapSliderContent({required this.app, this.author});

  final App app;
  final Profile? author;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    final step = useState(_ZapStep.slider);
    final amount = useState<double>(2100);
    final invoice = useState<String?>(null);
    final invoiceLoading = useState(false);
    final showManualClose = useState(false);
    final copied = useState(false);
    final error = useState<String?>(null);

    // NostrComposer manages its own internal controller; we read the result
    // via onSubmit. handleZap accepts the ComposerResult directly.
    final timerRef = useRef<Timer?>(null);
    useEffect(() => () => timerRef.value?.cancel(), const []);

    final qrUrl = invoice.value != null
        ? 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&bgcolor=ffffff&color=000000&data=${Uri.encodeComponent('lightning:${invoice.value!.toUpperCase()}')}'
        : null;

    Future<void> handleZap([ComposerResult? comment]) async {
      if (invoiceLoading.value) return;

      step.value = _ZapStep.invoice;
      invoice.value = null;
      invoiceLoading.value = true;
      error.value = null;
      showManualClose.value = false;

      try {
        final storageNotifier = ref.read(storageNotifierProvider.notifier);
        final settingsService = ref.read(settingsServiceProvider);
        final settings = await settingsService.load();
        final nwcString = settings.nwcConnectionString;

        var signer = ref.read(Signer.activeSignerProvider);
        if (signer == null) {
          signer = Bip340PrivateKeySigner(Utils.generateRandomHex64(), ref.asRef);
          await signer.signIn(registerSigner: false);
        }

        final latestMetadata = app.installable;
        if (latestMetadata == null || author == null) {
          throw Exception('App or author not ready.');
        }

        final relays = await storageNotifier.resolveRelays('AppCatalog');
        final zapRequest = PartialZapRequest()
          ..amount = amount.value.round() * 1000
          ..relays = relays;
        final commentText = comment?.text ?? '';
        if (commentText.isNotEmpty) zapRequest.comment = commentText;
        zapRequest.linkProfileByPubkey(author!.pubkey);
        zapRequest.linkModel(app);
        zapRequest.linkModelById(latestMetadata.id);

        final signed = await zapRequest.signWith(signer);

        if (nwcString != null && nwcString.isNotEmpty) {
          await executeZapPayment(signed, nwcString, ref.asRef);
          step.value = _ZapStep.success;
          return;
        }

        final bolt11 = await signed.getInvoice();
        invoice.value = bolt11;
        invoiceLoading.value = false;

        timerRef.value?.cancel();
        timerRef.value = Timer(const Duration(seconds: 30), () {
          showManualClose.value = true;
        });
      } catch (e) {
        error.value = e.toString();
        step.value = _ZapStep.slider;
        invoiceLoading.value = false;
      }
    }

    // ── Slider step ──────────────────────────────────────────────────────────
    if (step.value == _ZapStep.slider) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 16),
              child: Column(
                children: [
                  Text(
                    'Zap',
                    style: LabTextStyles.semibold22.copyWith(color: c.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${author?.name ?? 'Creator'} for publishing ${app.name ?? 'this app'}',
                    style: LabTextStyles.reg15.copyWith(color: c.white66),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Error banner
            if (error.value != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.rouge.colors.first.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: LabBorder.all(
                        color: c.rouge.colors.first.withAlpha(77)),
                  ),
                  child: Row(
                    children: [
                      LabIcon(LabIcons.cross,
                          size: 16, color: c.rouge.colors.first),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error.value!,
                          style: LabTextStyles.reg13
                              .copyWith(color: c.rouge.colors.first),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Circular arc slider — profile pic only in center (no amount text)
            _ZapArcSlider(
              initialValue: amount.value,
              profile: author,
              onChanged: (v) => amount.value = v,
            ),

            // ── .input-container ─────────────────────────────────────────────
            // black33, r16, 0.33px white33 border — contains:
            //   1) amount row (⚡ gold icon + editable sats field)
            //   2) 1.4px white8 divider
            //   3) NostrComposer (size small, send button IS the Zap trigger)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: c.black33,
                  borderRadius: BorderRadius.circular(16),
                  border: LabBorder.all(color: c.white33, width: LabStroke.thin),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Amount row — padding: 12px 16px (matching .amount-row)
                    _AmountRow(
                      amount: amount.value,
                      onChanged: (v) => amount.value = v,
                      colors: c,
                    ),

                    // Divider — 1.4px, white8 (matching .divider in ZapSlider.svelte)
                    Container(height: 1.4, color: c.white8),

                    // Comment composer — nested:true removes its own bg+border since
                    // this container already provides the black33 + white33 border.
                    NostrComposer(
                      placeholder: 'Write your comment…',
                      size: ComposerSize.small,
                      showActionRow: true,
                      allowEmptySubmit: true,
                      nested: true,
                      onSubmit: (result) => handleZap(result),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      );
    }

    // ── Invoice step ─────────────────────────────────────────────────────────
    if (step.value == _ZapStep.invoice) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Invoice',
              style: LabTextStyles.semibold22.copyWith(color: c.white),
            ),
            const SizedBox(height: 16),

            // QR code or skeleton
            (invoiceLoading.value || qrUrl == null)
                ? _QrSkeleton(colors: c)
                : _QrImage(url: qrUrl, invoice: invoice.value, colors: c),
            const SizedBox(height: 8),

            // Copy link
            GestureDetector(
              onTap: () async {
                if (invoice.value == null) return;
                await Clipboard.setData(
                    ClipboardData(text: invoice.value!));
                copied.value = true;
                Timer(
                    const Duration(seconds: 2), () => copied.value = false);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LabIcon(
                      copied.value ? LabIcons.check : LabIcons.copy,
                      size: 18,
                      color: copied.value ? c.blurpleColor : c.white66,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      copied.value ? 'Copied!' : 'Copy link',
                      style: LabTextStyles.reg15.copyWith(
                        color:
                            copied.value ? c.blurpleColor : c.white66,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Back + waiting-for-payment / done
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    timerRef.value?.cancel();
                    step.value = _ZapStep.slider;
                    invoice.value = null;
                    invoiceLoading.value = false;
                    showManualClose.value = false;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: c.black33,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Back',
                        style:
                            LabTextStyles.reg15.copyWith(color: c.white66)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: showManualClose.value
                      ? _GradientButton(
                          onTap: () {
                            timerRef.value?.cancel();
                            Navigator.of(context).pop();
                          },
                          label: "I've paid. Close this",
                          gradient: c.blurple,
                        )
                      : _WaitingButton(colors: c),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ── Success step ─────────────────────────────────────────────────────────
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 32, 14, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: c.blurpleColor.withAlpha(38),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: c.blurpleColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Zap Sent!',
            style: LabTextStyles.semibold22.copyWith(color: c.blurpleColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Zapped ${formatSatsWithSeparators(amount.value.round())} ⚡ successfully',
            style: LabTextStyles.reg15.copyWith(color: c.white66),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Amount row — editable sats field with gold ⚡ icon
// ─────────────────────────────────────────────────────────────────────────────

class _AmountRow extends StatefulWidget {
  const _AmountRow({
    required this.amount,
    required this.onChanged,
    required this.colors,
  });

  final double amount;
  final ValueChanged<double> onChanged;
  final LabColors colors;

  @override
  State<_AmountRow> createState() => _AmountRowState();
}

class _AmountRowState extends State<_AmountRow> {
  late final TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl =
        TextEditingController(text: _formatWithCommas(widget.amount.round()));
  }

  @override
  void didUpdateWidget(_AmountRow old) {
    super.didUpdateWidget(old);
    if (!_editing && old.amount != widget.amount) {
      _ctrl.text = _formatWithCommas(widget.amount.round());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static String _formatWithCommas(int v) {
    // Simple comma-separated number
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    // padding: 12px 16px — matches .amount-row in ZapSlider.svelte
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          // Gold zap icon — LabIcons.zap with gold gradient ShaderMask
          ShaderMask(
            shaderCallback: (b) => c.gold.createShader(b),
            child: LabIcon(LabIcons.zap, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),

          // Editable amount — font-size 18, font-weight 700
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.white,
                fontFamily: LabTextStyles.reg15.fontFamily,
              ),
              cursorColor: c.white,
              cursorWidth: 1.6,
              onTap: () {
                _editing = true;
                _ctrl.text = widget.amount.round().toString();
                _ctrl.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _ctrl.text.length);
              },
              onChanged: (v) {
                final n = int.tryParse(v) ?? 0;
                widget.onChanged(n.clamp(0, 1000000).toDouble());
              },
              onSubmitted: (_) {
                _editing = false;
                _ctrl.text = _formatWithCommas(widget.amount.round());
              },
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.white33),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circular arc slider
// Exactly matches ZapSlider.svelte canvas geometry:
//   SIZE=320, RADIUS=100, BG_THICKNESS=48, VAL_THICKNESS=32, HANDLE_SIZE=24
//   .slider-container height: 296px (clips 24px of dead-zone at bottom)
//   Center: profile pic only (no amount text)
//   Markers at [0, 10, 100, 1k, 10k, 100k, 1M] with tick lines + labels
// ─────────────────────────────────────────────────────────────────────────────

class _ZapArcSlider extends StatefulWidget {
  const _ZapArcSlider({
    required this.initialValue,
    required this.onChanged,
    this.profile,
  });

  final double initialValue;
  final ValueChanged<double> onChanged;
  final Profile? profile;

  @override
  State<_ZapArcSlider> createState() => _ZapArcSliderState();
}

class _ZapArcSliderState extends State<_ZapArcSlider> {
  // Arc geometry constants matching webapp's ZapSlider.svelte
  static const double _radius = 100;
  static const double _handleSize = 24;
  static const double _startAngle = math.pi * 3 / 4; // 135°
  static const double _totalAngle = math.pi * 3 / 2; // 270°

  // Log-scale: 0 – 1,000,000
  static const double _minSats = 0;
  static const double _maxSats = 1000000;

  late double _norm; // 0–1

  @override
  void initState() {
    super.initState();
    _norm = _satsToNorm(widget.initialValue.clamp(_minSats, _maxSats));
  }

  static double _satsToNorm(double sats) {
    if (sats <= 0) return 0;
    return (math.log(sats + 1) / math.log(_maxSats + 1)).clamp(0.0, 1.0);
  }

  static double _normToSats(double norm) {
    if (norm <= 0) return 0;
    final raw = math.exp(norm * math.log(_maxSats + 1)) - 1;
    return raw.clamp(_minSats, _maxSats).roundToDouble();
  }

  void _onPan(DragUpdateDetails d) {
    const center = Offset(160, 160); // canvas is always 320×320
    final dx = d.localPosition.dx - center.dx;
    final dy = d.localPosition.dy - center.dy;
    var angle = math.atan2(dy, dx);
    var rel = (angle - _startAngle) % (2 * math.pi);
    if (rel < 0) rel += 2 * math.pi;
    if (rel > _totalAngle + 0.2) return;
    final norm = (rel / _totalAngle).clamp(0.0, 1.0);
    setState(() => _norm = norm);
    widget.onChanged(_normToSats(norm));
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    // Webapp .slider-container { height:296px; align-items:flex-start }
    // .slider-canvas-wrapper { height:320px; overflow:visible } → the canvas
    // bleeds 24px below the slider-container (dead zone).
    //
    // Flutter equivalent: OverflowBox lets the 320×320 child escape the
    // SizedBox(296) constraint while ClipRect hard-clips at y=296.
    // This keeps the canvas at Size(320,320) → cx=cy=160, so the arc geometry,
    // profile pic (left:108, top:108) and handle all sit at the correct coords.
    return Center(
      child: ClipRect(
        child: SizedBox(
          width: 320,
          height: 296,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxWidth: 320,
            maxHeight: 320,
            child: SizedBox(
              width: 320,
              height: 320,
              child: GestureDetector(
              onPanUpdate: _onPan,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  // Arc track + filled arc + marker ticks/labels
                  CustomPaint(
                    size: const Size(320, 320),
                    painter: _ArcPainter(
                      norm: _norm,
                      trackColor: const Color.fromRGBO(0, 0, 0, 0.33),
                      fillGradient: c.gold,
                      markerColor: Colors.white.withOpacity(0.33),
                    ),
                  ),

                  // White handle dot — positioned on the arc at the current value
                  Builder(builder: (_) {
                    final handleAngle = _startAngle + _norm * _totalAngle;
                    const r = _radius;
                    const cx = 160.0;
                    const cy = 160.0;
                    final hx = cx + r * math.cos(handleAngle);
                    final hy = cy + r * math.sin(handleAngle);
                    const hr = _handleSize / 2;
                    return Positioned(
                      left: hx - hr,
                      top: hy - hr,
                      child: Container(
                        width: hr * 2,
                        height: hr * 2,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),

                  // Center: profile pic (104px, canvas center = 160 → left/top = 160−52 = 108)
                  Positioned(
                    left: 108,
                    top: 108,
                    child: ProfilePic(profile: widget.profile, size: 104),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arc painter — fixed pixel geometry matching zaplab_design's LabZapSliderPainter
//   radius=100, bgThickness=48, valThickness=32, handleSize=24, markerLength=8
//   Value arc: SweepGradient (same technique as LabZapSliderPainter)
//   Markers: [0, 10, 100, 1K, 10K, 100K, 1M] tick lines + labels
// ─────────────────────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.norm,
    required this.trackColor,
    required this.fillGradient,
    required this.markerColor,
  });

  final double norm;
  final Color trackColor;
  final Gradient fillGradient;
  final Color markerColor;

  // Fixed pixel constants — no scaling, matching zaplab_design exactly.
  static const double _radius = 100;
  static const double _bgThickness = 48;
  static const double _valThickness = 32;
  static const double _markerLength = 8;
  static const double _startAngle = math.pi * 3 / 4; // 135°
  static const double _totalAngle = math.pi * 3 / 2; // 270°
  static const double _maxSats = 1000000;

  // innerR = 100 − 24 = 76  |  outerR = 100 + 24 + 8 = 132  |  labelR = 146
  static const double _innerR = _radius - _bgThickness / 2;
  static const double _outerR = _radius + _bgThickness / 2 + _markerLength;
  static const double _labelR = _outerR + 14;

  static const List<int> _markerValues = [
    0, 10, 100, 1000, 10000, 100000, 1000000
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final rect = Rect.fromCircle(center: center, radius: _radius);

    // ── Background track (48px thick) ────────────────────────────────────────
    canvas.drawArc(
      rect,
      _startAngle,
      _totalAngle,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _bgThickness
        ..strokeCap = StrokeCap.round,
    );

    // ── Marker ticks + labels ─────────────────────────────────────────────────
    final tickPaint = Paint()
      ..color = markerColor
      ..strokeWidth = 0.33
      ..style = PaintingStyle.stroke;

    for (final v in _markerValues) {
      final pct = v == 0 ? 0.0 : math.log(v + 1) / math.log(_maxSats + 1);
      final angle = _startAngle + pct * _totalAngle;
      canvas.drawLine(
        Offset(cx + _innerR * math.cos(angle), cy + _innerR * math.sin(angle)),
        Offset(cx + _outerR * math.cos(angle), cy + _outerR * math.sin(angle)),
        tickPaint,
      );
      _drawLabel(
        canvas,
        _formatMarker(v),
        cx + _labelR * math.cos(angle),
        cy + _labelR * math.sin(angle),
      );
    }

    // ── Value arc (SweepGradient — matches LabZapSliderPainter technique) ────
    if (norm > 0) {
      final sweepAngle = _totalAngle * norm;
      canvas.drawArc(
        rect,
        _startAngle,
        sweepAngle,
        false,
        Paint()
          ..shader = SweepGradient(
            colors: [...fillGradient.colors, fillGradient.colors.first],
            stops: [
              0.0,
              ...List.generate(
                fillGradient.colors.length - 1,
                (i) => (i + 1) / fillGradient.colors.length,
              ),
              0.999999,
            ],
            startAngle: 0,
            endAngle: 2 * math.pi,
            transform: const GradientRotation(_startAngle - math.pi / 2),
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _valThickness
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, double x, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: markerColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  static String _formatMarker(int v) {
    if (v >= 1000000) return '${v ~/ 1000000}M';
    if (v >= 1000) return '${v ~/ 1000}K';
    return v.toString();
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.norm != norm;
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoice step helpers
// ─────────────────────────────────────────────────────────────────────────────

class _QrSkeleton extends StatelessWidget {
  const _QrSkeleton({required this.colors});
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 216,
      height: 216,
      decoration: BoxDecoration(
        color: colors.white16,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _QrImage extends StatelessWidget {
  const _QrImage({required this.url, required this.invoice, required this.colors});
  final String url;
  final String? invoice;
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.white16.withOpacity(0.4)),
      ),
      child: Image.network(
        url,
        width: 200,
        height: 200,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(width: 200, height: 200),
      ),
    );
  }
}

class _WaitingButton extends StatelessWidget {
  const _WaitingButton({required this.colors});
  final LabColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.blurpleColor.withAlpha(64),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.white66),
          ),
          const SizedBox(width: 8),
          Text('Waiting for payment',
              style: LabTextStyles.reg15.copyWith(color: c.white66)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable gradient button
// ─────────────────────────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onTap,
    required this.label,
    required this.gradient,
  });

  final VoidCallback onTap;
  final String label;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: LabTextStyles.semibold17.copyWith(color: c.whiteEnforced),
        ),
      ),
    );
  }
}
