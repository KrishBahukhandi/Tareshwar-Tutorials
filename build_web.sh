#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  build_web.sh  –  Install Flutter & build Flutter web for Netlify
# ─────────────────────────────────────────────────────────────
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.32.0}"
FLUTTER_DIR="$HOME/flutter"

echo "▶ Flutter version: $FLUTTER_VERSION"

# ── 1. Install Flutter if not cached ──────────────────────────
if [ ! -d "$FLUTTER_DIR" ]; then
  echo "▶ Cloning Flutter SDK..."
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
else
  echo "▶ Flutter SDK already present (cached)."
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

# ── 2. Pre-cache web artifacts ─────────────────────────────────
flutter precache --web

# ── 3. Enable web ──────────────────────────────────────────────
flutter config --enable-web

# ── 4. Fetch packages ──────────────────────────────────────────
flutter pub get

# ── 5. Build ───────────────────────────────────────────────────
# Secrets are injected from Netlify environment variables.
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
  --dart-define=AUTH_REDIRECT_URL="${AUTH_REDIRECT_URL:-}"

echo "✓ Build complete → build/web"
