import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/key_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SlotMachine
// ─────────────────────────────────────────────────────────────────────────────
//
// Matches webapp SpinKeyModal slot machine layout:
//   • 3 rows × 4 slots, each row 88px tall with top/bottom fade gradients
//   • Draggable blurple handle on the right that triggers the spin
//   • 12 reels scroll nsec bech32 char chunks; dashes while unspun
//   • Staggered spin → settle to final value
//   • [onSpinComplete] fires after the last slot settles + [completeDelay]

const _bech32Chars = 'QPZRY9X8GF2TVDW0S3JN54KHCE6MUA7L';

// Layout constants (matching webapp exactly)
const _totalHeight = 296.0;
const _diskHeight = 88.0;
const _slotTop = (_totalHeight - _diskHeight) / 2; // 104
const _centerY = _slotTop + _diskHeight / 2; // 148
const _handleMin = 40.0;
const _handleMax = 256.0;

/// Height of each nsec chunk cell — matches the settled display box.
const _reelCellHeight = 56.0;

/// Vertical inset that centres a [_reelCellHeight] cell inside [_diskHeight].
const _reelCellInset = (_diskHeight - _reelCellHeight) / 2;

/// [_offset] at which cell 0 is centred in the disk window.
const _centeredOffset = 0.0;

/// Cell 0 top (px) once it has fully left below the disk window.
const _recycleCellTop = _diskHeight;

/// Spin begins with cell 0 fully above the window (enters from the top).
const _spinStartOffset = -_reelCellInset - _reelCellHeight;

/// Minimum tiles kept in the reel queue while spinning.
const _minReelItems = 3;

/// Cells that scroll past after fast spin before the target lands.
const _cellsBeforeLand = 4;

/// Deceleration phase after fast spin (per reel).
const _stopDurationMs = 900;

/// End wobble duration (per reel).
const _wobbleMs = 280;

// Slot placeholder strings (dashes) before spinning
List<String> _emptyParts() =>
    List.generate(12, (i) => i < 9 ? '-----' : '------');

