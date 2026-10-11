from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
gradle_kts = ROOT / "android/app/build.gradle.kts"
gradle_groovy = ROOT / "android/app/build.gradle"
manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
gradle_path = gradle_kts if gradle_kts.exists() else gradle_groovy
if not gradle_path.exists():
    raise SystemExit("Android scaffold missing; run flutter create for Android first.")

text = gradle_path.read_text(encoding="utf-8")
text = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", text)
text = re.sub(r"targetSdk\s*=\s*flutter\.targetSdkVersion", "targetSdk = 34", text)
text = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 23", text)
text = re.sub(r"targetSdkVersion\s+flutter\.targetSdkVersion", "targetSdkVersion 34", text)
if "dev.rikka.shizuku:api:13.1.5" not in text:
    block = 'dependencies {\n    implementation("dev.rikka.shizuku:api:13.1.5")\n    implementation("dev.rikka.shizuku:provider:13.1.5")'
    if "dependencies {" in text:
        text = text.replace("dependencies {", block, 1)
    else:
        text += "\n" + block + "\n}\n"
if "buildFeatures {" not in text:
    if gradle_kts.exists():
        text = text.replace("android {", "android {\n    buildFeatures { aidl = true }\n", 1)
    else:
        text = text.replace("android {", "android {\n    buildFeatures { aidl true }\n", 1)
gradle_path.write_text(text, encoding="utf-8")

manifest_text = manifest.read_text(encoding="utf-8")
manifest_text = re.sub(r'android:label="[^"]+"', 'android:label="Hyouka TV Control"', manifest_text, count=1)
if "moe.shizuku.manager.permission.API_V23" not in manifest_text:
    manifest_text = manifest_text.replace(
        "<application",
        '<uses-permission android:name="moe.shizuku.manager.permission.API_V23" />\n'
        '<uses-feature android:name="android.software.leanback" android:required="false" />\n'
        '<uses-feature android:name="android.hardware.touchscreen" android:required="false" />\n'
        '<queries><package android:name="moe.shizuku.privileged.api" /></queries>\n'
        '<application',
        1,
    )
if "rikka.shizuku.ShizukuProvider" not in manifest_text:
    provider = (
        '\n        <provider\n'
        '            android:name="rikka.shizuku.ShizukuProvider"\n'
        '            android:authorities="com.hyouka.hyouka_tv_control.shizuku"\n'
        '            android:multiprocess="false"\n'
        '            android:enabled="true"\n'
        '            android:exported="true"\n'
        '            android:permission="android.permission.INTERACT_ACROSS_USERS_FULL" />\n'
    )
    index = manifest_text.find(">", manifest_text.find("<application"))
    manifest_text = manifest_text[:index + 1] + provider + manifest_text[index + 1:]
launcher = '<category android:name="android.intent.category.LAUNCHER" />'
if "android.intent.category.LEANBACK_LAUNCHER" not in manifest_text:
    manifest_text = manifest_text.replace(launcher, launcher + '\n                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />', 1)
manifest.write_text(manifest_text, encoding="utf-8")

base = ROOT / "android/app/src/main"
aidl = base / "aidl/com/hyouka/tvcontrol"
kotlin = base / "kotlin/com/hyouka/hyouka_tv_control"
aidl.mkdir(parents=True, exist_ok=True)
kotlin.mkdir(parents=True, exist_ok=True)
for source, destination in [
    ("android_src/ITvControlService.aidl", aidl / "ITvControlService.aidl"),
    ("android_src/TvControlUserService.kt", kotlin / "TvControlUserService.kt"),
    ("android_src/MainActivity.kt", kotlin / "MainActivity.kt"),
]:
    destination.write_text((ROOT / source).read_text(encoding="utf-8"), encoding="utf-8")

res = base / "res"
(res / "drawable").mkdir(parents=True, exist_ok=True)
(res / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
(res / "values").mkdir(parents=True, exist_ok=True)
(res / "drawable/ic_launcher_foreground.xml").write_text((ROOT / "android_src/ic_launcher_foreground.xml").read_text(encoding="utf-8"), encoding="utf-8")
(res / "values/colors.xml").write_text('<resources><color name="ic_launcher_background">#08090F</color></resources>\n', encoding="utf-8")
adaptive = """<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
"""
(res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(adaptive, encoding="utf-8")
(res / "mipmap-anydpi-v26/ic_launcher_round.xml").write_text(adaptive, encoding="utf-8")
print("Configured API 34, Shizuku UserService, TV launcher and custom adaptive icon.")
