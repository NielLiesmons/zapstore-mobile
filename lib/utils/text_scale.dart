import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's preferred font-size scale for the app.
///
/// Three presets matching zaplab_design's small / normal / large factories:
///   [TextScalePreset.small]  → 0.9   (approx. -1 font size step)
///   [TextScalePreset.normal] → 1.0   (default)
///   [TextScalePreset.large]  → 1.1   (approx. +1 font size step)
///
/// Applied in MaterialApp.builder via [MediaQuery.withClampedTextScaling] so
/// it only triggers a rebuild when the user explicitly changes the setting.
enum TextScalePreset {
  small(0.9),
  normal(1.0),
  large(1.1);

  const TextScalePreset(this.scale);
  final double scale;

  static TextScalePreset fromScale(double s) {
    if (s <= 0.95) return TextScalePreset.small;
    if (s >= 1.05) return TextScalePreset.large;
    return TextScalePreset.normal;
  }
}

const _kPrefsKey = 'text_scale_preset';

/// Async loader so we don't block app startup.
final textScalePresetProvider =
    AsyncNotifierProvider<TextScaleNotifier, TextScalePreset>(
  TextScaleNotifier.new,
);

/// Convenience: synchronous current scale factor (defaults to 1.0 until
/// SharedPreferences is loaded). Watch this in MaterialApp.builder.
final textScaleFactorProvider = Provider<double>((ref) {
  return ref
      .watch(textScalePresetProvider)
      .whenData((p) => p.scale)
      .valueOrNull ?? 1.0;
});

class TextScaleNotifier extends AsyncNotifier<TextScalePreset> {
  @override
  Future<TextScalePreset> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_kPrefsKey);
    return stored != null
        ? TextScalePreset.fromScale(stored)
        : TextScalePreset.normal;
  }

  Future<void> setPreset(TextScalePreset preset) async {
    state = AsyncData(preset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPrefsKey, preset.scale);
  }
}
