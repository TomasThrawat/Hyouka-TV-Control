# Hyouka TV Control

A remote-friendly Flutter control center for Android TV (Android 14/API 34) built for ARMv7-A (armeabi-v7a).

Features include Shizuku UserService brightness control, media/system/alarm volume sliders, Cinema/Standard/Night presets, screen-off timeout, English and Arabic RTL UI, four themes, D-pad navigation, and a native phone companion with one-time TV pairing and live text input. No accounts, analytics or ads.

GitHub Actions configures the native bridge and the custom TV launcher icon, then runs formatter, analyzer, widget tests and a release APK build.

Install and start Shizuku on the TV, open the app and grant the Shizuku permission. Display brightness and audio behaviour depend on manufacturer firmware. Screen timeout is not full TV power-off.

## Phone remote keyboard

Install the same APK on the Android TV and the Android phone.

1. Open Hyouka TV Control on the TV. The local TV discovery service starts automatically.
2. On the TV, open **Phone keyboard**. Select **Hyouka Remote Keyboard** once from the Android input-method picker. The TV shows a six-digit pairing code.
3. Open Hyouka on the phone. It discovers Hyouka TVs on the same Wi-Fi. Select the TV and enter the code once.
4. After pairing, the phone remembers the TV. Open any text field on the TV and tap the keyboard icon in the phone app. The phone's normal keyboard sends text live as you type.

The TV and phone must be on the same private Wi-Fi/LAN. Pairing tokens are stored on both devices; the six-digit code is only used for first pairing. Text is delivered through Android's input connection, including Unicode/Arabic text. The local HTTP transport is intended only for a trusted home network.
