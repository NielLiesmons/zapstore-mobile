import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG icon name constants — each value is the filename (without .svg) inside
/// assets/icons/ (default, 1.6px stroke) and assets/icons/thick/ (3.2px stroke).
class LabIcons {
  LabIcons._();

  static const String adjust        = 'adjust';
  static const String alert         = 'alert';
  static const String appearance    = 'appearance';
  static const String arrowDown     = 'arrowDown';
  static const String arrowUp       = 'arrowUp';
  static const String at            = 'at';
  static const String attachment    = 'attachment';
  static const String backspace     = 'backspace';
  static const String backup        = 'backup';
  static const String bell          = 'bell';
  static const String bold          = 'bold';
  static const String camera        = 'camera';
  static const String check         = 'check';
  static const String checkList     = 'checkList';
  static const String chevronDown   = 'chevronDown';
  static const String chevronDownFill = 'chevronDownFill';
  static const String chevronLeft   = 'chevronLeft';
  static const String chevronRight  = 'chevronRight';
  static const String chevronUp     = 'chevronUp';
  static const String circle50      = 'circle50';
  static const String circle75      = 'circle75';
  static const String clock         = 'clock';
  static const String code          = 'code';
  static const String code2         = 'code2';
  static const String copy          = 'copy';
  static const String counter       = 'counter';
  static const String cross         = 'cross';
  static const String crown         = 'crown';
  static const String details       = 'details';
  static const String devices       = 'devices';
  static const String discover      = 'discover';
  static const String download      = 'download';
  static const String draft         = 'draft';
  static const String drag          = 'drag';
  static const String draw          = 'draw';
  static const String emojiFill     = 'emojiFill';
  static const String emojiLine     = 'emojiLine';
  static const String expand        = 'expand';
  static const String extension     = 'extension';
  static const String filter        = 'filter';
  static const String flip          = 'flip';
  static const String focus         = 'focus';
  static const String gif           = 'gif';
  static const String heart         = 'heart';
  static const String hidden        = 'hidden';
  static const String home          = 'home';
  static const String hosting       = 'hosting';
  static const String id            = 'id';
  static const String impression    = 'impression';
  static const String inbox         = 'inbox';
  static const String incognito     = 'incognito';
  static const String index         = 'index';
  static const String info          = 'info';
  static const String insights      = 'insights';
  static const String invoice       = 'invoice';
  static const String italic        = 'italic';
  static const String key           = 'key';
  static const String label         = 'label';
  static const String latex         = 'latex';
  static const String link          = 'link';
  static const String list          = 'list';
  static const String location      = 'location';
  static const String magic         = 'magic';
  static const String mail          = 'mail';
  static const String menu          = 'menu';
  static const String mic           = 'mic';
  static const String mints         = 'mints';
  static const String music         = 'music';
  static const String nostr         = 'nostr';
  static const String numberedList  = 'numberedList';
  static const String openBook      = 'openBook';
  static const String openWith      = 'openWith';
  static const String options       = 'options';
  static const String pause         = 'pause';
  static const String pen           = 'pen';
  static const String phone         = 'phone';
  static const String pin           = 'pin';
  static const String play          = 'play';
  static const String plus          = 'plus';
  static const String pricing       = 'pricing';
  static const String profile       = 'profile';
  static const String profileQR     = 'profileQR';
  static const String qr            = 'QR';
  static const String reply         = 'reply';
  static const String search        = 'search';
  static const String security      = 'security';
  static const String send          = 'send';
  static const String share         = 'share';
  static const String shareFill     = 'shareFill';
  static const String split         = 'split';
  static const String star          = 'star';
  static const String sticker       = 'sticker';
  static const String strikeThrough = 'strikeThrough';
  static const String studio        = 'studio';
  static const String subscript     = 'subscript';
  static const String superscript   = 'superscript';
  static const String table         = 'table';
  static const String text          = 'text';
  static const String tilda         = 'tilda';
  static const String tools         = 'tools';
  static const String transfer      = 'transfer';
  static const String underline     = 'underline';
  static const String video         = 'video';
  static const String voice         = 'voice';
  static const String wifi          = 'wifi';
  static const String zap           = 'zap';
}

/// Renders a Zaplab SVG icon.
///
/// • [icon]      — one of the [LabIcons] constants (filename without .svg)
/// • [size]      — rendered width and height in logical pixels
/// • [color]     — tints the icon via [BlendMode.srcIn]; pass null to use the
///                 SVG's own colours (white for most icons)
/// • [gradient]  — wraps the icon in a [ShaderMask] for gradient fills
/// • [thick]     — when true, uses the 3.2px-stroke variant from assets/icons/thick/
class LabIcon extends StatelessWidget {
  const LabIcon(
    this.icon, {
    super.key,
    this.size = 20.0,
    this.color,
    this.gradient,
    this.thick = false,
  });

  final String icon;
  final double size;
  final Color? color;
  final Gradient? gradient;
  final bool thick;

  @override
  Widget build(BuildContext context) {
    final path =
        thick ? 'assets/icons/thick/$icon.svg' : 'assets/icons/$icon.svg';

    final svg = SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: (gradient == null && color != null)
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );

    if (gradient != null) {
      return ShaderMask(
        shaderCallback: (bounds) => gradient!.createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: SvgPicture.asset(path, width: size, height: size),
      );
    }

    return svg;
  }
}
