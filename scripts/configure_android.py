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
    insertion = 'dependencies {\n    implementation("dev.rikka.shizuku:api:13.1.5")\n    implementation("dev.rikka.shizuku:provider:13.1.5")'
    if "dependencies {" in text:
        text = text.replace("dependencies {", insertion, 1)
    else:
        text += "\n" + insertion + "\n}\n"
if "buildFeatures {" not in text:
    if gradle_kts.exists():
        text = text.replace("android {", "android {\n    buildFeatures { aidl = true }\n", 1)
    else:
        text = text.replace("android {", "android {\n    buildFeatures { aidl true }\n", 1)
gradle_path.write_text(text, encoding="utf-8")

manifest_text = manifest.read_text(encoding="utf-8")
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
    app_open_end = manifest_text.find(">", manifest_text.find("<application"))
    manifest_text = manifest_text[:app_open_end + 1] + provider + manifest_text[app_open_end + 1:]
manifest_text = manifest_text.replace('android:label="hyouka_tv_control"', 'android:label="Hyouka TV Control"')
manifest_text = manifest_text.replace('android:label="Hyouka Tv Control"', 'android:label="Hyouka TV Control"')
launcher = '<category android:name="android.intent.category.LAUNCHER" />'
if "android.intent.category.LEANBACK_LAUNCHER" not in manifest_text:
    manifest_text = manifest_text.replace(
        launcher,
        launcher + '\n                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />',
        1,
    )
manifest.write_text(manifest_text, encoding="utf-8")

base = ROOT / "android/app/src/main"
aidl_dest = base / "aidl/com/hyouka/tvcontrol"
kotlin_dest = base / "kotlin/com/hyouka/hyouka_tv_control"
aidl_dest.mkdir(parents=True, exist_ok=True)
kotlin_dest.mkdir(parents=True, exist_ok=True)
for source, destination in [
    ("android_src/ITvControlService.aidl", aidl_dest / "ITvControlService.aidl"),
    ("android_src/TvControlUserService.kt", kotlin_dest / "TvControlUserService.kt"),
    ("android_src/MainActivity.kt", kotlin_dest / "MainActivity.kt"),
]:
    destination.write_text((ROOT / source).read_text(encoding="utf-8"), encoding="utf-8")

print("Android scaffold configured for API 34 and the Shizuku UserService.")
