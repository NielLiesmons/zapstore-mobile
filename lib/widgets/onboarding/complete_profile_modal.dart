import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:models/models.dart';
import 'package:zapstore/constants/app_constants.dart';
import 'package:zapstore/services/onboarding_profile_service.dart';
import 'package:zapstore/services/profile_pow_miner.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/color.dart';
import 'package:zapstore/utils/extensions.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/text_styles.dart';
import 'package:zapstore/widgets/common/button.dart';
import 'package:zapstore/widgets/common/input_field.dart';
import 'package:zapstore/widgets/common/modal.dart';

/// Profile editor — photo, name, and bio. Used for onboarding and settings.
///
/// Returns `true` when the user saved successfully.
Future<bool> showEditProfileModal(
  BuildContext context, {
  required String title,
  String? description,
  required String initialName,
  String? initialAbout,
  String? initialPictureUrl,
  ProfilePowMiner? miner,
  bool publishOnSave = false,
  bool nestedModal = false,
  bool fillHeight = true,
  bool footerEdgeFade = true,
  String saveButtonLabel = 'Save profile',
  bool deferSignIn = false,
}) {
  final saving = ValueNotifier(false);
  final saveAction = ValueNotifier<VoidCallback?>(null);

  return showModal<bool>(
    context,
    nestedModal: nestedModal,
    title: title,
    description: description,
    fillHeight: fillHeight,
    footerEdgeFade: footerEdgeFade,
    maxHeightFactor: fillHeight ? 0.88 : 0.75,
    footer: (ctx) => ValueListenableBuilder<VoidCallback?>(
      valueListenable: saveAction,
      builder: (_, save, __) => ValueListenableBuilder<bool>(
        valueListenable: saving,
        builder: (_, isSaving, __) => ModalFooterBar(
          child: LabButton.primary(
            text: isSaving ? 'Saving…' : saveButtonLabel,
            onTap: isSaving || save == null ? null : save,
          ),
        ),
      ),
    ),
    builder: (ctx) => _EditProfileContent(
      initialName: initialName,
      initialAbout: initialAbout ?? '',
      initialPictureUrl: initialPictureUrl,
      miner: miner,
      publishOnSave: publishOnSave,
      deferSignIn: deferSignIn,
      saving: saving,
      onSaveReady: (fn) => saveAction.value = fn,
    ),
  ).then((v) => v ?? false).whenComplete(() {
    saving.dispose();
    saveAction.dispose();
  });
}

/// Onboarding alias — [showEditProfileModal] titled "Your Profile".
Future<bool> showCompleteProfileModal(
  BuildContext context, {
  required String initialName,
  ProfilePowMiner? miner,
  bool nestedModal = false,
  bool publishOnSave = false,
}) {
  return showEditProfileModal(
    context,
    title: 'Your Profile',
    initialName: initialName,
    miner: miner,
    nestedModal: nestedModal,
    publishOnSave: publishOnSave,
    fillHeight: false,
    footerEdgeFade: false,
    deferSignIn: kOnboardingDeferSignIn,
  );
}

class _EditProfileContent extends ConsumerStatefulWidget {
  const _EditProfileContent({
    required this.initialName,
    required this.initialAbout,
    this.initialPictureUrl,
    this.miner,
    required this.publishOnSave,
    this.deferSignIn = false,
    required this.saving,
    required this.onSaveReady,
  });

  final String initialName;
  final String initialAbout;
  final String? initialPictureUrl;
  final ProfilePowMiner? miner;
  final bool publishOnSave;
  final bool deferSignIn;
  final ValueNotifier<bool> saving;
  final void Function(VoidCallback save) onSaveReady;

  @override
  ConsumerState<_EditProfileContent> createState() =>
      _EditProfileContentState();
}

