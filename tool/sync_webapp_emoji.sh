#!/usr/bin/env bash
# Copies Nostr-kind badge emoji from the sibling webapp repo into Flutter assets.
# Requires ../webapp only when you run this script — not for normal builds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEBAPP_EMOJI="$ROOT/../webapp/static/images/emoji"
DEST="$ROOT/assets/images/emoji"

if [[ ! -d "$WEBAPP_EMOJI" ]]; then
  echo "error: webapp emoji dir not found at $WEBAPP_EMOJI" >&2
  echo "Clone webapp as a sibling of zapstore, or copy PNGs manually." >&2
  exit 1
fi

mkdir -p "$DEST"
cp "$WEBAPP_EMOJI"/*.png "$DEST/"
count="$(find "$DEST" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
echo "Synced $count emoji PNGs → $DEST"
