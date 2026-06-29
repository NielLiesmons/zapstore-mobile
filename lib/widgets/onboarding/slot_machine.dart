import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/key_generator.dart';
import 'package:zapstore/widgets/onboarding/secret_key_actions.dart';

// Port of zaplab_design `LabSlotMachine` (Nsec mode) — layout + motion source of truth.

const _bech32Chars = 'QPZRY9X8GF2TVDW0S3JN54KHCE6MUA7L';

/// Width of the four-disk reel grid inside [SpinKeySlotMachine].
const double kSpinKeySlotGridWidth = 252.0;

/// Extra width from 0.33px borders on disk rows.
const double _kSpinKeyBorderSlack = 1.0;

/// Revealed panel width — grid plus finale [SpinKeySlotMachine] padding.
const double kSpinKeyRevealedPanelWidth =
    kSpinKeySlotGridWidth + _kSpinKeyBorderSlack + 20.0;

/// Grid + gap + handle (+ slack for row borders).
const double kSpinKeyActiveRowWidth =
    kSpinKeySlotGridWidth + _kSpinKeyBorderSlack + 16 + 48;

const _totalHeight = 296.0;
const _rowGap = 16.0;
const _diskWidth = 56.0;
const _diskHeight = 88.0;
const _cellHeight = 56.0;
const _cellInset = (_diskHeight - _cellHeight) / 2;

const _handleMin = 18.0;
const _handleMax = 234.0;
const _handleCenterY = _totalHeight / 2;
const _slotHeight = 88.0;
const _slotTop = (_totalHeight - _slotHeight) / 2;

const _spinDurationMs = 3800;
const _spinStaggerMs = 220;
const _spinSequenceLength = 28;

/// Finale duration — keep in sync with [_SpinKeyMorphFooter].
const kSpinKeyFinaleAnimMs = 520;
const _finaleAnimMs = kSpinKeyFinaleAnimMs;
const _defaultSettleDelay = Duration(milliseconds: 1200);

/// Opacity for nsec symbols in the center viewing window.
const _nsecTextOpacity = 0.8;

int _chunkSizeForSlot(int slotIndex) => slotIndex < 9 ? 5 : 6;

String _placeholderForSlot(int slotIndex) =>
    '-' * _chunkSizeForSlot(slotIndex);

String _randomChunkForSlot(int slotIndex) {
  final rng = Random();
  final size = _chunkSizeForSlot(slotIndex);
  return String.fromCharCodes(
    List.generate(
      size,
      (_) => _bech32Chars.codeUnitAt(rng.nextInt(_bech32Chars.length)),
    ),
  );
}

/// Gentle ramp → long slowdown → overshoot past target, then elastic settle.
class _SlotSpinCurve extends Curve {
  @override
  double transform(double t) {
    // 0–48%: slow elastic take-off from rest
    if (t < 0.48) {
      final rampT = t / 0.48;
      return pow(rampT, 2.6) * 0.34;
    }
    // 48–76%: steady spin
    if (t < 0.76) {
      final midT = (t - 0.48) / 0.28;
      return 0.34 + 0.46 * midT;
    }
    // 76–86%: heavy deceleration into the target lane
    if (t < 0.86) {
      final slowT = (t - 0.76) / 0.10;
      return 0.80 + 0.16 * (1 - pow(1 - slowT, 5));
    }
    // 86–100%: roll past the stop, then wobble back to 1.0
    final settleT = (t - 0.86) / 0.14;
    final decay = pow(1 - settleT, 1.35);
    final wobble = sin(settleT * pi * 1.1) * 0.24 * decay;
    return 0.96 + 0.04 * settleT + wobble;
  }
}

class SpinKeySlotMachine extends StatefulWidget {
  const SpinKeySlotMachine({
    super.key,
    this.initialNsec,
    this.onNsecReady,
    this.onSettled,
    this.settleDelay = _defaultSettleDelay,
    this.onFinaleStarted,
    this.onFinaleComplete,
  });

  final String? initialNsec;
  final void Function(String nsec)? onNsecReady;

  /// Fired after all reels stop and [settleDelay] has elapsed.
  final void Function(String nsec)? onSettled;
  final Duration settleDelay;

  /// Fired when the handle-out / panel-in finale begins (title + footer swap).
  final VoidCallback? onFinaleStarted;