class _EditProfileContentState extends ConsumerState<_EditProfileContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _aboutController;
  String? _pictureUrl;
  Uint8List? _localPreview;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _aboutController = TextEditingController(text: widget.initialAbout);
    _pictureUrl = widget.initialPictureUrl;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSaveReady(saveProfile);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> pickProfilePhoto() async {
    if (_uploading || widget.saving.value) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final bytes = await file.readAsBytes();
      if (widget.deferSignIn) {
        if (!mounted) return;
        setState(() {
          _localPreview = bytes;
          _pictureUrl = null;
        });
        return;
      }

      final mime = file.mimeType ?? 'image/jpeg';
      final url = await uploadOnboardingProfileImage(
        ref: ref,
        bytes: bytes,
        mimeType: mime,
      );
      if (!mounted) return;
      setState(() {
        _pictureUrl = url;
        _localPreview = bytes;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? _sanitizePictureUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri.toString();
  }

  Future<void> saveProfile() async {
    if (widget.saving.value) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    widget.saving.value = true;
    setState(() => _error = null);

    try {
      if (widget.deferSignIn) {
        widget.miner?.stop();
        widget.miner?.dispose();
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      if (widget.publishOnSave && widget.miner != null) {
        await publishFinalOnboardingProfile(
          ref: ref,
          displayName: name,
          about: _aboutController.text,
          pictureUrl: _pictureUrl,
          miner: widget.miner!,
        );
      } else {
        final signer = ref.read(Signer.activeSignerProvider);
        if (signer == null) {
          throw Exception('Sign in to save your profile');
        }
        final partial = PartialProfile(
          name: name,
          about: _aboutController.text.trim().isEmpty
              ? null
              : _aboutController.text.trim(),
          pictureUrl: _sanitizePictureUrl(_pictureUrl),
        );
        final signed = await partial.signWith(signer);
        await ref.storage.save({signed});
        widget.miner?.stop();
        widget.miner?.dispose();
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
        widget.saving.value = false;
      }
    }
  }

  Widget _buildAvatar(LabColors c) {
    const size = 96.0;

    if (_localPreview != null) {
      return ClipOval(
        child: Image.memory(
          _localPreview!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    if (_pictureUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _pictureUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    final name = _nameController.text.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = stringToColor(name.isNotEmpty ? name : 'profile');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: profileBgColor(color),
        border: LabBorder.all(color: c.white16, width: 0.33),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: kFontFamily,
          fontSize: size * 0.44,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kModalInset, 0, kModalInset, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: GestureDetector(
              onTap: pickProfilePhoto,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildAvatar(c),
                  if (_uploading)
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: c.black33,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.white66,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c.gray66,
                        shape: BoxShape.circle,
                        border: LabBorder.all(color: c.white16, width: 0.33),
                      ),
                      child: Center(
                        child: LabIcon(
                          LabIcons.camera,
                          size: 16,
                          color: c.white66,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          LabInputField(
            controller: _nameController,
            label: 'Profile name',
            placeholder: 'Profile Name',
          ),
          const SizedBox(height: 8),
          _AboutField(controller: _aboutController),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: LabTextStyles.reg13.copyWith(color: c.rougeColor),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Multiline about field — taller than [LabInputField] for profile bios.
class _AboutField extends StatelessWidget {
  const _AboutField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(
            'About',
            style: LabTextStyles.reg15.copyWith(color: c.white),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 96),
          decoration: BoxDecoration(
            color: c.black33,
            borderRadius: BorderRadius.circular(17),
            border: LabBorder.all(color: c.white33, width: 0.33),
          ),
          child: TextField(
            controller: controller,
            maxLines: 5,
            minLines: 4,
            textInputAction: TextInputAction.newline,
            style: LabTextStyles.reg15.copyWith(color: c.white),
            cursorColor: c.white,
            cursorWidth: 1.6,
            decoration: InputDecoration(
              hintText: 'Tell people a little about yourself…',
              hintStyle: LabTextStyles.reg15.copyWith(color: c.white33),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
