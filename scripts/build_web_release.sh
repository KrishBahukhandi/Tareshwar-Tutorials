#!/bin/sh

set -eu

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ] || [ -z "${AUTH_REDIRECT_URL:-}" ]; then
  echo "Missing required environment variables."
  echo "Set SUPABASE_URL, SUPABASE_ANON_KEY, and AUTH_REDIRECT_URL before running this script."
  exit 1
fi

flutter build web \
  --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=AUTH_REDIRECT_URL="$AUTH_REDIRECT_URL"
