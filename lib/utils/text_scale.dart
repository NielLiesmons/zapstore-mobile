import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's preferred font-size scale for the app.
///
/// Three presets:
///   [TextScalePreset.small]  → text 0.9 · UI 0.95
///   [TextScalePreset.normal] → text 1.0 · UI 1.0  (default)
///   [TextScalePreset.large]  → text 1.1 · UI 1.05
///
/// Both scales are applied in MaterialApp.builder. Text scale goes through
/// [TextScaler]; UI scale uses Transform.scale + MediaQuery size override so
/// the full layout responds (same mechanism as Android's Display Size setting).
enum TextScalePreset {
  small(0.9, 0.975),
  normal(1.0, 1.0),
  large(1.1, 1.025);

  const TextScalePreset(this.scale, this.uiScale);
  final double scale;
  /// Overall UI zoom applied on top of text scale.
  final double uiScale;

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

/// Synchronous text scale factor (defaults to 1.0 until SharedPreferences loads).
final textScaleFactorProvider = Provider<double>((ref) {
  return ref
      .watch(textScalePresetProvider)
      .whenData((p) => p.scale)
      .valueOrNull ?? 1.0;
});

/// Synchronous UI zoom factor derived from the same preset (defaults to 1.0).
final uiScaleFactorProvider = Provider<double>((ref) {
  return ref
      .watch(textScalePresetProvider)
      .whenData((p) => p.uiScale)
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
