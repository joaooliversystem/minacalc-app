#!/usr/bin/env bash
set -euo pipefail
flutter --version
flutter pub get
flutter analyze
flutter test
flutter build apk --release "$@"
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
