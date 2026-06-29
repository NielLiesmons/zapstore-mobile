import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zapstore/main.dart';
import 'package:zapstore/services/notification_service.dart';
import 'package:zapstore/utils/debug_utils.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a modal that detects installed Nostr signer apps and offers fallback
/// options (Secret Key, Nostr Connect — UI active, flows coming soon).
Future<void> showUseExistingKeyModal(BuildContext context) {
  return showModal<void>(
    context,
    title: 'Add Existing Profile',
    builder: (_) => const _UseExistingKeyContent(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Content
// ─────────────────────────────────────────────────────────────────────────────

enum _CheckState { checking, signerFound, noneFound }

class _UseExistingKeyContent extends ConsumerStatefulWidget {
  const _UseExistingKeyContent();

  @override
  ConsumerState<_UseExistingKeyContent> createState() =>
      _UseExistingKeyContentState();
}

class _UseExistingKeyContentState
    extends ConsumerState<_UseExistingKeyContent> {
  _CheckState _state = _CheckState.checking;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _checkSigners();
  }

  Future<void> _checkSigners() async {
    final startTime = DateTime.now();
    bool found = false;

    if (Platform.isAndroid) {
      try {
        final isAvailable = await ref.read(amberSignerProvider).isAvailable;
        if (mounted && isAvailable) {
          found = true;
          setState(() => _state = _CheckState.signerFound);
        }
      } catch (_) {}
    }
    // iOS / other platforms: add checks here when signers become available.

    if (!found) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed < 2000) {
        await Future.delayed(Duration(milliseconds: 2000 - elapsed));
      }
      if (mounted && _state == _CheckState.checking) {
        setState(() => _state = _CheckState.noneFound);
      }
    }
  }

  Future<void> _signInWithAmber() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    try {
      await ref.read(amberSignerProvider).signIn();
      await onSignInSuccess(ref.read(refProvider));
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        context.showError('Sign in failed', technicalDetails: '$e');
        setState(() => _isSigningIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kModalInset, 0, kModalInset, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Signer detection panel ──────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: c.black33,
              borderRadius: BorderRadius.circular(LabRadius.r20),
              border: LabBorder.all(color: c.gray, width: LabStroke.medium),
            ),
            padding: const EdgeInsets.all(16),
            child: _buildDetectionBody(c),
          ),

          const SizedBox(height: 12),

          // ── Bottom options (Secret Key / Nostr Connect) ─────────────────────
          Row(
            children: [
              Expanded(
                child: _OptionTile(
                  icon: LabIcons.key,
                  title: 'Secret Key',
                  subtitle: 'Enter your nsec',
                  onTap: () {
                    // TODO: navigate to nsec paste screen
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OptionTile(
                  icon: LabIcons.nostr,
                  title: 'Nostr Connect',
                  subtitle: 'Paste a bunker link',
                  onTap: () {
                    // TODO: navigate to Nostr Connect screen
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionBody(LabColors c) {
    switch (_state) {
      case _CheckState.checking:
        return SizedBox(
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LoadingDots(color: c.white66),
              const SizedBox(height: 10),
              Text(
                'Checking for signer apps…',
                style: LabTextStyles.reg13.copyWith(color: c.white33),
              ),
            ],
          ),
        );

      case _CheckState.signerFound:
        return Row(
          children: [
            // Amber app icon
            ClipRRect(
              borderRadius: BorderRadius.circular(LabRadius.r11),
              child: Image.asset(
                'assets/images/amber.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amber',
                    style: LabTextStyles.semibold15.copyWith(color: c.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Signer app detected!',
                    style: LabTextStyles.reg13.copyWith(color: c.white66),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            LabButton.primarySmall(
              onTap: _isSigningIn ? null : _signInWithAmber,
              child: _isSigningIn
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.whiteEnforced,
                      ),
                    )
                  : Text(
                      'Use',
                      style: LabTextStyles.med15.copyWith(
                        color: c.whiteEnforced,
                      ),
                    ),
            ),
          ],
        );

      case _CheckState.noneFound:
        return SizedBox(
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: c.white16,
                  borderRadius: BorderRadius.circular(LabRadius.r11),
                ),
                child: Text(
                  'None detected',
                  style: LabTextStyles.med13.copyWith(color: c.white66),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No signer apps found on this device.',
                style: LabTextStyles.reg13.copyWith(color: c.white33),
              ),
            ],
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option tile (Secret Key / Nostr Connect)
// ─────────────────────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: c.black33,
          borderRadius: BorderRadius.circular(LabRadius.r20),
          border: LabBorder.all(color: c.gray, width: LabStroke.medium),
        ),
        child: Column(
          children: [
            LabIcon(
              icon,
              size: 32,
              color: c.white33,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: LabTextStyles.semibold15.copyWith(color: c.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: LabTextStyles.reg13.copyWith(color: c.white66),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated loading dots
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingDots extends StatefulWidget {
  const _LoadingDots({required this.color});
  final Color color;

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t - i * 0.2).clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * (1 - (phase * 2 - 1).abs());
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
