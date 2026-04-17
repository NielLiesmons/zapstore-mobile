import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:zapstore/utils/text_styles.dart';

const kFontFamily = 'Inter';
const kHeadlineFontFamily = 'Inter Display';

/// Stroke widths — mirrors LabLineThicknessData.normal() exactly.
/// Use these everywhere a border width is needed.
class AppStroke {
  AppStroke._();
  static const double thin = 0.33;   // panel/card borders, icon borders
  static const double medium = 1.6;  // interactive borders, icon grid containers
  static const double thick = 3.2;   // emphasis borders
}

/// Centered-stroke border factory.
///
/// Flutter's default [Border.all] uses [BorderSide.strokeAlignInside], which
/// paints the stroke entirely inward AND adds the full border width to the
/// container's effective padding — causing subtle layout overflows in
/// size-constrained widgets (exactly like CSS `box-sizing: content-box` +
/// an inward-only stroke).
///
/// [AppBorder.all] uses [BorderSide.strokeAlignCenter] instead:
///   • stroke sits on the element edge (half in, half out) → CSS/web default
///   • Flutter only inflates effective padding by `width / 2`, not `width`
///   • No surprise overflow; math stays simple: inner = size − 2 × padding
///
/// Use this everywhere instead of [Border.all].
class AppBorder {
  AppBorder._();

  static Border all({
    required Color color,
    double width = AppStroke.medium,
  }) {
    final side = BorderSide(
      color: color,
      width: width,
      strokeAlign: BorderSide.strokeAlignCenter,
    );
    return Border.fromBorderSide(side);
  }
}

