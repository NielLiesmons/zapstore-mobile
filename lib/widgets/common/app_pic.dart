import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/utils/icons.dart';
import 'package:zapstore/utils/color.dart';
import 'shimmer.dart';


/// Rounded-square app icon matching the webapp's AppPic.svelte design.
///
/// - Size-dependent border radius (matching AppPic.svelte + profile_pic_square.dart)
/// - 0.33px white16 border on gray66 background
/// - [CachedNetworkImage] with [Shimmer] loading state
/// - Blurred background fill for transparent Android icons
/// - Colored initial letter fallback from [name] / [identifier]
/// - Generic app icon fallback
///
/// [size] is the full side length in pixels.
class AppPic extends StatefulWidget {
  const AppPic({
    super.key,
    this.iconUrl,
    this.name,
    this.identifier,
    required this.size,
    this.fillBackground = true,
    this.onTap,
  });

  final String? iconUrl;
  final String? name;
  final String? identifier;
  final double size;

  /// Whether to render the blurred background fill for transparent icons.
  final bool fillBackground;
  final VoidCallback? onTap;

  @override
  State<AppPic> createState() => _AppPicState();
}

class _AppPicState extends State<AppPic> {
  bool _imageLoaded = false;
  bool _imageError = false;

  double get _radius {
    final s = widget.size;
    if (s == 28) return 6;
    if (s >= 120) return 32;
    if (s >= 72) return 24;
    if (s >= 48) return 16;
    return 8;
  }

  @override
  void didUpdateWidget(AppPic old) {
    super.didUpdateWidget(old);
    if (old.iconUrl != widget.iconUrl) {
      setState(() {
        _imageLoaded = false;
        _imageError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<LabColors>()!;
    final resolvedUrl = _sanitize(widget.iconUrl);
    final borderRadius = BorderRadius.circular(_radius);

    Widget child;

    if (resolvedUrl != null && !_imageError) {
      child = _buildImageContent(context, c, resolvedUrl, borderRadius);
    } else {
      child = _buildFallback(context, c);
    }

    final inner = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        // thin stroke matches LabProfilePicSquare — LabLineThicknessData.normal().thin
        border: LabBorder.all(color: c.white16, width: LabStroke.thin),
        color: c.gray66,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: child,
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(onTap: widget.onTap, child: inner);
    }
    return inner;
  }

  Widget _buildImageContent(
    BuildContext context,
    LabColors c,
    String url,
    BorderRadius borderRadius,
  ) {
    return Stack(
      children: [
        // Shimmer shown until image loads
        if (!_imageLoaded)
          Shimmer(
            width: widget.size,
            height: widget.size,
            radius: _radius,
          ),

        // Blurred background fill for transparent/PNG icons
        if (widget.fillBackground && _imageLoaded)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Transform.scale(
                scale: 1.4,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                ),
              ),
            ),
          ),

        // Main image
        CachedNetworkImage(
          imageUrl: url,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          fadeInDuration: const Duration(milliseconds: 200),
          fadeOutDuration: const Duration(milliseconds: 100),
          imageBuilder: (_, imageProvider) {
            if (!_imageLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _imageLoaded = true);
              });
            }
            return Image(image: imageProvider, fit: BoxFit.contain);
          },
          errorWidget: (_, __, ___) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _imageError = true);
            });
            return const SizedBox.shrink();
          },
          placeholder: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildFallback(BuildContext context, LabColors c) {
    final seed = widget.identifier ?? widget.name;

    if (seed != null && seed.trim().isNotEmpty) {
      final initial = seed.trim()[0].toUpperCase();
      final color = stringToColor(seed);
      final bg = profileBgColor(color);
      final fg = color;
      final fontSize = (widget.size * 0.56).roundToDouble();

      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: ColoredBox(
          color: bg,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                initial,
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                  decoration: TextDecoration.none,
                ),
              ),
              // Subtle white16 overlay matching the webapp's initial-overlay
              Text(
                initial,
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: c.white16,
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ColoredBox(
        color: c.white8,
        child: Center(
          child: LabIcon(
            LabIcons.details,
            size: widget.size * 0.50,
            color: c.white33,
          ),
        ),
      ),
    );
  }

  String? _sanitize(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }
    return trimmed;
  }
}

