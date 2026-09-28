#!/usr/bin/env bash
set -euo pipefail
flutter --version
flutter pub get
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
flutter build appbundle --release "$@"
echo "AAB: build/app/outputs/bundle/release/app-release.aab"
