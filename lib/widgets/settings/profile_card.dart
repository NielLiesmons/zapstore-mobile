import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/profile_pic.dart';

/// Active (currently selected) profile card.
///
/// Matches the LabActivePorfileCard layout: gray66 background, no border,
/// avatar + name/npub row at top, View/Edit/Share buttons at the bottom.
class ActiveProfileCard extends HookWidget {
  const ActiveProfileCard({
    super.key,
    this.profile,
    required this.pubkey,
    this.onViewProfile,
    this.onEditProfile,
    this.onShareProfile,
  });

  final Profile? profile;
  final String pubkey;
  final VoidCallback? onViewProfile;
  final VoidCallback? onEditProfile;
  final VoidCallback? onShareProfile;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final pressed = useState(false);

    final name = _displayName(profile, pubkey);
    final sub = profile?.nip05 != null && profile!.nip05!.isNotEmpty
        ? profile!.nip05!
        : _truncNpub(pubkey);

    return GestureDetector(
      onTapDown: (_) => pressed.value = true,
      onTapUp: (_) {
        pressed.value = false;
        onViewProfile?.call();
      },
      onTapCancel: () => pressed.value = false,
      child: AnimatedScale(
        scale: pressed.value ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 272,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.gray66,
            borderRadius: BorderRadius.circular(LabRadius.r20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Center(
                      child: ProfilePic(profile: profile, pubkey: pubkey, size: 48),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: LabTextStyles.semibold17
                              .copyWith(color: c.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: LabTextStyles.reg13.copyWith(color: c.white33),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  if (profile != null) ...[
                    _PillButton(
                      label: 'View',
                      onTap: onViewProfile,
                    ),
                    const SizedBox(width: 12),
                    _PillButton(
                      label: 'Edit',
                      onTap: onEditProfile,
                    ),
                    const Spacer(),
                    _PillIconButton(
                      icon: LabIcons.share,
                      onTap: onShareProfile,
                    ),
                  ] else
                    _PillButton(
                      label: 'Reload',
                      onTap: onViewProfile,
                      emphasized: true,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Non-active profile card — matching LabOtherProfileCard layout.
///
/// gray33 background + gray border, fixed height matching add-profile card.
class OtherProfileCard extends HookWidget {
  const OtherProfileCard({
    super.key,
    this.profile,
    required this.pubkey,
    this.onSelect,
    this.onShareProfile,
    this.onViewProfile,
  });

  final Profile? profile;
  final String pubkey;
  final VoidCallback? onSelect;
  final VoidCallback? onShareProfile;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final pressed = useState(false);

    final name = _displayName(profile, pubkey);
    final sub = profile?.nip05 != null && profile!.nip05!.isNotEmpty
        ? profile!.nip05!
        : _truncNpub(pubkey);

    return GestureDetector(
      onTapDown: (_) => pressed.value = true,
      onTapUp: (_) {
        pressed.value = false;
        onSelect?.call();
      },
      onTapCancel: () => pressed.value = false,
      child: AnimatedScale(
        scale: pressed.value ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 256,
          height: 148,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.gray33,
            borderRadius: BorderRadius.circular(LabRadius.r20),
            border: LabBorder.all(
              color: c.gray,
              width: LabStroke.medium,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Center(
                      child: ProfilePic(profile: profile, pubkey: pubkey, size: 48),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: LabTextStyles.semibold15
                              .copyWith(color: c.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: LabTextStyles.reg13.copyWith(color: c.white33),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _PillButton(label: 'Select', onTap: onSelect),
                  const Spacer(),
                  if (profile != null)
                    _PillIconButton(
                      icon: LabIcons.share,
                      onTap: onShareProfile,
                    )
                  else
                    Text(
                      'Profile not found',
                      style: LabTextStyles.reg13.copyWith(color: c.white33),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card for adding a new profile — same height as [OtherProfileCard], never square.
///
/// Matches the zaplab_design add-profile card: left-aligned circle icon + label.
class AddProfileCard extends HookWidget {
  const AddProfileCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final pressed = useState(false);

    return GestureDetector(
      onTapDown: (_) => pressed.value = true,
      onTapUp: (_) {
        pressed.value = false;
        onTap?.call();
      },
      onTapCancel: () => pressed.value = false,
      child: AnimatedScale(
        scale: pressed.value ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 256,
          height: 148,
          padding: const EdgeInsets.all(16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: c.gray33,
            borderRadius: BorderRadius.circular(LabRadius.r20),
            border: LabBorder.all(
              color: c.gray,
              width: LabStroke.medium,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.white8,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: LabIcon(
                    LabIcons.plus,
                    size: 16,
                    color: c.white33,
                    thick: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Add Profile',
                style: LabTextStyles.med15.copyWith(color: c.white33),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Internal button helpers ──────────────────────────────────────────────────

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    this.onTap,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: emphasized ? c.blurple : null,
          color: emphasized ? null : c.white8,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: LabTextStyles.med13.copyWith(
              color: emphasized ? c.whiteEnforced : c.white66,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({required this.icon, this.onTap});

  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: c.white8,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: LabIcon(icon, size: 15, color: c.white33),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _displayName(Profile? profile, String pubkey) {
  final name = profile?.name?.trim();
  if (name != null && name.isNotEmpty) return name;
  return _truncNpub(pubkey);
}

String _truncNpub(String hex) => hex.length >= 12
    ? '${hex.substring(0, 8)}…${hex.substring(hex.length - 4)}'
    : hex;