  /// Called once the handle-out / panel-in finale animation completes.
  final VoidCallback? onFinaleComplete;

  @override
  State<SpinKeySlotMachine> createState() => SpinKeySlotMachineState();
}

class SpinKeySlotMachineState extends State<SpinKeySlotMachine>
    with TickerProviderStateMixin {
  static const _slotCount = 12;

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  final List<String> _displayValues =
      List.generate(_slotCount, _placeholderForSlot);
  final List<List<String>> _spinSequences =
      List.generate(_slotCount, (_) => <String>[]);

  String _nsec = '';
  List<String> _targetParts =
      List.generate(_slotCount, _placeholderForSlot);

  bool _isSpinning = false;
  bool _hasSpun = false;
  int _spinGeneration = 0;
  double _handleOffset = _handleMin;
  bool _isDragging = false;
  bool _finalePlayed = false;

  late final AnimationController _handleCtrl;
  late Animation<double> _handleAnim;
  late final AnimationController _finaleCtrl;
  late final Animation<double> _finaleAnim;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _slotCount,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: _spinDurationMs),
      ),
    );
    _animations = List.generate(
      _slotCount,
      (i) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controllers[i], curve: _SlotSpinCurve()),
      ),
    );
    _handleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _handleCtrl.addListener(() {
      if (mounted && _handleCtrl.isAnimating) {
        setState(() => _handleOffset = _handleAnim.value);
      }
    });
    _finaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _finaleAnimMs),
    );
    _finaleAnim = CurvedAnimation(
      parent: _finaleCtrl,
      curve: Curves.easeInOutCubic,
    );
    _finaleCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.initialNsec != null && widget.initialNsec!.isNotEmpty) {
      _applyNsec(widget.initialNsec!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onNsecReady?.call(_nsec);
      });
    } else {
      final result = KeyGenerator.generate();
      _applyNsec(result.nsec);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onNsecReady?.call(_nsec);
      });
    }
  }

  void _applyNsec(String nsec) {
    _nsec = nsec;
    _targetParts = KeyGenerator.splitNsec(nsec);
    for (var i = 0; i < _slotCount; i++) {
      _displayValues[i] = _placeholderForSlot(i);
      _spinSequences[i] = [];
    }
  }

  @visibleForTesting
  double get finaleProgress => _finaleAnim.value;

  @visibleForTesting
  void debugStartFinale() => _startFinaleAnimation();

  void _startFinaleAnimation() {
    if (_finalePlayed || _finaleCtrl.isAnimating) return;
    _finalePlayed = true;
    _finaleCtrl.forward(from: 0).then((_) {
      if (mounted) widget.onFinaleComplete?.call();
    });
    // Notify parent after the first animation tick so a title swap cannot
    // remount this widget before [_finaleCtrl] starts advancing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFinaleStarted?.call();
    });
  }

  @override
  void dispose() {
    _spinGeneration++;
    for (final c in _controllers) {
      c.stop();
      c.dispose();
    }
    _handleCtrl.dispose();
    _finaleCtrl.dispose();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning || _hasSpun) return;
    final generation = ++_spinGeneration;
    setState(() {
      _isSpinning = true;
      _hasSpun = true;
    });

    var finished = 0;

    for (var i = 0; i < _slotCount; i++) {
      Future.delayed(Duration(milliseconds: i * _spinStaggerMs), () {
        if (!mounted || generation != _spinGeneration || !_isSpinning) return;

        final firstRandom = _randomChunkForSlot(i);
        final sequence = <String>[
          _displayValues[i],
          firstRandom,
          ...List<String>.generate(
            _spinSequenceLength - 1,
            (_) => _randomChunkForSlot(i),
          ),
          _targetParts[i],
        ];

        setState(() => _spinSequences[i] = sequence);

        _controllers[i].duration =
            const Duration(milliseconds: _spinDurationMs);
        _controllers[i].reset();
        _animations[i] = Tween<double>(
          begin: 0,
          end: (sequence.length - 1).toDouble(),
        ).animate(
          CurvedAnimation(
            parent: _controllers[i],
            curve: _SlotSpinCurve(),
          ),
        );

        _controllers[i].forward().then((_) {
          if (!mounted || generation != _spinGeneration) return;
          setState(() {
            _displayValues[i] = _targetParts[i];
            _spinSequences[i] = [_targetParts[i]];
          });
          finished++;
          if (finished >= _slotCount) {
            setState(() => _isSpinning = false);
            Future.delayed(widget.settleDelay, () {
              if (!mounted || generation != _spinGeneration) return;
              widget.onSettled?.call(_nsec);
              _startFinaleAnimation();
            });
          }
        });
      });
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_isDragging || _isSpinning || _hasSpun) return;
    setState(() {
      _handleOffset =
          (_handleOffset + d.delta.dy).clamp(_handleMin, _handleMax);
    });
  }

  void _onDragEnd(DragEndDetails _) {
    if (!_isDragging) return;
    setState(() => _isDragging = false);
    if (_handleOffset > _handleCenterY + 24) _spin();
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

  double _fontSizeForSlot(int diskIndex) =>
      _chunkSizeForSlot(diskIndex) <= 5 ? 13.0 : 12.0;

  Widget _buildCell(LabColors c, int diskIndex, String text) {
    final isPlaceholder = RegExp(r'^-+$').hasMatch(text);
    return SizedBox(
      width: _diskWidth,
      height: _cellHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.black33, width: 0.33),
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
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: _fontSizeForSlot(diskIndex),
                        fontWeight: FontWeight.w600,
                        color: c.white,
                        letterSpacing: -0.3,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  String _textAt(int diskIndex, int sequenceIndex) {
    final seq = _spinSequences[diskIndex];
    if (seq.isEmpty) return _displayValues[diskIndex];
    if (sequenceIndex < 0) {
      // Above the resting index: show the first random entering from the top,
      // not the placeholder clamped to seq.first.
      return seq.length > 1 ? seq[1] : seq.first;
    }
    if (sequenceIndex >= seq.length) return seq.last;
    return seq[sequenceIndex];
  }

  /// Fade + squash symbols as they move away from the reel center — mimics a
  /// curved drum receding in Z.
  Widget _buildPositionedCell(
    LabColors c,
    int diskIndex,
    String text,
    double top,
  ) {
    final diskCenterY = _diskHeight / 2;
    final cellCenterY = top + _cellHeight / 2;
    final dist = (cellCenterY - diskCenterY).abs();
    final t = (dist / _cellHeight).clamp(0.0, 1.0);
    final opacity = _nsecTextOpacity * (1 - 0.72 * t);
    final scaleY = 1.0 - 0.32 * t;
    final pushTowardCenter =
        cellCenterY < diskCenterY ? 4.0 * t : -4.0 * t;

    return Positioned(
      top: top + pushTowardCenter,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scaleY: scaleY,
          alignment: Alignment.center,
          child: _buildCell(c, diskIndex, text),
        ),
      ),
    );
  }

  Widget _buildDisk(LabColors c, int diskIndex) {
    return SizedBox(
      width: _diskWidth,
      height: _diskHeight,
      child: ColoredBox(
        color: c.white16,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _animations[diskIndex],
            builder: (context, _) {
              final controller = _controllers[diskIndex];
              final seq = _spinSequences[diskIndex];

              if (seq.isEmpty || (seq.length <= 1 && !controller.isAnimating)) {
                final text = _displayValues[diskIndex];
                const offset = _cellInset;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    _buildPositionedCell(
                      c,
                      diskIndex,
                      text,
                      offset - _cellHeight,
                    ),
                    _buildPositionedCell(c, diskIndex, text, offset),
                    _buildPositionedCell(
                      c,
                      diskIndex,
                      text,
                      offset + _cellHeight,
                    ),
                  ],
                );
              }

              final value = _animations[diskIndex].value;
              final currentIndex = value.floor();
              // Positive scroll: symbols enter from above, exit below.
              final offset = (value % 1.0) * _cellHeight + _cellInset;

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  _buildPositionedCell(
                    c,
                    diskIndex,
                    _textAt(diskIndex, currentIndex - 1),
                    offset - _cellHeight,
                  ),
                  _buildPositionedCell(
                    c,
                    diskIndex,
                    _textAt(diskIndex, currentIndex),
                    offset,
                  ),
                  _buildPositionedCell(
                    c,
                    diskIndex,
                    _textAt(diskIndex, currentIndex + 1),
                    offset + _cellHeight,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDiskRow(LabColors c, int rowIndex) {
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 8),
              _buildDisk(c, rowIndex * 4 + 0),
              const SizedBox(width: 4),
              _buildDisk(c, rowIndex * 4 + 1),
              const SizedBox(width: 4),
              _buildDisk(c, rowIndex * 4 + 2),
              const SizedBox(width: 4),
              _buildDisk(c, rowIndex * 4 + 3),
              const SizedBox(width: 8),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 28,
            child: DecoratedBox(
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
            height: 28,
            child: DecoratedBox(
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
    const baseCircleSize = 44.0;
    const circleGrowth = 6.0;
    final handleBarLength = _totalHeight / 2 - 40;

    final isBottomHalf = _handleOffset > _handleCenterY;
    final progress = isBottomHalf
        ? (_handleOffset - _handleCenterY) / (_handleMax - _handleCenterY)
        : (_handleOffset - _handleMin) / (_handleCenterY - _handleMin);

    final distanceFromCenter = (_handleOffset - _handleCenterY).abs();
    final maxDistanceFromCenter = _handleCenterY - _handleMin;
    final circleProgress =
        1.0 - (distanceFromCenter / maxDistanceFromCenter).clamp(0.0, 1.0);
    final circleSize = baseCircleSize + circleGrowth * circleProgress;
    final circleSizeOffset = (circleSize - baseCircleSize) / 2;

    double barHeight;
    double barTop;
    var isFlipped = false;

    if (isBottomHalf) {
      barHeight = handleBarLength * progress;
      barTop = _handleCenterY + (256 - _handleCenterY) * progress;
      isFlipped = true;
    } else {
      barHeight = handleBarLength * (1 - progress);
      barTop = 40 + (_handleCenterY - 40) * progress;
    }

    return SizedBox(
      width: 48,
      height: _totalHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 8,
            top: _slotTop,
            child: Container(
              width: 32,
              height: _slotHeight,
              decoration: BoxDecoration(
                color: const Color(0x88000000),
                borderRadius: BorderRadius.circular(16),
                border: LabBorder.all(color: c.white16, width: 0.33),
              ),
            ),
          ),
          if (barHeight > 0)
            Positioned(
              left: 16,
              top: barTop,
              child: Transform.scale(
                scaleY: isFlipped ? -1 : 1,
                alignment: Alignment.topCenter,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFF232323),
                      Color(0x00000000),
                    ],
                    stops: [0.5, 0.66, 1],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: Container(
                    width: 16,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9696A3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            c.black16,
                            c.black8,
                          ],
                          stops: const [0.33, 0.80, 1.0],
                        ),
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
              onVerticalDragStart: (_) {
                if (_hasSpun) return;
                setState(() => _isDragging = true);
              },
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
                child: const DecoratedBox(
                  decoration: BoxDecoration(
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

  Widget _buildDiskGrid(LabColors c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDiskRow(c, 0),
        const SizedBox(height: _rowGap),
        _buildDiskRow(c, 1),
        const SizedBox(height: _rowGap),
        _buildDiskRow(c, 2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final t = _finaleAnim.value;
    final handleT = (1 - t).clamp(0.0, 1.0);
    final handleWidth = 48.0 * handleT;
    final handleGap = 16.0 * handleT;
    final handleInteractive = !_isSpinning && !_hasSpun && t <= 0;

    final gridPanel = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color.lerp(Colors.transparent, c.white8, t),
      ),
      padding: EdgeInsets.all(10 * t),
      child: _buildDiskGrid(c),
    );

    final reelRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        gridPanel,
        SizedBox(width: handleGap),
        if (handleT > 0.001)
          SizedBox(
            width: max(handleWidth, 0),
            height: _totalHeight,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: handleT,
                child: Opacity(
                  opacity: handleT,
                  child: IgnorePointer(
                    ignoring: !handleInteractive,
                    child: _buildHandle(c),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final rowWidth = kSpinKeyActiveRowWidth +
        (kSpinKeyRevealedPanelWidth - kSpinKeyActiveRowWidth) * t;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: rowWidth,
          child: Center(child: reelRow),
        ),
        if (_finalePlayed || t > 0)
          Padding(
            padding: EdgeInsets.only(top: 16 * t),
            child: SizedBox(
              width: kSpinKeyRevealedPanelWidth,
              child: SecretKeyActionsRow(nsec: _nsec, revealT: t),
            ),
          ),
      ],
    );
  }
}
