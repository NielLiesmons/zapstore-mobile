import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/services/app_restart_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:purplebase/purplebase.dart';
import 'package:zapstore/main.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/services/settings_service.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/nostr_route.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/base_dialog.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/modal.dart';
import 'package:zapstore/widgets/common/stack_link_card.dart';
import 'package:zapstore/widgets/common/top_scroll_fader.dart';
import 'package:zapstore/services/notification_service.dart';
import 'package:zapstore/widgets/nwc_widgets.dart';
import 'package:zapstore/widgets/relay_management_card.dart';
import 'package:zapstore/screens/app_stacks_screen.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/providers/theme_mode.dart';
import 'package:zapstore/services/local_signer_service.dart';
import 'package:zapstore/utils/text_scale.dart';
import 'package:zapstore/widgets/common/selector.dart';
import 'package:zapstore/widgets/onboarding/onboarding_flow.dart';
import 'package:zapstore/widgets/settings/profile_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfilesScreen — active profile card + settings list
// ─────────────────────────────────────────────────────────────────────────────

class ProfilesScreen extends HookConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final topPad = MediaQuery.paddingOf(context).top;
    final headerHeight = topPad + 48.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TopScrollFader(
              scrollController: scrollController,
              fadeStart: headerHeight,
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.only(
                  top: headerHeight + 10,
                  bottom: MediaQuery.paddingOf(context).bottom + 32,
                ),
                children: [
                  const _ProfileContent(),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ProfileHeader(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixed floating header
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final topPad = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: c.black.withValues(alpha: 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: topPad + 9),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Settings',
                      style: LabTextStyles.semibold23.copyWith(color: c.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main content — dispatches on sign-in state
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePubkey = ref.watch(Signer.activePubkeyProvider);

    if (activePubkey == null) {
      return const _SignedOutContent();
    }

    return _SignedInContent(activePubkey: activePubkey);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Signed-in layout — profile cards + settings + disconnect
// ─────────────────────────────────────────────────────────────────────────────

class _SignedInContent extends ConsumerWidget {
  const _SignedInContent({required this.activePubkey});

  final String activePubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    // Load profile for disconnect confirmation
    final profileState = ref.watch(
      query<Profile>(
        authors: {activePubkey},
        limit: 1,
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          stream: false,
          cachedFor: Duration(hours: 2),
        ),
        subscriptionPrefix: 'profile-screen-active',
      ),
    );
    final activeProfile = profileState.models.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // ── Full-width divider above cards ──────────────────────────────────
        Container(height: LabStroke.medium, color: c.white8),

        // ── Active profile (single account) ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: ActiveProfileCard(
            fullWidth: true,
            profile: activeProfile,
            pubkey: activePubkey,
            onViewProfile: () =>
                context.push('/profile/user/$activePubkey'),
          ),
        ),

        // ── Full-width divider below cards ──────────────────────────────────
        Container(height: LabStroke.medium, color: c.white8),

        // ── Settings list (full-width, dividers edge-to-edge) ───────────────
        _SettingsList(activePubkey: activePubkey),

        const SizedBox(height: 14),

        // ── Disconnect Profile ──────────────────────────────────────────────
        _DisconnectButton(
          activePubkey: activePubkey,
          activeProfile: activeProfile,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings list — full-width rows with hairline dividers, no panel background
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.activePubkey});

  final String activePubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? AppThemeMode.dark;
    final textScale =
        ref.watch(textScalePresetProvider).valueOrNull ?? TextScalePreset.normal;

    final themeName = switch (themeMode) {
      AppThemeMode.system => 'System',
      AppThemeMode.light  => 'Light',
      AppThemeMode.dark   => 'Dark',
      AppThemeMode.black  => 'Black',
    };
    final scaleName = switch (textScale) {
      TextScalePreset.small => 'Small text',
      TextScalePreset.normal => 'Normal text',
      TextScalePreset.large => 'Large text',
    };

    final items = [
      _SettingsItemData(
        icon: LabIcons.zap,
        iconGradient: c.gold,
        title: 'Wallet',
        description: 'Lightning wallet connection',
        onTap: () => showModal(
          context,
          title: 'Wallet',
          builder: (_) => const _WalletModalContent(),
        ),
      ),
      _SettingsItemData(
        icon: LabIcons.appearance,
        iconGradient: c.graydient66,
        title: 'Preferences',
        description: '$themeName · $scaleName',
        onTap: () => showModal(
          context,
          title: 'Preferences',
          builder: (_) => const _PreferencesModalContent(),
        ),
      ),
      _SettingsItemData(
        icon: LabIcons.security,
        iconGradient: c.blurple,
        title: 'Security',
        description: 'Signer, keys, backups',
        onTap: () => showModal(
          context,
          title: 'Security',
          builder: (_) => const _SecurityModalContent(),
        ),
      ),
      _SettingsItemData(
        icon: LabIcons.backup,
        iconGradient: c.blurple66,
        title: 'Hosting & Backups',
        description: 'Relays, data, stacks',
        onTap: () => showModal(
          context,
          title: 'Hosting & Backups',
          builder: (_) => _HostingModalContent(pubkey: activePubkey),
        ),
      ),
      _SettingsItemData(
        icon: LabIcons.info,
        iconColor: c.white33,
        title: 'Help & Support',
        description: 'About, version, debug',
        onTap: () => showModal(
          context,
          title: 'Help & Support',
          builder: (_) => const _HelpModalContent(),
        ),
      ),
      _SettingsItemData(
        icon: LabIcons.crown,
        iconGradient: c.gold,
        title: 'Zapstore Pro',
        description: 'Unlock premium features',
        onTap: () => showModal(
          context,
          title: 'Zapstore Pro',
          builder: (_) => const _ZapstoreProModalContent(),
        ),
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(height: LabStroke.medium, color: c.white8),
          _SettingsItem(data: items[i]),
        ],
        Container(height: LabStroke.medium, color: c.white8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single settings row
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsItemData {
  const _SettingsItemData({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.iconGradient,
    this.iconColor,
  });

  final String icon;
  final Gradient? iconGradient;
  final Color? iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;
}

class _SettingsItem extends StatefulWidget {
  const _SettingsItem({required this.data});

  final _SettingsItemData data;

  @override
  State<_SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<_SettingsItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final d = widget.data;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        d.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressed ? c.white4 : Colors.transparent,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon square — all items share gray66 bg, only icon differs
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: c.gray66,
                borderRadius: BorderRadius.circular(LabRadius.r12),
              ),
              child: Center(
                child: d.iconGradient != null
                    ? LabIcon(d.icon, size: 22, gradient: d.iconGradient)
                    : LabIcon(d.icon, size: 22,
                        color: d.iconColor ?? c.white66),
              ),
            ),

            const SizedBox(width: 14),

            // Title + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.title,
                    style: LabTextStyles.med15.copyWith(color: c.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.description,
                    style: LabTextStyles.reg13.copyWith(color: c.white66),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Disconnect Profile button
// ─────────────────────────────────────────────────────────────────────────────

class _DisconnectButton extends ConsumerWidget {
  const _DisconnectButton({
    required this.activePubkey,
    this.activeProfile,
  });

  final String activePubkey;
  final Profile? activeProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    final label = activeProfile?.name?.trim().isNotEmpty == true
        ? 'Disconnect ${activeProfile!.name}'
        : 'Disconnect Profile';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        width: double.infinity,
        child: LabButton.secondary(
          onTap: () => _confirmDisconnect(context, ref),
          color: c.gray33,
          child: Text(label, style: LabTextStyles.med15.copyWith(color: c.white66)),
        ),
      ),
    );
  }

  Future<void> _confirmDisconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirm(
      context,
      title: 'Disconnect Profile',
      message: 'This will sign you out. Your keys and data remain on your device.',
      confirmLabel: 'Disconnect',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      try {
        await ref.read(localSignerServiceProvider).clearNsec();
        await ref.read(amberSignerProvider).signOut();
        if (context.mounted) context.go('/');
      } catch (e) {
        if (context.mounted) {
          context.showError('Sign out failed', technicalDetails: '$e');
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Signed-out content
// ─────────────────────────────────────────────────────────────────────────────

/// Signed-out layout — mirrors the signed-in structure but without a profile.
///
/// Shows a full-width (non-scrollable) "Add Profile" card where the horizontal
/// cards row would be, plus the settings that are available without an account
/// (Preferences, Help & Support).
class _SignedOutContent extends ConsumerWidget {
  const _SignedOutContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // ── Full-width "Add Profile" card — identical to the in-row card ─────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: AddProfileCard(
            fullWidth: true,
            onTap: () => launchProfileOnboarding(context, ref),
          ),
        ),

        const SizedBox(height: 20),

        // ── Full-width divider ────────────────────────────────────────────────
        Container(height: LabStroke.medium, color: c.white8),

        // ── Settings available without a profile (full-width) ─────────────────
        _SignedOutSettingsList(),
      ],
    );
  }
}

