#!/usr/bin/env python3
"""Prepare the generated Flutter Android host for Auralis release builds."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path("android/app")
ANDROID = "{http://schemas.android.com/apk/res/android}"

gradle = ROOT / "build.gradle.kts"
if not gradle.exists():
    raise SystemExit("android/app/build.gradle.kts was not generated")
text = gradle.read_text()
text = re.sub(r"compileSdk\s*=\s*[^\n]+", "compileSdk = 36", text, count=1)
text = re.sub(r"minSdk\s*=\s*[^\n]+", "minSdk = 28", text, count=1)
text = re.sub(r"targetSdk\s*=\s*[^\n]+", "targetSdk = 36", text, count=1)
if "minSdk = 28" not in text or "compileSdk = 36" not in text:
    raise SystemExit("Could not set Android SDK levels")
gradle.write_text(text)

manifest = ROOT / "src/main/AndroidManifest.xml"
tree = ET.parse(manifest)
app = tree.getroot().find("application")
if app is None:
    raise SystemExit("Android manifest has no application element")
app.set(ANDROID + "label", "Auralis")
app.set(ANDROID + "icon", "@mipmap/ic_launcher")
app.set(ANDROID + "roundIcon", "@mipmap/ic_launcher")
app.set(ANDROID + "usesCleartextTraffic", "false")
app.set(ANDROID + "allowBackup", "false")
root = tree.getroot()
existing = {node.get(ANDROID + "name") for node in root.findall("uses-permission")}
permissions = [
    "android.permission.INTERNET",
    "android.permission.WAKE_LOCK",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.MODIFY_AUDIO_SETTINGS",
]
for permission in permissions:
    if permission not in existing:
        node = ET.Element("uses-permission")
        node.set(ANDROID + "name", permission)
        root.insert(0, node)
# audio_service has an empty plugin manifest, so declare its Android service explicitly.
if not any(node.tag == "service" and node.get(ANDROID + "name") == "com.ryanheise.audioservice.AudioService" for node in app.findall("service")):
    service = ET.SubElement(app, "service", {
        ANDROID + "name": "com.ryanheise.audioservice.AudioService",
        ANDROID + "foregroundServiceType": "mediaPlayback",
        ANDROID + "exported": "true",
        ANDROID + "enabled": "true",
    })
    intent = ET.SubElement(service, "intent-filter")
    ET.SubElement(intent, "action", {ANDROID + "name": "android.media.browse.MediaBrowserService"})
if not any(node.tag == "receiver" and node.get(ANDROID + "name") == "com.ryanheise.audioservice.MediaButtonReceiver" for node in app.findall("receiver")):
    receiver = ET.SubElement(app, "receiver", {
        ANDROID + "name": "com.ryanheise.audioservice.MediaButtonReceiver",
        ANDROID + "exported": "true",
    })
    intent = ET.SubElement(receiver, "intent-filter")
    ET.SubElement(intent, "action", {ANDROID + "name": "android.intent.action.MEDIA_BUTTON"})
ET.indent(tree, space="    ")
tree.write(manifest, encoding="utf-8", xml_declaration=True)

res = ROOT / "src/main/res"
(res / "drawable").mkdir(parents=True, exist_ok=True)
(res / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
(res / "values").mkdir(parents=True, exist_ok=True)

(res / "drawable/auralis_launcher_foreground.xml").write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#00000000" android:strokeColor="#FFFFFFFF"
        android:strokeWidth="6.5" android:strokeLineCap="round"
        android:strokeLineJoin="round"
        android:pathData="M18,82 L47,29 Q54,14 61,29 L90,82 M35,65 L73,65" />
</vector>
''')
(res / "values/auralis_colors.xml").write_text('''<resources>
    <color name="auralis_icon_background">#0D0E10</color>
</resources>
''')
(res / "mipmap-anydpi-v26/ic_launcher.xml").write_text('''<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/auralis_icon_background" />
    <foreground android:drawable="@drawable/auralis_launcher_foreground" />
</adaptive-icon>
''')
(res / "drawable/launch_background.xml").write_text('''<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/auralis_icon_background" />
    <item android:drawable="@drawable/auralis_launcher_foreground"
        android:gravity="center" android:width="108dp" android:height="108dp" />
</layer-list>
''')

styles = res / "values/styles.xml"
if styles.exists():
    style_text = styles.read_text()
    style_text = style_text.replace("@drawable/launch_background", "@drawable/launch_background")
    styles.write_text(style_text)

print("Auralis Android host configured: minSdk 28, compileSdk 36, targetSdk 36.")
print("Adaptive monochrome launcher icon and dark native launch screen installed.")
