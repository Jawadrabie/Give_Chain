#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK غير موجود في PATH" >&2
  exit 1
fi
flutter create . --platforms=android,ios,web --org com.givechain --project-name give_chain_app
flutter pub get