/// Border radii — mirrors LabRadiusData.normal() exactly.
/// Use these everywhere a BorderRadius is needed.
class AppRadius {
  AppRadius._();
  static const double r4 = 4;
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r18 = 18;
  static const double r24 = 24;
  static const double r32 = 32;
  static const double r40 = 40;
}

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.white,
    required this.white66,
    required this.white33,
    required this.white16,
    required this.white11,
    required this.white8,
    required this.white4,
    required this.whiteEnforced,
    required this.black,
    required this.black66,
    required this.black33,
    required this.black16,
    required this.black8,
    required this.gray,
    required this.gray66,
    required this.gray44,
    required this.gray33,
    required this.gray16,
    required this.blurpleLightColor,
    required this.blurpleLightColor66,
    required this.blurpleColor,
    required this.blurpleColor66,
    required this.blurpleColor33,
    required this.goldColor,
    required this.goldColor66,
    required this.rougeColor,
    required this.rougeColor66,
    required this.greenColor,
    required this.greenColor66,
    required this.blurple,
    required this.blurple66,
    required this.blurple33,
    required this.blurple16,
    required this.rouge,
    required this.rouge66,
    required this.rouge33,
    required this.rouge16,
    required this.gold,
    required this.gold66,
    required this.gold33,
    required this.gold16,
    required this.green,
    required this.green66,
    required this.green33,
    required this.graydient,
    required this.graydient66,
    required this.graydient33,
    required this.graydient16,
  });

  final Color white;
  final Color white66;
  final Color white33;
  final Color white16;
  /// 11% white — design-system divider color (1.4px lines between panel rows).
  final Color white11;
  final Color white8;
  /// 4% white — very subtle backgrounds (--white4).
  final Color white4;
  final Color whiteEnforced;
  /// App background color — maps to --black in webapp CSS.
  final Color black;
  final Color black66;
  final Color black33;
  final Color black16;
  final Color black8;
  /// Surface color — maps to --gray (#242424) in webapp CSS.
  final Color gray;
  final Color gray66;
  final Color gray44;
  final Color gray33;
  final Color gray16;
  final Color blurpleLightColor;
  final Color blurpleLightColor66;
  final Color blurpleColor;
  final Color blurpleColor66;
  final Color blurpleColor33;
  final Color goldColor;
  final Color goldColor66;
  final Color rougeColor;
  final Color rougeColor66;
  final Color greenColor;
  final Color greenColor66;
  final Gradient blurple;
  final Gradient blurple66;
  final Gradient blurple33;
  final Gradient blurple16;
  final Gradient rouge;
  final Gradient rouge66;
  final Gradient rouge33;
  final Gradient rouge16;
  final Gradient gold;
  final Gradient gold66;
  final Gradient gold33;
  final Gradient gold16;
  final Gradient green;
  final Gradient green66;
  final Gradient green33;
  final Gradient graydient;
  final Gradient graydient66;
  final Gradient graydient33;
  final Gradient graydient16;

  factory AppColors.gray() => AppColors(
        // White opacity scale — exact webapp values
        white: const Color(0xFFFFFFFF),
        white66: const Color(0xA8FFFFFF),
        white33: const Color(0x54FFFFFF),
        white16: const Color(0x29FFFFFF),
        white11: const Color(0x1CFFFFFF),
        white8: const Color(0x14FFFFFF),
        white4: const Color(0x0AFFFFFF),
        whiteEnforced: const Color(0xFFFFFFFF),
        // Black = background (#121212 = webapp --black gray mode)
        black: const Color(0xFF121212),
        black66: const Color(0xA8121212),
        black33: const Color(0x54000000),
        black16: const Color(0x29000000),
        black8: const Color(0x14000000),
        // Gray = surface (#242424 = webapp --gray)
        gray: const Color(0xFF242424),
        gray66: const Color(0xA8333333),
        gray44: const Color(0x70333333),
        gray33: const Color(0x54333333),
        gray16: const Color(0x29333333),
        // Blurple (links/primary) — exact webapp values
        blurpleLightColor: const Color(0xFF8280FF),
        blurpleLightColor66: const Color(0xA88280FF),
        blurpleColor: const Color(0xFF5A58FE),
        blurpleColor66: const Color(0xA85A58FE),
        blurpleColor33: const Color(0x545A58FE),
        // Gold (secondary) — exact webapp values
        goldColor: const Color(0xFFFFB338),
        goldColor66: const Color(0xA8FFB338),
        // Rouge / Green solid colors
        rougeColor: const Color(0xFFFF4778),
        rougeColor66: const Color(0xA8FF4778),
        greenColor: const Color(0xFF1CD981),
        greenColor66: const Color(0xA81CD981),
        // Blurple gradient — #5C5FFF → #4542FF (webapp --gradient-blurple)
        blurple: const LinearGradient(
          colors: [Color(0xFF5C5FFF), Color(0xFF4542FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        blurple66: const LinearGradient(
          colors: [Color(0xA85C5FFF), Color(0xA84542FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        blurple33: const LinearGradient(
          colors: [Color(0x545C5FFF), Color(0x544542FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        blurple16: const LinearGradient(
          colors: [Color(0x295C5FFF), Color(0x294542FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        // Rouge gradient — #FF4778 → #FF005E (webapp --gradient-rouge)
        rouge: const LinearGradient(
          colors: [Color(0xFFFF4778), Color(0xFFFF005E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        rouge66: const LinearGradient(
          colors: [Color(0xA8FF4778), Color(0xA8FF005E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        rouge33: const LinearGradient(
          colors: [Color(0x54FF4778), Color(0x54FF005E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        rouge16: const LinearGradient(
          colors: [Color(0x29FF4778), Color(0x29FF005E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        // Gold gradient — #FFC736 → #FFA037 (webapp --gradient-gold)
        gold: const LinearGradient(
          colors: [Color(0xFFFFC736), Color(0xFFFFA037)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        gold66: const LinearGradient(
          colors: [Color(0xA8FFC736), Color(0xA8FFA037)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        gold33: const LinearGradient(
          colors: [Color(0x54FFC736), Color(0x54FFA037)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        gold16: const LinearGradient(
          colors: [Color(0x29FFC736), Color(0x29FFA037)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        // Green gradient — #19DD75 → #0BBB8C (webapp --gradient-green)
        green: const LinearGradient(
          colors: [Color(0xFF19DD75), Color(0xFF0BBB8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        green66: const LinearGradient(
          colors: [Color(0xA819DD75), Color(0xA80BBB8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        green33: const LinearGradient(
          colors: [Color(0x5419DD75), Color(0x540BBB8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        // Graydient (white → blurple-tinted) — #FFFFFF → #DBDBFF (webapp --gradient-gray)
        graydient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFDBDBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        graydient66: const LinearGradient(
          colors: [Color(0xA8FFFFFF), Color(0xA8DBDBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        graydient33: const LinearGradient(
          colors: [Color(0x54FFFFFF), Color(0x54DBDBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        graydient16: const LinearGradient(
          colors: [Color(0x29FFFFFF), Color(0x29DBDBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );

  factory AppColors.dark() => AppColors(
        white: const Color(0xFFFFFFFF),
        white66: const Color(0xA8FFFFFF),
        white33: const Color(0x54FFFFFF),
        white16: const Color(0x29FFFFFF),
        white11: const Color(0x1CFFFFFF),
        white8: const Color(0x14FFFFFF),
        white4: const Color(0x0AFFFFFF),
        whiteEnforced: const Color(0xFFFFFFFF),
        // Dark mode background is pure black (#000000)
        black: const Color(0xFF000000),
        black66: const Color(0xA8000000),
        black33: const Color(0x54000000),
        black16: const Color(0x29000000),
        black8: const Color(0x14000000),
        gray: const Color(0xFF242424),
        gray66: const Color(0xA8333333),
        gray44: const Color(0x70333333),
        gray33: const Color(0x54333333),
        gray16: const Color(0x29333333),
        blurpleLightColor: const Color(0xFF8280FF),
        blurpleLightColor66: const Color(0xA88280FF),
        blurpleColor: const Color(0xFF5A58FE),
        blurpleColor66: const Color(0xA85A58FE),
        blurpleColor33: const Color(0x545A58FE),
        goldColor: const Color(0xFFFFB338),
        goldColor66: const Color(0xA8FFB338),
        rougeColor: const Color(0xFFFF4778),
        rougeColor66: const Color(0xA8FF4778),
        greenColor: const Color(0xFF1CD981),
        greenColor66: const Color(0xA81CD981),
        blurple: const LinearGradient(
          colors: [Color(0xFF5C5FFF), Color(0xFF4542FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        blurple66: const LinearGradient(
          colors: [Color(0xA85C5FFF), Color(0xA84542FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        blurple33: const LinearGradient(
          colors: [Color(0x545C5FFF), Color(0x544542FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        blurple16: const LinearGradient(
          colors: [Color(0x295C5FFF), Color(0x294542FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        rouge: const LinearGradient(
          colors: [Color(0xFFFF4778), Color(0xFFFF005E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        rouge66: const LinearGradient(
          colors: [Color(0xA8FF4778), Color(0xA8FF005E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        rouge33: const LinearGradient(
          colors: [Color(0x54FF4778), Color(0x54FF005E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        rouge16: const LinearGradient(
          colors: [Color(0x29FF4778), Color(0x29FF005E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        gold: const LinearGradient(
          colors: [Color(0xFFFFC736), Color(0xFFFFA037)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        gold66: const LinearGradient(
          colors: [Color(0xA8FFC736), Color(0xA8FFA037)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        gold33: const LinearGradient(
          colors: [Color(0x54FFC736), Color(0x54FFA037)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        gold16: const LinearGradient(
          colors: [Color(0x29FFC736), Color(0x29FFA037)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        green: const LinearGradient(
          colors: [Color(0xFF19DD75), Color(0xFF0BBB8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        green66: const LinearGradient(
          colors: [Color(0xA819DD75), Color(0xA80BBB8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        green33: const LinearGradient(
          colors: [Color(0x5419DD75), Color(0x540BBB8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        graydient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFDBDBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        graydient66: const LinearGradient(
          colors: [Color(0xA8FFFFFF), Color(0xA8DBDBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        graydient33: const LinearGradient(
          colors: [Color(0x54FFFFFF), Color(0x54DBDBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        graydient16: const LinearGradient(
          colors: [Color(0x29FFFFFF), Color(0x29DBDBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );

  factory AppColors.light() => AppColors(
        // Light mode — warm dark-on-light palette (webapp [data-theme="light"])
        white: const Color(0xFF241B0F),
        white66: const Color(0xA8241B0F),
        white33: const Color(0x54241B0F),
        white16: const Color(0x29241B0F),
        white11: const Color(0x1C241B0F),
        white8: const Color(0x14241B0F),
        white4: const Color(0x0A241B0F),
        whiteEnforced: const Color(0xFFFFFFFF),
        // Light background (#F3ECE2)
        black: const Color(0xFFF3ECE2),
        black66: const Color(0xA8F0E9E0),
        black33: const Color(0x54F0E9E0),
        black16: const Color(0x29F0E9E0),
        black8: const Color(0x14F0E9E0),
        gray: const Color(0xFFC4BAAB),
        gray66: const Color(0x99AEA798),
        gray44: const Color(0x70AEA798),
        gray33: const Color(0x4DAEA798),
        gray16: const Color(0x29AEA798),
        blurpleLightColor: const Color(0xFF4B4BCD),
        blurpleLightColor66: const Color(0xA84B4BCD),
        blurpleColor: const Color(0xFF5A58FE),
        blurpleColor66: const Color(0xA85A58FE),
        blurpleColor33: const Color(0x545A58FE),
        goldColor: const Color(0xFFE99C0A),
        goldColor66: const Color(0xA8E99C0A),
        rougeColor: const Color(0xFFFF4778),
        rougeColor66: const Color(0xA8FF4778),
        greenColor: const Color(0xFF0CA05F),
        greenColor66: const Color(0xA80CA05F),
        blurple: const LinearGradient(
          colors: [Color(0xFF5C5FFF), Color(0xFF4542FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        blurple66: const LinearGradient(
          colors: [Color(0xA85C5FFF), Color(0xA84542FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        blurple33: const LinearGradient(
          colors: [Color(0x545C5FFF), Color(0x544542FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        blurple16: const LinearGradient(
          colors: [Color(0x295C5FFF), Color(0x294542FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        rouge: const LinearGradient(
          colors: [Color(0xFFFF4778), Color(0xFFFF005E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        rouge66: const LinearGradient(
          colors: [Color(0xA8FF4778), Color(0xA8FF005E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        rouge33: const LinearGradient(
          colors: [Color(0x54FF4778), Color(0x54FF005E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        rouge16: const LinearGradient(
          colors: [Color(0x29FF4778), Color(0x29FF005E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        gold: const LinearGradient(
          colors: [Color(0xFFE3A915), Color(0xFFEF8F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        gold66: const LinearGradient(
          colors: [Color(0xA8E3A915), Color(0xA8EF8F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        gold33: const LinearGradient(
          colors: [Color(0x54E3A915), Color(0x54EF8F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        gold16: const LinearGradient(
          colors: [Color(0x29E3A915), Color(0x29EF8F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        green: const LinearGradient(
          colors: [Color(0xFF0EBA6A), Color(0xFF0A8060)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        green66: const LinearGradient(
          colors: [Color(0xA80EBA6A), Color(0xA80A8060)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        green33: const LinearGradient(
          colors: [Color(0x540EBA6A), Color(0x540A8060)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        graydient: const LinearGradient(
          colors: [Color(0xFF535367), Color(0xFF232323)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        graydient66: const LinearGradient(
          colors: [Color(0xA8535367), Color(0xA8232323)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        graydient33: const LinearGradient(
          colors: [Color(0x54535367), Color(0x54232323)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        graydient16: const LinearGradient(
          colors: [Color(0x29535367), Color(0x29232323)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );

  @override
  AppColors copyWith({
    Color? white,
    Color? white66,
    Color? white33,
    Color? white16,
    Color? white11,
    Color? white8,
    Color? white4,
    Color? whiteEnforced,
    Color? black,
    Color? black66,
    Color? black33,
    Color? black16,
    Color? black8,
    Color? gray,
    Color? gray66,
    Color? gray44,
    Color? gray33,
    Color? gray16,
    Color? blurpleLightColor,
    Color? blurpleLightColor66,
    Color? blurpleColor,
    Color? blurpleColor66,
    Color? blurpleColor33,
    Color? goldColor,
    Color? goldColor66,
    Color? rougeColor,
    Color? rougeColor66,
    Color? greenColor,
    Color? greenColor66,
    Gradient? blurple,
    Gradient? blurple66,
    Gradient? blurple33,
    Gradient? blurple16,
    Gradient? rouge,
    Gradient? rouge66,
    Gradient? rouge33,
    Gradient? rouge16,
    Gradient? gold,
    Gradient? gold66,
    Gradient? gold33,
    Gradient? gold16,
    Gradient? green,
    Gradient? green66,
    Gradient? green33,
    Gradient? graydient,
    Gradient? graydient66,
    Gradient? graydient33,
    Gradient? graydient16,
  }) =>
      AppColors(
        white: white ?? this.white,
        white66: white66 ?? this.white66,
        white33: white33 ?? this.white33,
        white16: white16 ?? this.white16,
        white11: white11 ?? this.white11,
        white8: white8 ?? this.white8,
        white4: white4 ?? this.white4,
        whiteEnforced: whiteEnforced ?? this.whiteEnforced,
        black: black ?? this.black,
        black66: black66 ?? this.black66,
        black33: black33 ?? this.black33,
        black16: black16 ?? this.black16,
        black8: black8 ?? this.black8,
        gray: gray ?? this.gray,
        gray66: gray66 ?? this.gray66,
        gray44: gray44 ?? this.gray44,
        gray33: gray33 ?? this.gray33,
        gray16: gray16 ?? this.gray16,
        blurpleLightColor: blurpleLightColor ?? this.blurpleLightColor,
        blurpleLightColor66: blurpleLightColor66 ?? this.blurpleLightColor66,
        blurpleColor: blurpleColor ?? this.blurpleColor,
        blurpleColor66: blurpleColor66 ?? this.blurpleColor66,
        blurpleColor33: blurpleColor33 ?? this.blurpleColor33,
        goldColor: goldColor ?? this.goldColor,
        goldColor66: goldColor66 ?? this.goldColor66,
        rougeColor: rougeColor ?? this.rougeColor,
        rougeColor66: rougeColor66 ?? this.rougeColor66,
        greenColor: greenColor ?? this.greenColor,
        greenColor66: greenColor66 ?? this.greenColor66,
        blurple: blurple ?? this.blurple,
        blurple66: blurple66 ?? this.blurple66,
        blurple33: blurple33 ?? this.blurple33,
        blurple16: blurple16 ?? this.blurple16,
        rouge: rouge ?? this.rouge,
        rouge66: rouge66 ?? this.rouge66,
        rouge33: rouge33 ?? this.rouge33,
        rouge16: rouge16 ?? this.rouge16,
        gold: gold ?? this.gold,
        gold66: gold66 ?? this.gold66,
        gold33: gold33 ?? this.gold33,
        gold16: gold16 ?? this.gold16,
        green: green ?? this.green,
        green66: green66 ?? this.green66,
        green33: green33 ?? this.green33,
        graydient: graydient ?? this.graydient,
        graydient66: graydient66 ?? this.graydient66,
        graydient33: graydient33 ?? this.graydient33,
        graydient16: graydient16 ?? this.graydient16,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      white: Color.lerp(white, other.white, t)!,
      white66: Color.lerp(white66, other.white66, t)!,
      white33: Color.lerp(white33, other.white33, t)!,
      white16: Color.lerp(white16, other.white16, t)!,
      white11: Color.lerp(white11, other.white11, t)!,
      white8: Color.lerp(white8, other.white8, t)!,
      white4: Color.lerp(white4, other.white4, t)!,
      whiteEnforced: Color.lerp(whiteEnforced, other.whiteEnforced, t)!,
      black: Color.lerp(black, other.black, t)!,
      black66: Color.lerp(black66, other.black66, t)!,
      black33: Color.lerp(black33, other.black33, t)!,
      black16: Color.lerp(black16, other.black16, t)!,
      black8: Color.lerp(black8, other.black8, t)!,
      gray: Color.lerp(gray, other.gray, t)!,
      gray66: Color.lerp(gray66, other.gray66, t)!,
      gray44: Color.lerp(gray44, other.gray44, t)!,
      gray33: Color.lerp(gray33, other.gray33, t)!,
      gray16: Color.lerp(gray16, other.gray16, t)!,
      blurpleLightColor: Color.lerp(blurpleLightColor, other.blurpleLightColor, t)!,
      blurpleLightColor66: Color.lerp(blurpleLightColor66, other.blurpleLightColor66, t)!,
      blurpleColor: Color.lerp(blurpleColor, other.blurpleColor, t)!,
      blurpleColor66: Color.lerp(blurpleColor66, other.blurpleColor66, t)!,
      blurpleColor33: Color.lerp(blurpleColor33, other.blurpleColor33, t)!,
      goldColor: Color.lerp(goldColor, other.goldColor, t)!,
      goldColor66: Color.lerp(goldColor66, other.goldColor66, t)!,
      rougeColor: Color.lerp(rougeColor, other.rougeColor, t)!,
      rougeColor66: Color.lerp(rougeColor66, other.rougeColor66, t)!,
      greenColor: Color.lerp(greenColor, other.greenColor, t)!,
      greenColor66: Color.lerp(greenColor66, other.greenColor66, t)!,
      blurple: Gradient.lerp(blurple, other.blurple, t)!,
      blurple66: Gradient.lerp(blurple66, other.blurple66, t)!,
      blurple33: Gradient.lerp(blurple33, other.blurple33, t)!,
      blurple16: Gradient.lerp(blurple16, other.blurple16, t)!,
      rouge: Gradient.lerp(rouge, other.rouge, t)!,
      rouge66: Gradient.lerp(rouge66, other.rouge66, t)!,
      rouge33: Gradient.lerp(rouge33, other.rouge33, t)!,
      rouge16: Gradient.lerp(rouge16, other.rouge16, t)!,
      gold: Gradient.lerp(gold, other.gold, t)!,
      gold66: Gradient.lerp(gold66, other.gold66, t)!,
      gold33: Gradient.lerp(gold33, other.gold33, t)!,
      gold16: Gradient.lerp(gold16, other.gold16, t)!,
      green: Gradient.lerp(green, other.green, t)!,
      green66: Gradient.lerp(green66, other.green66, t)!,
      green33: Gradient.lerp(green33, other.green33, t)!,
      graydient: Gradient.lerp(graydient, other.graydient, t)!,
      graydient66: Gradient.lerp(graydient66, other.graydient66, t)!,
      graydient33: Gradient.lerp(graydient33, other.graydient33, t)!,
      graydient16: Gradient.lerp(graydient16, other.graydient16, t)!,
    );
  }

  // ── Backward-compat static aliases (gray mode values) ──────────────────
  // These let existing widgets compile unchanged until they migrate to
  // Theme.of(context).extension<AppColors>()!
  static const Color darkPrimary = Color(0xFF5A58FE);
  static const Color darkSecondary = Color(0xFF8280FF);
  static const Color darkSurface = Color(0xFF242424);
  static const Color darkSurfaceVariant = Color(0x54333333);
  /// Gray-mode app background — matches webapp --black (#121212).
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkBackgroundSecondary = Color(0xFF121212);
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkOnSurfaceVariant = Color(0xA8FFFFFF);
  static const Color darkOnSurfaceSecondary = Color(0xA8FFFFFF);
  static const Color darkOutline = Color(0x29FFFFFF);
  static const Color darkSkeletonBase = Color(0xFF242424);
  static const Color darkSkeletonHighlight = Color(0xA8333333);
  static const Color darkPillBackground = Color(0x54333333);
  static const Color darkActionPrimary = Color(0xFF5A58FE);

  static SkeletonizerConfigData getSkeletonizerConfig(Brightness brightness) {
    return const SkeletonizerConfigData(
      effect: ShimmerEffect(
        baseColor: darkSkeletonBase,
        highlightColor: darkSkeletonHighlight,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }
}

TextTheme _buildTextTheme(AppColors c) => TextTheme(
      // Large display: app name hero text
      displayLarge: AppTextStyles.h1.copyWith(fontSize: 56, color: c.white),
      displayMedium: AppTextStyles.h1.copyWith(fontSize: 44, color: c.white),
      displaySmall: AppTextStyles.h1.copyWith(fontSize: 36, color: c.white),
      // Headlines: major screen sections
      headlineLarge: AppTextStyles.h1.copyWith(fontSize: 32, color: c.white),
      headlineMedium: AppTextStyles.h1.copyWith(fontSize: 28, color: c.white),
      headlineSmall: AppTextStyles.h1.copyWith(fontSize: 24, color: c.white),
      // Titles: modal headers, card titles (SemiBold, not ExtraBold)
      titleLarge: AppTextStyles.h2.copyWith(color: c.white),   // 20px w600
      titleMedium: AppTextStyles.bold17.copyWith(color: c.white), // 16px w600
      titleSmall: AppTextStyles.bold15.copyWith(color: c.white),  // 14.5px w600
      // Body
      bodyLarge: AppTextStyles.reg17.copyWith(color: c.white),
      bodyMedium: AppTextStyles.reg15.copyWith(color: c.white66),
      bodySmall: AppTextStyles.reg13.copyWith(color: c.white66),
      // Labels: chips, timestamps, metadata
      labelLarge: AppTextStyles.med15.copyWith(color: c.white),
      labelMedium: AppTextStyles.med13.copyWith(color: c.white),
      labelSmall: AppTextStyles.med11.copyWith(color: c.white66),
    );

ThemeData _buildMaterialTheme(AppColors c) => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      scaffoldBackgroundColor: c.black,
      extensions: [c],
      colorScheme: ColorScheme.dark(
        primary: c.blurpleColor,
        secondary: c.blurpleLightColor,
        surface: c.gray,
        surfaceContainerHighest: c.gray33,
        onSurface: c.white,
        onSurfaceVariant: c.white66,
        outline: c.white16,
        error: const Color(0xFFFF416E),
        onError: c.whiteEnforced,
      ),
      textTheme: _buildTextTheme(c),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.gray33,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.white8, width: 0.33),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.gray33,
        selectedColor: c.blurpleColor33,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        labelStyle: TextStyle(
          fontFamily: kFontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 14,
          letterSpacing: 0.15,
          color: c.white,
        ),
        elevation: 0,
        pressElevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.blurpleColor,
          foregroundColor: c.whiteEnforced,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          textStyle: AppTextStyles.med17,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.blurpleColor,
          foregroundColor: c.whiteEnforced,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          textStyle: AppTextStyles.med17,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.blurpleColor,
          side: BorderSide(color: c.blurpleColor, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          textStyle: AppTextStyles.med17,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.white16, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.white16, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.blurpleColor, width: 2),
        ),
        filled: true,
        fillColor: c.gray33,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: TextStyle(
          fontFamily: kFontFamily,
          color: c.white33,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.black,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.white,
        titleTextStyle: TextStyle(
          fontFamily: kHeadlineFontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: c.white,
          letterSpacing: 0.1,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.gray66,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.gray,
        selectedItemColor: c.blurpleColor,
        unselectedItemColor: c.white66,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.gray,
        selectedIconTheme: IconThemeData(color: c.blurpleColor),
        unselectedIconTheme: IconThemeData(color: c.white66),
        selectedLabelTextStyle: TextStyle(color: c.blurpleColor),
        unselectedLabelTextStyle: TextStyle(color: c.white66),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.blurpleColor,
        linearTrackColor: c.gray33,
        circularTrackColor: c.gray33,
      ),
    );

final grayTheme = _buildMaterialTheme(AppColors.gray());
final darkTheme = _buildMaterialTheme(AppColors.dark());
final lightTheme = _buildMaterialTheme(AppColors.light());
