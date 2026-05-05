import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/key_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SlotMachine
// ─────────────────────────────────────────────────────────────────────────────
//
// Matches webapp SpinKeyModal slot machine layout:
//   • 3 rows × 4 slots, each row 88px tall with top/bottom fade gradients
//   • Draggable blurple handle on the right that triggers the spin
//   • 12 slots show nsec bech32 char chunks; dashes while unspun
//   • Staggered spin: random chars → settle to final value
//   • [onSpinComplete] fires after the last slot settles + [completeDelay]

const _bech32Chars = 'QPZRY9X8GF2TVDW0S3JN54KHCE6MUA7L';

// Layout constants (matching webapp exactly)
const _totalHeight = 296.0;
const _diskHeight = 88.0;
const _slotTop = (_totalHeight - _diskHeight) / 2; // 104
const _centerY = _slotTop + _diskHeight / 2; // 148
const _handleMin = 40.0;
const _handleMax = 256.0;

// Slot placeholder strings (dashes) before spinning
List<String> _emptyParts() =>
    List.generate(12, (i) => i < 9 ? '-----' : '------');

String _randomChunk(int length) {
  final rng = Random();
  return String.fromCharCodes(
    List.generate(length, (_) => _bech32Chars.codeUnitAt(rng.nextInt(32))),
  );
}

class SpinKeySlotMachine extends StatefulWidget {
  const SpinKeySlotMachine({
    super.key,
    this.onSpinComplete,
    this.completeDelay = const Duration(milliseconds: 1200),
  });

  final void Function(String nsec)? onSpinComplete;
  final Duration completeDelay;

  @override
  State<SpinKeySlotMachine> createState() => _SpinKeySlotMachineState();
}

class _SpinKeySlotMachineState extends State<SpinKeySlotMachine>
    with SingleTickerProviderStateMixin {
  // Key state
  String _nsec = '';
  List<String> _targetParts = _emptyParts();
  final List<String> _displayParts = _emptyParts();
  bool _isSpinning = false;

  // Per-slot timers (spin interval + settle)
  final List<Timer?> _spinTimers = List.filled(12, null);

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
    // Pre-generate a key so it's ready on first spin
    _pregenKey();
  }

  @override
  void dispose() {
    for (final t in _spinTimers) {
      t?.cancel();
    }
    _handleCtrl.dispose();
    super.dispose();
  }

  void _pregenKey() {
    final result = KeyGenerator.generate();
    _nsec = result.nsec;
    _targetParts = result.parts;
  }

  void _spin() {
    if (_isSpinning) return;

    // Generate fresh key for this spin
    final result = KeyGenerator.generate();
    _nsec = result.nsec;
    _targetParts = result.parts;

    setState(() {
      _isSpinning = true;
    });

    // Cancel any previous timers
    for (final t in _spinTimers) {
      t?.cancel();
    }

    for (int i = 0; i < 12; i++) {
      final index = i;
      final charLen = i < 9 ? 5 : 6;
      final targetValue = _targetParts[index];

      // Staggered start: 100ms per slot
      Future.delayed(Duration(milliseconds: index * 100), () {
        if (!mounted) return;

        // Rapid random spin for 2000ms
        _spinTimers[index] = Timer.periodic(
          const Duration(milliseconds: 50),
          (t) {
            if (!mounted) {
              t.cancel();
              return;
            }
            setState(() {
              _displayParts[index] = _randomChunk(charLen);
            });
          },
        );

        // Stop spinning and settle after 2000ms
        Future.delayed(const Duration(milliseconds: 2000), () {
          _spinTimers[index]?.cancel();
          _spinTimers[index] = null;
          if (!mounted) return;
          _settleSlot(index, targetValue, charLen);
        });
      });
    }

    // Total duration = 2000ms spin + 11*100ms stagger + 300ms settle buffer
    const totalMs = 2000 + 11 * 100 + 300;
    Future.delayed(const Duration(milliseconds: totalMs), () {
      if (!mounted) return;
      setState(() {
        _isSpinning = false;
      });
      Future.delayed(widget.completeDelay, () {
        if (mounted) widget.onSpinComplete?.call(_nsec);
      });
    });
  }

  void _settleSlot(int index, String target, int charLen) {
    int count = 0;
    _spinTimers[index] = Timer.periodic(
      const Duration(milliseconds: 60),
      (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        count++;
        if (count >= 4) {
          t.cancel();
          _spinTimers[index] = null;
          setState(() => _displayParts[index] = target);
        } else {
          setState(() => _displayParts[index] = _randomChunk(charLen));
        }
      },
    );
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
    final text = _displayParts[index];
    final isPlaceholder = text.startsWith('---');

    return SizedBox(
      width: 64,
      height: _diskHeight,
      child: Container(
        color: c.white16,
        child: Center(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: c.black33, width: 0.33),
              ),
            ),
            child: Center(
              child: isPlaceholder
                  ? Container(
                      width: 24,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.white33,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
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
          // Slot cells
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
          // Top fade
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
          // Bottom fade
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
          // Handle slot (fixed groove)
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
          // Handle bar (stretches from center to ball).
          // When the ball is above center: white at the top (ball) → transparent
          // at the bottom (center). When below center: flip the gradient so white
          // is at the bottom (ball) → transparent at the top (center).
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
          // Draggable blurple ball
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