/// Subset of settings accessible without a signed-in profile.
class _SignedOutSettingsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? AppThemeMode.dark;
    final textScale =
        ref.watch(textScalePresetProvider).valueOrNull ?? TextScalePreset.normal;

    final themeName = switch (themeMode) {
      AppThemeMode.system => 'System',
      AppThemeMode.light  => 'Light',
      AppThemeMode.dark   => 'Dark',
      AppThemeMode.black  => 'Black',
    };
    final scaleName = switch (textScale) {
      TextScalePreset.small => 'Small text',
      TextScalePreset.normal => 'Normal text',
      TextScalePreset.large => 'Large text',
    };

    final items = [
      _SettingsItemData(
        icon: LabIcons.appearance,
        iconGradient: c.graydient66,
        title: 'Preferences',
        description: '$themeName · $scaleName',
        onTap: () => showModal(
          context,
          title: 'Preferences',
          builder: (_) => const _PreferencesModalContent(),
        ),
      ),
      _SettingsItemData(
        icon: LabIcons.info,
        iconColor: c.white33,
        title: 'Help & Support',
        description: 'About, version, debug',
        onTap: () => showModal(
          context,
          title: 'Help & Support',
          builder: (_) => const _HelpModalContent(),
        ),
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(height: LabStroke.medium, color: c.white8),
          _SettingsItem(data: items[i]),
        ],
        Container(height: LabStroke.medium, color: c.white8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal content widgets
// ─────────────────────────────────────────────────────────────────────────────

// Wallet ──────────────────────────────────────────────────────────────────────

class _WalletModalContent extends StatelessWidget {
  const _WalletModalContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: NWCConnectionCard(),
    );
  }
}

