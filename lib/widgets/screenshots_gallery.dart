import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/url_utils.dart';
import 'package:zapstore/widgets/common/media_lightbox.dart';
import 'package:zapstore/widgets/common/shimmer.dart';

// Portrait card dimensions (matching webapp's AppDetail.svelte ratio):
//   webapp: width 140px, height 320px (20rem) → 7:16
//   mobile: width 80dp (matches app icon), height = 80 × 320/140 ≈ 183dp
//
// Landscape images are "hugged": shown at their natural aspect ratio at
// _kImgHeight instead of being forced into the portrait box.
const _kPortraitWidth = 80.0;
const _kImgHeight = _kPortraitWidth * 320.0 / 140.0; // ≈ 182.9 dp
const _kRadius = 12.0;
const _kGap = 12.0;
const _kHPad = 16.0;

/// Horizontal screenshots carousel.
/// Portrait images → 80 × 183 dp card, cover-cropped from top (webapp behaviour).
/// Landscape images → natural width at 183 dp height, no cropping (hugged).
class ScreenshotsGallery extends StatelessWidget {
  const ScreenshotsGallery({super.key, required this.app});

  final App app;

  @override
  Widget build(BuildContext context) {
    final imageUrls = filterValidHttpUrls(app.images);
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: _kImgHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _kHPad),
        itemCount: imageUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: _kGap),
        itemBuilder: (context, index) {
          final url = imageUrls[index];
          return _ScreenshotItem(
            url: url,
            onTap: () => showMediaLightbox(
              context,
              urls: imageUrls,
              initialIndex: index,
            ),
          );
        },
      ),
    );
  }
}

/// A single screenshot card that self-adjusts once the image's pixel dimensions
/// are known: portrait → fixed 80dp wide + cover crop; landscape → natural
/// width at _kImgHeight (hugged, no crop).
class _ScreenshotItem extends StatefulWidget {
  const _ScreenshotItem({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  State<_ScreenshotItem> createState() => _ScreenshotItemState();
}

class _ScreenshotItemState extends State<_ScreenshotItem> {
  // Width and fit default to portrait until the image resolves.
  double _width = _kPortraitWidth;
  BoxFit _fit = BoxFit.cover;

  @override
  void initState() {
    super.initState();
    _resolveOrientation();
  }

  void _resolveOrientation() {
    // CachedNetworkImageProvider shares the same cache as CachedNetworkImage,
    // so this resolve() call does not trigger a second network request.
    final provider = CachedNetworkImageProvider(widget.url);
    provider.resolve(ImageConfiguration.empty).addListener(
      ImageStreamListener((info, _) {
        if (!mounted) return;
        final imgW = info.image.width.toDouble();
        final imgH = info.image.height.toDouble();
        if (imgW > imgH) {
          // Landscape: let the card width expand to the natural proportional
          // width at the fixed gallery height.
          setState(() {
            _width = imgW / imgH * _kImgHeight;
            _fit = BoxFit.fitHeight;
          });
        }
        // Portrait (imgW <= imgH): defaults are already correct, no setState.
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kRadius),
        child: SizedBox(
          width: _width,
          height: _kImgHeight,
          child: CachedNetworkImage(
            imageUrl: widget.url,
            width: _width,
            height: _kImgHeight,
            fit: _fit,
            // Matches webapp's object-position: center top.
            alignment: Alignment.topCenter,
            fadeInDuration: const Duration(milliseconds: 250),
            fadeOutDuration: const Duration(milliseconds: 150),
            placeholder: (_, __) => Shimmer(
              width: _kPortraitWidth,
              height: _kImgHeight,
            ),
            errorWidget: (_, __, ___) => _ErrorFrame(),
          ),
        ),
      ),
    );
  }
}

class _ErrorFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    return ColoredBox(
      color: c.white8,
      child: Center(
        child: LabIcon(LabIcons.camera, size: 20, color: c.white33),
      ),
    );
  }
}
