import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/url_utils.dart';
import 'package:zapstore/widgets/common/media_lightbox.dart';
import 'package:zapstore/widgets/common/shimmer.dart';

// Dimensions mirror webapp's chateau-web AppDetail.svelte:
//   height: 20rem (320 dp at 16 dp base)
//   width:  matches AppPic size used in AppHeader (80 dp)
//   border-radius: 0.75rem → 12 dp
//   gap: 12 dp
//   horizontal padding: 16 dp
const _kImgHeight = 320.0;
const _kImgWidth = 80.0;
const _kRadius = 12.0;
const _kGap = 12.0;
const _kHPad = 16.0;

/// Horizontal screenshots carousel — portrait frames (80 × 320 dp).
/// Tapping opens the full-screen [MediaLightbox] with prev/next + dots.
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
          return GestureDetector(
            onTap: () => showMediaLightbox(
              context,
              urls: imageUrls,
              initialIndex: index,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kRadius),
              child: SizedBox(
                width: _kImgWidth,
                height: _kImgHeight,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 250),
                  fadeOutDuration: const Duration(milliseconds: 150),
                  placeholder: (_, __) => const Shimmer(
                    width: _kImgWidth,
                    height: _kImgHeight,
                  ),
                  errorWidget: (_, __, ___) => _ErrorFrame(),
                ),
              ),
            ),
          );
        },
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