// Preferences ─────────────────────────────────────────────────────────────────

class _PreferencesModalContent extends ConsumerWidget {
  const _PreferencesModalContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;

    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? AppThemeMode.dark;
    final textScale =
        ref.watch(textScalePresetProvider).valueOrNull ?? TextScalePreset.normal;

    final themeIndex = themeMode.index; // system=0, light=1, dark=2, black=3
    final scaleIndex = textScale.index; // small=0, normal=1, large=2

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Theme ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              'THEME',
              style: LabTextStyles.eyebrow15.copyWith(color: c.white33),
            ),
          ),
          const SizedBox(height: 7),
          Selector(
            initialIndex: themeIndex,
            dark: true,
            tabs: const [
              SelectorTab(label: 'System'),
              SelectorTab(label: 'Light'),
              SelectorTab(label: 'Dark'),
              SelectorTab(label: 'Black'),
            ],
            onChanged: (index) {
              final mode = AppThemeMode.values[index];
              ref.read(themeModeProvider.notifier).setMode(mode);
            },
          ),

          const SizedBox(height: 24),

          // ── Text Size ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              'TEXT SIZE',
              style: LabTextStyles.eyebrow15.copyWith(color: c.white33),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.black33,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectorButton(
                    dark: true,
                    selected: [
                      Text(
                        'Small',
                        style: LabTextStyles.med13.copyWith(color: c.white),
                      ),
                    ],
                    unselected: [
                      Text(
                        'Small',
                        style: LabTextStyles.med13.copyWith(color: c.white33),
                      ),
                    ],
                    isSelected: scaleIndex == 0,
                    onTap: () => ref
                        .read(textScalePresetProvider.notifier)
                        .setPreset(TextScalePreset.small),
                  ),
                ),
                Expanded(
                  child: SelectorButton(
                    dark: true,
                    selected: [
                      Text(
                        'Normal',
                        style: LabTextStyles.med15.copyWith(color: c.white),
                      ),
                    ],
                    unselected: [
                      Text(
                        'Normal',
                        style: LabTextStyles.med15.copyWith(color: c.white33),
                      ),
                    ],
                    isSelected: scaleIndex == 1,
                    onTap: () => ref
                        .read(textScalePresetProvider.notifier)
                        .setPreset(TextScalePreset.normal),
                  ),
                ),
                Expanded(
                  child: SelectorButton(
                    dark: true,
                    selected: [
                      Text(
                        'Large',
                        style: LabTextStyles.med17.copyWith(color: c.white),
                      ),
                    ],
                    unselected: [
                      Text(
                        'Large',
                        style: LabTextStyles.med17.copyWith(color: c.white33),
                      ),
                    ],
                    isSelected: scaleIndex == 2,
                    onTap: () => ref
                        .read(textScalePresetProvider.notifier)
                        .setPreset(TextScalePreset.large),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Security ────────────────────────────────────────────────────────────────────

class _SecurityModalContent extends ConsumerWidget {
  const _SecurityModalContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: () => launchProfileOnboarding(context, ref),
            icon: const Icon(Icons.vpn_key, size: 16),
            label: const Text('Generate new keypair'),
          ),
          const SizedBox(height: 16),
          Text(
            'Advanced key and signer settings coming soon.',
            style: LabTextStyles.reg15.copyWith(color: c.white66),
          ),
        ],
      ),
    );
  }
}