String _randomChunk(int length) {
  final rng = Random();
  return String.fromCharCodes(
    List.generate(length, (_) => _bech32Chars.codeUnitAt(rng.nextInt(32))),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Single scrolling reel column
// ─────────────────────────────────────────────────────────────────────────────

enum _ReelPhase { idle, spinning, stopping, wobble, settled }

class _SlotReel extends StatefulWidget {
  const _SlotReel({
    super.key,
    required this.charLen,
    required this.target,
    required this.spinEpoch,
    required this.spinDelayMs,
    required this.resetEpoch,
  });

  final int charLen;
  final String target;
  final int spinEpoch;
  final int spinDelayMs;
  final int resetEpoch;

  @override
  State<_SlotReel> createState() => _SlotReelState();
}

class _SlotReelState extends State<_SlotReel> with TickerProviderStateMixin {
  _ReelPhase _phase = _ReelPhase.idle;
  final List<String> _items = [];
  double _offset = 0;
  double _velocity = 0;
  double _wobbleOffset = 0;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  Duration _wobbleStart = Duration.zero;
  int _lastSpinEpoch = 0;
  int _lastResetEpoch = 0;
  Timer? _spinStopTimer;

  static const _spinDuration = Duration(milliseconds: 2000);
  static const _pixelsPerSecond = 420.0;
  static const _wobbleAmplitude = 7.0;

  @override
  void initState() {
    super.initState();
    _seedIdle();
  }

  @override
  void didUpdateWidget(covariant _SlotReel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetEpoch != _lastResetEpoch) {
      _lastResetEpoch = widget.resetEpoch;
      _stopMotion();
      _seedIdle();
      setState(() {});
    }
    if (widget.spinEpoch != _lastSpinEpoch && widget.spinEpoch > 0) {
      _lastSpinEpoch = widget.spinEpoch;
      _scheduleSpin();
    }
    if (widget.target != oldWidget.target &&
        (_phase == _ReelPhase.settled || _phase == _ReelPhase.idle)) {
      _seedIdle();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _stopMotion();
    super.dispose();
  }

  void _seedIdle() {
    _phase = _ReelPhase.idle;
    _velocity = 0;
    _wobbleOffset = 0;
    _items
      ..clear()
      ..add(widget.target);
    _offset = _centeredOffset;
  }

  void _stopMotion() {
    _spinStopTimer?.cancel();
    _spinStopTimer = null;
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _lastTick = Duration.zero;
    _wobbleStart = Duration.zero;
  }

  void _scheduleSpin() {
    _stopMotion();
    _seedIdle();
    Future.delayed(Duration(milliseconds: widget.spinDelayMs), () {
      if (!mounted || widget.spinEpoch != _lastSpinEpoch) return;
      _startSpinning();
    });
  }

  void _startSpinning() {
    setState(() {
      _phase = _ReelPhase.spinning;
      _velocity = _pixelsPerSecond;
      _wobbleOffset = 0;
      _items
        ..clear()
        ..addAll(
          List.generate(
            _minReelItems + 2,
            (_) => _randomChunk(widget.charLen),
          ),
        );
      _offset = _spinStartOffset;
    });

    _lastTick = Duration.zero;
    _ticker = createTicker(_onTick)..start();

    _spinStopTimer = Timer(_spinDuration, () {
      if (!mounted) return;
      _beginStopping();
    });
  }

  void _beginStopping() {
    setState(() {
      _phase = _ReelPhase.stopping;
      final subCell = _offset % _reelCellHeight;
      // Short landing strip — target is always last (appending to the long spin
      // queue never reached the target in time).
      _items
        ..clear()
        ..addAll(
          List.generate(
            _cellsBeforeLand - 1,
            (_) => _randomChunk(widget.charLen),
          ),
        )
        ..add(widget.target);
      // Keep sub-cell scroll phase but place cell 0 above the window again.
      _offset = _spinStartOffset + subCell;
    });
  }

  /// Cell [index] top edge in the clipped disk (px).
  double _cellTop(int index) =>
      _reelCellInset + _offset + index * _reelCellHeight;

  void _recycleForward() {
    // Recycle only after cell 0 has fully left below the window — not at one
    // cell height (that snapped each new symbol into the centre band).
    while (_cellTop(0) >= _recycleCellTop && _items.length > 1) {
      _offset -= _reelCellHeight;
      _items.removeAt(0);
      if (_phase == _ReelPhase.spinning) {
        _items.add(_randomChunk(widget.charLen));
      }
    }
  }

  void _startWobble(Duration elapsed) {
    _phase = _ReelPhase.wobble;
    _wobbleStart = elapsed;
    _velocity = 0;
    _offset = _centeredOffset;
    _items
      ..clear()
      ..add(widget.target);
  }

  void _finishSettle() {
    _phase = _ReelPhase.settled;
    _wobbleOffset = 0;
    _offset = _centeredOffset;
    _velocity = 0;
    _items
      ..clear()
      ..add(widget.target);
    _ticker?.stop();
  }

  void _onTick(Duration elapsed) {
    if (_phase == _ReelPhase.idle || _phase == _ReelPhase.settled) return;
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;

    setState(() {
      switch (_phase) {
        case _ReelPhase.spinning:
          _offset += _velocity * dt;
          _recycleForward();
        case _ReelPhase.stopping:
          final onlyTarget =
              _items.length == 1 && _items.first == widget.target;
          if (onlyTarget) {
            _velocity = 0;
            final t = (1 - exp(-dt * 10)).clamp(0.0, 1.0);
            _offset = _offset + (_centeredOffset - _offset) * t;
            if (_offset.abs() < 0.35) {
              _startWobble(elapsed);
            }
          } else {
            _velocity = max(70, _velocity * exp(-dt * 3.2));
            _offset += _velocity * dt;
            _recycleForward();
          }
        case _ReelPhase.wobble:
          final t = (elapsed - _wobbleStart).inMicroseconds /
              (_wobbleMs * 1000.0);
          if (t >= 1) {
            _finishSettle();
          } else {
            _wobbleOffset =
                sin(t * pi * 2.8) * _wobbleAmplitude * (1 - t);
          }
        case _ReelPhase.idle:
        case _ReelPhase.settled:
          break;
      }
    });
  }

  bool _isPlaceholder(String text) => text.startsWith('---');

  static const _cellTextStyle = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: -0.3,
  );

  BoxDecoration _cellDecoration(LabColors c) => BoxDecoration(
        border: Border(
          top: BorderSide(color: c.black33, width: 0.33),
          bottom: BorderSide(color: c.black33, width: 0.33),
        ),
      );

  Widget _buildCellContent(
    LabColors c,
    String text, {
    bool placeholder = false,
  }) {
    return Container(
      height: _reelCellHeight,
      decoration: _cellDecoration(c),
      child: Center(
        child: placeholder
            ? Container(
                width: 24,
                height: 8,
                decoration: BoxDecoration(
                  color: c.white33,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : Text(text, style: _cellTextStyle),
      ),
    );
  }

  Widget _buildReelBody(LabColors c) {
    // [_offset] == 0 → cell 0 centred in the 88px disk (16px inset top/bottom).
    return Transform.translate(
      offset: Offset(0, _reelCellInset + _offset + _wobbleOffset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _items.length; i++)
            _buildCellContent(
              c,
              _items[i],
              placeholder: _isPlaceholder(_items[i]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return SizedBox(
      width: 64,
      height: _diskHeight,
      child: ColoredBox(
        color: c.white16,
        child: ClipRect(
          child: _buildReelBody(c),
        ),
      ),
    );
  }
}

class SpinKeySlotMachine extends StatefulWidget {
  const SpinKeySlotMachine({
    super.key,
    this.initialNsec,
    this.onNsecReady,
    this.onSpinComplete,
    this.completeDelay = const Duration(milliseconds: 1200),
  });

  /// When set, reels use this key (cosmetic spin only) instead of generating anew.
  final String? initialNsec;

  /// Fired when a signing key exists (initial pregen or after [regenerateKey]).
  final void Function(String nsec)? onNsecReady;

  final void Function(String nsec)? onSpinComplete;
  final Duration completeDelay;

  @override
  State<SpinKeySlotMachine> createState() => SpinKeySlotMachineState();
}

/// [GlobalKey] target for [SpinKeySlotMachineState.regenerateKey].
class SpinKeySlotMachineState extends State<SpinKeySlotMachine>
    with SingleTickerProviderStateMixin {
  String _nsec = '';
  List<String> _targetParts = _emptyParts();
  bool _isSpinning = false;
  int _spinEpoch = 0;
  int _resetEpoch = 0;

  // Handle drag
  double _handleOffset = _handleMin;
  bool _isDragging = false;
  late final AnimationController _handleCtrl;
  late Animation<double> _handleAnim;

  @override
  void initState() {
    super.initState();
    _handleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _handleCtrl.addListener(() {
      if (mounted) setState(() => _handleOffset = _handleAnim.value);
    });
    if (widget.initialNsec != null && widget.initialNsec!.isNotEmpty) {
      _applyNsec(widget.initialNsec!, notify: true);
    } else {
      _assignNewKey(notify: true);
    }
  }

  void _applyNsec(String nsec, {required bool notify}) {
    _nsec = nsec;
    _targetParts = KeyGenerator.splitNsec(nsec);
    if (notify) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onNsecReady?.call(nsec);
      });
    }
  }

  /// New key for PoW + signing; cosmetic reels reset to placeholders.
  void regenerateKey() {
    _assignNewKey(notify: true);
    setState(() {
      _isSpinning = false;
      _resetEpoch++;
    });
  }

  void _assignNewKey({required bool notify}) {
    final result = KeyGenerator.generate();
    _nsec = result.nsec;
    _targetParts = result.parts;
    if (notify) {
      final nsec = _nsec;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onNsecReady?.call(nsec);
      });
    }
  }

  @override
  void dispose() {
    _handleCtrl.dispose();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _spinEpoch++;
    });

    const totalMs = 2000 + 11 * 100 + _stopDurationMs + _wobbleMs;
    Future.delayed(const Duration(milliseconds: totalMs), () {
      if (!mounted) return;
      setState(() => _isSpinning = false);
      Future.delayed(widget.completeDelay, () {
        if (mounted) widget.onSpinComplete?.call(_nsec);
      });
    });
  }

  // ── Handle drag ─────────────────────────────────────────────────────────────

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_isDragging || _isSpinning) return;
    setState(() {
      _handleOffset =
          (_handleOffset + d.delta.dy).clamp(_handleMin, _handleMax);
    });
  }

  void _onDragEnd(DragEndDetails _) {
    if (!_isDragging) return;
    setState(() => _isDragging = false);
    if (_handleOffset > _centerY + 30) _spin();
    _animateHandleBack();
  }

  void _animateHandleBack() {
    _handleAnim = Tween<double>(
      begin: _handleOffset,
      end: _handleMin,
    ).animate(
      CurvedAnimation(parent: _handleCtrl, curve: Curves.easeOutCubic),
    );
    _handleCtrl
      ..reset()
      ..forward();
  }

  // ── Build helpers ───────────────────────────────────────────────────────────

  Widget _buildSlot(LabColors c, int index) {
    final charLen = index < 9 ? 5 : 6;
    return _SlotReel(
      key: ValueKey('reel-$index-$_resetEpoch'),
      charLen: charLen,
      target: _targetParts[index],
      spinEpoch: _spinEpoch,
      spinDelayMs: index * 100,
      resetEpoch: _resetEpoch,
    );
  }

  Widget _buildRow(LabColors c, int rowIndex) {
    return Container(
      height: _diskHeight,
      decoration: BoxDecoration(
        color: c.black66,
        borderRadius: BorderRadius.circular(17),
        border: LabBorder.all(color: c.white16, width: 0.33),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              _buildSlot(c, rowIndex * 4 + 0),
              const SizedBox(width: 4),
              _buildSlot(c, rowIndex * 4 + 1),
              const SizedBox(width: 4),
              _buildSlot(c, rowIndex * 4 + 2),
              const SizedBox(width: 4),
              _buildSlot(c, rowIndex * 4 + 3),
              const SizedBox(width: 8),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.black66,
                    c.black66.withValues(alpha: 0.7),
                    c.black66.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.4, 1],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    c.black66,
                    c.black66.withValues(alpha: 0.7),
                    c.black66.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.4, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(LabColors c) {
    final isBottomHalf = _handleOffset > _centerY;
    final distFromCenter = (_handleOffset - _centerY).abs();
    final maxDist = _centerY - _handleMin;
    final circleProgress = 1.0 - (distFromCenter / maxDist).clamp(0.0, 1.0);
    final circleSize = 44.0 + 6.0 * circleProgress;
    final circleSizeOffset = (circleSize - 44.0) / 2;

    final barHeight = (_handleOffset - _centerY).abs();
    final barTop = isBottomHalf ? _centerY : _handleOffset;

    return SizedBox(
      width: 48,
      height: _totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 8,
            top: _slotTop,
            child: Container(
              width: 32,
              height: _diskHeight,
              decoration: BoxDecoration(
                color: const Color(0x88000000),
                borderRadius: BorderRadius.circular(16),
                border: LabBorder.all(color: c.white16, width: 0.33),
              ),
            ),
          ),
          if (barHeight > 2)
            Positioned(
              left: 16,
              top: barTop,
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: isBottomHalf
                      ? Alignment.bottomCenter
                      : Alignment.topCenter,
                  end: isBottomHalf
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  colors: const [
                    Colors.white,
                    Color(0xFF232323),
                    Colors.transparent,
                  ],
                  stops: const [0.5, 0.66, 1.0],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: Container(
                  width: 16,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9696A3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Color(0x1A000000),
                          Color(0x0D000000),
                        ],
                        stops: [0.33, 0.80, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 2 - circleSizeOffset,
            top: _handleOffset - circleSizeOffset,
            child: GestureDetector(
              onVerticalDragStart: (_) =>
                  setState(() => _isDragging = true),
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  gradient: c.blurple,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.black33,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.6, -0.6),
                      radius: 1.2,
                      colors: [Colors.transparent, Color(0x33000000)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow(c, 0),
            const SizedBox(height: 16),
            _buildRow(c, 1),
            const SizedBox(height: 16),
            _buildRow(c, 2),
          ],
        ),
        const SizedBox(width: 16),
        _buildHandle(c),
      ],
    );
  }
}
