# Hyouka TV Control

A remote-friendly Flutter control center for Android TV (Android 14/API 34) built for ARMv7-A (armeabi-v7a).

Features include Shizuku UserService brightness control, media/system/alarm volume sliders, Cinema/Standard/Night presets, screen-off timeout, English and Arabic RTL UI, four themes, D-pad navigation and a Shizuku status page. No accounts, analytics, ads or network permission.

GitHub Actions configures the native bridge and the custom TV launcher icon, then runs formatter, analyzer, widget tests and a release APK build.

Install and start Shizuku on the TV, open the app and grant the Shizuku permission. Display brightness and audio behaviour depend on manufacturer firmware. Screen timeout is not full TV power-off.

## Phone keyboard

1. On the TV, open **Phone keyboard** in Hyouka TV Control and choose **Hyouka Remote Keyboard** from the system input-method picker.
2. Start the phone keyboard. The TV shows a local address and a temporary six-digit pairing code.
3. Keep the TV and phone on the same Wi-Fi/LAN. Open the address on the phone and enter the code.
4. On the TV, open the app/search field you want to type into and focus it. Type on the phone page and tap **Send to TV**.
5. Stop sharing from the TV app when finished.

The phone page is served locally by the TV and does not use a cloud relay. A temporary pairing code is checked for every text submission, and repeated incorrect codes are rate-limited. The headless input method commits Unicode text through Android's input connection. The local page uses HTTP, so use it only on a trusted private network, not public Wi-Fi.
\n