// Hosting & Backups ───────────────────────────────────────────────────────────

class _HostingModalContent extends StatelessWidget {
  const _HostingModalContent({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        children: [
          _StackMigrationWarning(pubkey: pubkey),
          const SizedBox(height: 8),
          const RelayManagementCard(),
          const SizedBox(height: 16),
          _UserStacksSection(pubkey: pubkey),
          const SizedBox(height: 16),
          const _DataManagementSection(),
        ],
      ),
    );
  }
}

// Help & Support ──────────────────────────────────────────────────────────────

class _HelpModalContent extends StatelessWidget {
  const _HelpModalContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        children: [
          _AboutSection(),
          SizedBox(height: 16),
          _DebugMessagesSection(),
        ],
      ),
    );
  }
}

// Zapstore Pro ────────────────────────────────────────────────────────────────

class _ZapstoreProModalContent extends StatelessWidget {
  const _ZapstoreProModalContent();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Text(
        'Zapstore Pro is coming soon. Stay tuned.',
        style: LabTextStyles.reg15.copyWith(color: c.white66),
      ),
    );
  }
}

// Add Profile ─────────────────────────────────────────────────────────────────

// _AddProfileModalContent is no longer used — the Add Profile card taps
// directly launch the slot-machine onboarding flow via launchProfileOnboarding.

// ─────────────────────────────────────────────────────────────────────────────
// Below: existing private widgets preserved for modal content
// ─────────────────────────────────────────────────────────────────────────────

