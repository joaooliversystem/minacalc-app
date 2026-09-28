@echo off
flutter --version || exit /b 1
flutter pub get || exit /b 1
flutter analyze --no-fatal-warnings --no-fatal-infos || exit /b 1
flutter test || exit /b 1
flutter build appbundle --release %* || exit /b 1
echo AAB: build\app\outputs\bundle\release\app-release.aab
