#!/usr/bin/env bash
# Regression loop for inbox RenderFlex overflows — widget tests + optional emulator.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FLUTTER="${FLUTTER:-flutter}"
DEVICE="${DEVICE:-emulator-5554}"

echo "▸ Inbox widget tests"
"$FLUTTER" test \
  test/intrinsic_height_stack_test.dart \
  test/bubble_swiper_layout_test.dart \
  test/inbox_screen_layout_test.dart

if command -v adb >/dev/null 2>&1 && adb devices 2>/dev/null | grep -qE "^${DEVICE}[[:space:]]+device"; then
  echo "▸ Building debug APK"
  "$FLUTTER" build apk --debug

  echo "▸ Installing on ${DEVICE}"
  adb -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-debug.apk

  echo "▸ Clearing logcat overflow markers"
  adb -s "$DEVICE" logcat -c || true

  echo "▸ Integration test on ${DEVICE}"
  "$FLUTTER" test integration_test/inbox_screen_test.dart -d "$DEVICE"

  echo "▸ Logcat overflow scan"
  if adb -s "$DEVICE" logcat -d 2>/dev/null | grep -iE 'RenderFlex|overflowed by'; then
    echo "✗ Overflow detected in logcat"
    exit 1
  fi
  echo "✓ No overflow lines in logcat"
else
  echo "▸ No device ${DEVICE} — skipping APK + integration test"
fi

echo "✓ Inbox verification complete"