class _StackMigrationWarning extends ConsumerWidget {
  const _StackMigrationWarning({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.read(packageManagerProvider.notifier).platform;
    final stacksState = ref.watch(
      query<AppStack>(
        authors: {pubkey},
        where: (s) => stackNeedsMigration(s, platform),
        source: LocalAndRemoteSource(relays: {'AppCatalog'}, stream: false),
        subscriptionPrefix: 'app-user-stacks-migration-profile',
      ),
    );

    final count = stacksState.models.length;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: () => pushStacks(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: LabBorder.all(
              color:
                  Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count stack${count == 1 ? '' : 's'} need${count == 1 ? 's' : ''} updating — tap to fix',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: 14,
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstalledAppsBackupToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubkey = ref.watch(Signer.activePubkeyProvider);
    if (pubkey == null) return const SizedBox.shrink();

    final settingsAsync = ref.watch(localSettingsProvider);
    final enabled =
        settingsAsync.valueOrNull?.installedAppsBackupEnabled ?? false;

    return SwitchListTile(
      secondary: CircleAvatar(
        radius: 18,
        backgroundColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        child: Icon(
          Icons.cloud_upload,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: const Text('Back up installed apps'),
      value: enabled,
      contentPadding: EdgeInsets.zero,
      onChanged: (value) async {
        await ref
            .read(settingsServiceProvider)
            .update((s) => s.copyWith(installedAppsBackupEnabled: value));
        ref.invalidate(localSettingsProvider);
      },
    );
  }
}

class _DataManagementSection extends ConsumerWidget {
  const _DataManagementSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Management',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _InstalledAppsBackupToggle(),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor:
                    Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                child: Icon(
                  Icons.delete_sweep,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              title: AutoSizeText(
                'Clear local storage',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                minFontSize: 12,
              ),
              contentPadding: EdgeInsets.zero,
              onTap: () => _showClearAllDataDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearAllDataDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Clear local storage',
      message: 'Clears all cached data and restarts the app. '
          'Your sign-in and wallet connection will be preserved.',
      confirmLabel: 'Clear storage',
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      await _clearAllData(context, ref);
    }
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    try {
      await restartApp();
    } catch (e) {
      if (context.mounted) {
        context.showError('Restart failed', technicalDetails: e.toString());
      }
    }
  }
}

class _UserStacksSection extends ConsumerWidget {
  const _UserStacksSection({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stacksState = ref.watch(
      query<AppStack>(
        authors: {pubkey},
        where: (s) => s.content.isNotEmpty,
        source: const LocalAndRemoteSource(relays: 'AppCatalog', stream: false),
        subscriptionPrefix: 'app-profile-user-stacks',
      ),
    );

    final privateStacks = stacksState.models.toList();
    if (privateStacks.isEmpty) return const SizedBox.shrink();

    privateStacks.sort((a, b) {
      if (a.identifier == kAppBookmarksIdentifier) return -1;
      if (b.identifier == kAppBookmarksIdentifier) return 1;
      if (a.identifier == kInstalledAppsBackupIdentifier) return -1;
      if (b.identifier == kInstalledAppsBackupIdentifier) return 1;
      return (a.name ?? a.identifier).compareTo(b.name ?? b.identifier);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Your Private Stacks',
              style: Theme.of(context).textTheme.headlineSmall),
        ),
        ...privateStacks.asMap().entries.map((entry) {
          final index = entry.key;
          final stack = entry.value;
          final displayName = stack.identifier == kAppBookmarksIdentifier
              ? 'Saved Apps'
              : stack.identifier == kInstalledAppsBackupIdentifier
                  ? 'Installed Apps'
                  : null;
          return Padding(
            padding: EdgeInsets.only(top: index > 0 ? 8 : 0),
            child: StackLinkCard(stack: stack, displayName: displayName),
          );
        }),
      ],
    );
  }
}

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pmState = ref.watch(packageManagerProvider);
    final zsPackage = pmState.installed[kZapstoreAppIdentifier];

    if (zsPackage == null) {
      final isLoading = pmState.installed.isEmpty;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              if (isLoading) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Loading Zapstore build information…',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'Zapstore version details are unavailable right now.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.orange[700]),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    unawaited(
                      ref
                          .read(packageManagerProvider.notifier)
                          .syncInstalledPackages(),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              leading: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  color: Colors.grey,
                  colorBlendMode: BlendMode.saturation,
                ),
              ),
              title: const Text('Version'),
              subtitle: Text('${zsPackage.version}+${zsPackage.versionCode}'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Source Code'),
              subtitle: const Text('View on GitHub'),
              trailing: const Icon(Icons.open_in_new),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                launchUrl(Uri.parse('https://github.com/zapstore/zapstore'));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Debug messages section (moved to Help & Support modal)
// ─────────────────────────────────────────────────────────────────────────────

class _DebugMessagesSection extends HookConsumerWidget {
  const _DebugMessagesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolState = ref.watch(poolStateProvider);
    final selectedTab = useState(0);
    final now = useState(DateTime.now());
    final expandedSubs = useState<Set<String>>({});

    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        now.value = DateTime.now();
      });
      return timer.cancel;
    }, const []);

    final subscriptions = poolState?.subscriptions ?? {};
    final closedSubscriptions = poolState?.closedSubscriptions ?? {};
    final logs = poolState?.logs ?? const [];

    final allRelayUrls = <String>{};
    for (final sub in subscriptions.values) {
      allRelayUrls.addAll(sub.relays.keys);
    }
    for (final log in logs) {
      if (log.relayUrl != null) {
        allRelayUrls.add(log.relayUrl!);
      }
    }

    void toggleSubscription(String id) {
      final next = {...expandedSubs.value};
      if (!next.remove(id)) next.add(id);
      expandedSubs.value = next;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Debug Info',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TabButton(
                  label: 'Subscriptions (${subscriptions.length})',
                  isSelected: selectedTab.value == 0,
                  onTap: () => selectedTab.value = 0,
                ),
                _TabButton(
                  label: 'Relays (${allRelayUrls.length})',
                  isSelected: selectedTab.value == 1,
                  onTap: () => selectedTab.value = 1,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (selectedTab.value == 0)
              _buildSubscriptionsTab(
                context,
                subscriptions,
                closedSubscriptions,
                logs,
                now.value,
                expandedSubs.value,
                toggleSubscription,
              ),
            if (selectedTab.value == 1)
              _buildRelaysTab(
                context,
                logs,
                subscriptions,
                closedSubscriptions,
                expandedSubs.value,
                toggleSubscription,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionsTab(
    BuildContext context,
    Map<String, RelaySubscription> subscriptions,
    Map<String, RelaySubscription> closedSubscriptions,
    List<LogEntry> allLogs,
    DateTime now,
    Set<String> expandedSubs,
    void Function(String id) onToggleSub,
  ) {
    if (subscriptions.isEmpty && closedSubscriptions.isEmpty) {
      return _EmptyState(message: 'No subscriptions');
    }

    final sortedSubs = subscriptions.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final sortedClosedSubs = closedSubscriptions.entries.toList()
      ..sort((a, b) {
        final aTime = a.value.closedAt ?? a.value.startedAt;
        final bTime = b.value.closedAt ?? b.value.startedAt;
        return bTime.compareTo(aTime);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sortedSubs.map(
          (entry) => _buildSubscriptionCard(context, entry, allLogs, now,
              expandedSubs, onToggleSub,
              isHistorical: false),
        ),
        if (sortedClosedSubs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.history,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                'History (${sortedClosedSubs.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...sortedClosedSubs.map(
            (entry) => _buildSubscriptionCard(context, entry, allLogs, now,
                expandedSubs, onToggleSub,
                isHistorical: true),
          ),
        ],
      ],
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    MapEntry<String, RelaySubscription> entry,
    List<LogEntry> allLogs,
    DateTime now,
    Set<String> expandedSubs,
    void Function(String id) onToggleSub, {
    required bool isHistorical,
  }) {
    final sub = entry.value;
    final relays = sub.relays;
    final isExpanded = expandedSubs.contains(sub.id);

    final totalRelays = sub.totalRelayCount;
    final activeRelays = sub.activeRelayCount;
    final allEose = sub.allEoseReceived;

    final relayEntries = relays.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final duration = isHistorical && sub.closedAt != null
        ? sub.closedAt!.difference(sub.startedAt)
        : null;

    return InkWell(
      onTap: () => onToggleSub(sub.id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: isHistorical ? 0.15 : 0.3),
          borderRadius: BorderRadius.circular(8),
          border: LabBorder.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isHistorical
                      ? Icons.check_circle_outline
                      : (sub.stream ? Icons.stream : Icons.download),
                  size: 16,
                  color: isHistorical
                      ? Colors.blueGrey
                      : (allEose ? Colors.green : Colors.amber.shade700),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: isHistorical
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  icon: Icons.event,
                  label: '${sub.eventCount}',
                  color: isHistorical
                      ? Colors.blueGrey
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                if (isHistorical && duration != null)
                  _StatusChip(
                    icon: Icons.timer,
                    label: _formatDuration(duration),
                    color: Colors.blueGrey,
                  )
                else
                  _StatusChip(
                    icon: Icons.cloud_done,
                    label: '$activeRelays/$totalRelays',
                    color: allEose ? Colors.green : Colors.amber.shade700,
                  ),
                const SizedBox(width: 6),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ],
            ),
            if (!isHistorical && relayEntries.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: LabBorder.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: relayEntries.map((relayEntry) {
                    final relay = relayEntry.value;
                    final phase = relay.phase;
                    final phaseColor = switch (phase) {
                      RelaySubPhase.streaming => Colors.green,
                      RelaySubPhase.loading => Colors.blue,
                      RelaySubPhase.connecting => Colors.orange,
                      RelaySubPhase.waiting => Colors.amber,
                      RelaySubPhase.failed => Colors.red,
                      RelaySubPhase.disconnected => Colors.grey,
                      RelaySubPhase.closed => Colors.blueGrey,
                    };
                    final phaseIcon = switch (phase) {
                      RelaySubPhase.streaming => Icons.cloud_done,
                      RelaySubPhase.loading => Icons.cloud_sync,
                      RelaySubPhase.connecting => Icons.wifi_find,
                      RelaySubPhase.waiting => Icons.pause_circle,
                      RelaySubPhase.failed => Icons.error,
                      RelaySubPhase.disconnected => Icons.cloud_off,
                      RelaySubPhase.closed => Icons.check_circle_outline,
                    };

                    final shortUrl = relayEntry.key
                        .replaceAll('wss://', '')
                        .replaceAll('ws://', '')
                        .replaceAll(RegExp(r'/$'), '');

                    final streamingSince = relay.streamingSince;
                    final connectedFor =
                        (phase == RelaySubPhase.streaming ||
                                phase == RelaySubPhase.loading) &&
                            streamingSince != null
                        ? _formatDuration(now.difference(streamingSince))
                        : null;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(phaseIcon, size: 16, color: phaseColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shortUrl,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${phase.name}'
                                  '${relay.reconnectAttempts > 0 ? ' · retry ${relay.reconnectAttempts}' : ''}'
                                  '${connectedFor != null ? ' · connected for $connectedFor' : ''}',
                                  style: TextStyle(
                                      fontSize: 10, color: phaseColor),
                                ),
                                if (relay.lastError != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _humanizeRelayError(relay.lastError!),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange.shade300),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            if (isExpanded) ...[
              _buildRequestView(context, sub),
              _buildSubscriptionLogs(context, sub.id, allLogs),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRelaysTab(
    BuildContext context,
    List<LogEntry> logs,
    Map<String, RelaySubscription> subscriptions,
    Map<String, RelaySubscription> closedSubscriptions,
    Set<String> expandedSubs,
    void Function(String id) onToggleSub,
  ) {
    final allRelayUrls = <String>{};
    for (final sub in subscriptions.values) {
      allRelayUrls.addAll(sub.relays.keys);
    }
    for (final log in logs) {
      if (log.relayUrl != null) allRelayUrls.add(log.relayUrl!);
    }

    if (allRelayUrls.isEmpty) {
      return _EmptyState(message: 'No relays connected');
    }

    final logsByRelay = <String, List<LogEntry>>{};
    for (final relayUrl in allRelayUrls) {
      logsByRelay[relayUrl] = [];
    }
    for (final log in logs) {
      if (log.relayUrl != null && logsByRelay.containsKey(log.relayUrl)) {
        logsByRelay[log.relayUrl]!.add(log);
      }
    }

    final sortedRelays = logsByRelay.keys.toList()..sort();
    for (final url in sortedRelays) {
      logsByRelay[url]!.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedRelays.map((relayUrl) {
        final relayLogs = logsByRelay[relayUrl]!;
        final shortUrl = relayUrl
            .replaceAll('wss://', '')
            .replaceAll('ws://', '')
            .replaceAll(RegExp(r'/$'), '');

        final errorCount =
            relayLogs.where((l) => l.level == LogLevel.error).length;
        final warningCount =
            relayLogs.where((l) => l.level == LogLevel.warning).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: LabBorder.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              childrenPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.dns,
                size: 18,
                color: errorCount > 0
                    ? Colors.red
                    : warningCount > 0
                        ? Colors.orange
                        : Theme.of(context).colorScheme.primary,
              ),
              title: Text(shortUrl,
                  style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600)),
              subtitle: Row(
                children: [
                  Text('${relayLogs.length} logs',
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6))),
                  if (errorCount > 0) ...[
                    const SizedBox(width: 8),
                    _StatusChip(
                        icon: Icons.error, label: '$errorCount', color: Colors.red),
                  ],
                  if (warningCount > 0) ...[
                    const SizedBox(width: 4),
                    _StatusChip(
                        icon: Icons.warning,
                        label: '$warningCount',
                        color: Colors.orange),
                  ],
                ],
              ),
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.1)),
                    ),
                  ),
                  child: relayLogs.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('No logs for this relay',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5))),
                        )
                      : Column(
                          children: relayLogs.map((log) {
                            final time = _formatTime(log.timestamp);
                            final levelName = log.level.name.toUpperCase();
                            final color = switch (log.level) {
                              LogLevel.error => Colors.red,
                              LogLevel.warning => Colors.orange,
                              LogLevel.info =>
                                Theme.of(context).colorScheme.primary,
                            };
                            final subId = log.subscriptionId;
                            final sub = subId != null
                                ? (subscriptions[subId] ??
                                    closedSubscriptions[subId])
                                : null;
                            final isExpanded =
                                subId != null && expandedSubs.contains(subId);

                            return InkWell(
                              onTap:
                                  subId != null ? () => onToggleSub(subId) : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(alpha: 0.1)),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                color.withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(levelName,
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: color)),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('[$time] ${log.message}',
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      fontFamily: 'monospace')),
                                              if (subId != null)
                                                Text('Sub: $subId',
                                                    style: TextStyle(
                                                        fontSize: 9,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: 0.6))),
                                              if (log.exception != null)
                                                Text(log.exception!.toString(),
                                                    style: TextStyle(
                                                        fontSize: 9,
                                                        color: Colors.red
                                                            .withValues(
                                                                alpha: 0.8))),
                                            ],
                                          ),
                                        ),
                                        if (subId != null)
                                          Icon(
                                            isExpanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            size: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                      ],
                                    ),
                                    if (isExpanded && sub != null) ...[
                                      const SizedBox(height: 8),
                                      _buildRequestView(context, sub),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(DateTime timestamp) =>
      '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}';

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) return '${duration.inSeconds}s';
    if (duration.inMinutes < 60) {
      final m = duration.inMinutes;
      final s = duration.inSeconds % 60;
      return s > 0 ? '${m}m ${s}s' : '${m}m';
    }
    if (duration.inHours < 24) {
      final h = duration.inHours;
      final m = duration.inMinutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    final d = duration.inDays;
    final h = duration.inHours % 24;
    return h > 0 ? '${d}d ${h}h' : '${d}d';
  }

  Widget _buildRequestView(BuildContext context, RelaySubscription sub) {
    final req = _formatReq(sub);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: LabBorder.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('REQ',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(sub.id,
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7)),
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Clipboard.setData(ClipboardData(text: req)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(req,
              style: const TextStyle(
                  fontSize: 11, height: 1.4, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  String _formatReq(RelaySubscription sub) {
    final payload = ['REQ', sub.id, ...sub.request.toMaps()];
    try {
      return const JsonEncoder.withIndent('  ').convert(payload);
    } catch (_) {
      return payload.toString();
    }
  }

  Widget _buildSubscriptionLogs(
    BuildContext context,
    String subscriptionId,
    List<LogEntry> allLogs,
  ) {
    final subLogs = allLogs
        .where((log) => log.subscriptionId == subscriptionId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (subLogs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: LabBorder.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LOGS (${subLogs.length})',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...subLogs.map((log) {
            final time = _formatTime(log.timestamp);
            final levelName = log.level.name.toUpperCase();
            final color = switch (log.level) {
              LogLevel.error => Colors.red,
              LogLevel.warning => Colors.orange,
              LogLevel.info => Theme.of(context).colorScheme.primary,
            };
            final parts = [
              if (log.relayUrl != null)
                log.relayUrl!
                    .replaceAll('wss://', '')
                    .replaceAll('ws://', '')
                    .replaceAll(RegExp(r'/$'), ''),
              if (log.exception != null) log.exception!,
            ];

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(levelName,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('[$time] ${log.message}',
                            style: const TextStyle(
                                fontSize: 10, fontFamily: 'monospace')),
                        if (parts.isNotEmpty)
                          Text(parts.join(' • '),
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline,
                size: 36,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Relay error humanizer (kept from original)
// ─────────────────────────────────────────────────────────────────────────────

String _humanizeRelayError(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('timeoutexception') ||
      lower.contains('future not completed')) {
    return 'Connection timed out';
  }
  if (lower.contains('max retries exceeded')) return 'Failed after max retries';
  if (lower.contains('connection refused') || lower.contains('econnrefused')) {
    return 'Connection refused';
  }
  if (lower.contains('network') || lower.contains('socket')) {
    return 'Network error';
  }
  if (lower.contains('ping timeout') || lower.contains('zombie')) {
    return 'Connection lost (ping timeout)';
  }
  return raw.length > 60 ? '${raw.substring(0, 60)}…' : raw;
}
