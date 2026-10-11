# Hyouka TV Control

A remote-friendly Flutter control center for Android TV (Android 14 / API 34, ARMv7-A / armeabi-v7a). Uses Shizuku UserService to adjust system brightness, media/system/alarm volume, and screen-off timeout.

## Features
- System brightness slider and Cinema / Standard / Night presets
- Media, system and alarm volume sliders
- Screen-off timeout shortcuts
- Arabic (RTL) and English UI
- Pure Black, White, Cozy and Material You-inspired themes
- TV-friendly focus targets, D-pad navigation and Shizuku status
- No accounts, analytics, advertisements or network permission

## Build
The CI workflow creates the Android scaffold with Flutter, configures the Shizuku bridge, formats/analyzes/tests the app and builds an ARMv7 APK. Artifact name: hyouka-tv-control-armv7.apk.

## Install
1. Install and start Shizuku on the TV.
2. Install the APK and open Hyouka TV Control.
3. Select Connect Shizuku and grant permission.
4. Use sliders or labelled presets. Errors are displayed instead of pretending an operation succeeded.

Brightness depends on TV firmware and its display driver. Screen timeout behaviour is manufacturer-dependent. The timeout control changes Android's screen-off timeout; it does not power the TV off.

For a local build, install Flutter stable and Java 17, create an Android scaffold using Flutter, copy the scaffold android directory to the project, then run scripts/configure_android.py, flutter pub get, flutter analyze, flutter test, and flutter build apk --release --target-platform android-arm.
