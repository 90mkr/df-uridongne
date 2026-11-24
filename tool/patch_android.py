"""자동 제작 때 안드로이드 설정을 맞춘다: 인터넷·위치 권한, 앱 이름, 바깥 링크 열기 허용."""
import re
import sys

path = "android/app/src/main/AndroidManifest.xml"
label = sys.argv[1] if len(sys.argv) > 1 else "우리동네"
s = open(path, encoding="utf-8").read()

if "android.permission.INTERNET" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)

# 내 주변 맛집: 위치 권한
for perm in ("ACCESS_COARSE_LOCATION", "ACCESS_FINE_LOCATION"):
    if f"android.permission.{perm}" not in s:
        s = s.replace("<application", f'<uses-permission android:name="android.permission.{perm}"/>\n    <application', 1)

# QR 읽기: 카메라 (없는 기기도 설치되게 required=false)
if "android.permission.CAMERA" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.CAMERA"/>\n    <uses-feature android:name="android.hardware.camera" android:required="false"/>\n    <application', 1)

s = re.sub(r'android:label="[^"]*"', f'android:label="{label}"', s, count=1)

if "android.intent.action.DIAL" not in s:
    extra = """
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL" />
            <data android:scheme="tel" />
        </intent>
        <intent>
            <action android:name="android.intent.action.SENDTO" />
            <data android:scheme="mailto" />
        </intent>"""
    if "<queries>" in s:
        s = s.replace("<queries>", "<queries>" + extra, 1)
    else:
        s = s.replace("</manifest>", "    <queries>" + extra + "\n    </queries>\n</manifest>", 1)

# 길안내: 카카오맵·네이버·티맵이 깔렸는지 보고 아이콘을 받으려면 알려 둬야 함 (안드로이드 11부터)
if "net.daum.android.map" not in s:
    nav = """
        <package android:name="net.daum.android.map" />
        <package android:name="com.nhn.android.nmap" />
        <package android:name="com.skt.tmap.ku" />
        <package android:name="com.kakao.talk" />
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="kakaomap" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="nmap" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="tmap" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="market" />
        </intent>"""
    s = s.replace("<queries>", "<queries>" + nav, 1)

open(path, "w", encoding="utf-8").write(s)

# 출시용 만들 때 린트 검사 끄기 (영상 재생 부품의 린트 도구가 깨져 제작이 멈춤)
import os
for gp, line in (("android/app/build.gradle.kts", "    lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }\n"),
                 ("android/app/build.gradle", "    lint {\n        checkReleaseBuilds false\n        abortOnError false\n    }\n")):
    if os.path.exists(gp):
        g = open(gp, encoding="utf-8").read()
        if "checkReleaseBuilds" not in g:
            g = g.replace("android {\n", "android {\n" + line, 1)
            open(gp, "w", encoding="utf-8").write(g)
# 파이어베이스 로그인은 안드로이드 6.0(23) 이상
for gp in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    if os.path.exists(gp):
        g = open(gp, encoding="utf-8").read()
        g = g.replace("minSdk = flutter.minSdkVersion", "minSdk = 23").replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 23")
        open(gp, "w", encoding="utf-8").write(g)

# 고정 서명: android/app/upload.jks 가 있으면 그 키로 (비밀번호는 KEY_PASS 환경 변수)
kts = "android/app/build.gradle.kts"
if os.path.exists(kts):
    g = open(kts, encoding="utf-8").read()
    if 'create("upload")' not in g:
        g = g.replace("    buildTypes {", """    signingConfigs {
        create("upload") {
            storeFile = file("upload.jks")
            storePassword = System.getenv("KEY_PASS")
            keyAlias = "dongne"
            keyPassword = System.getenv("KEY_PASS")
        }
    }

    buildTypes {""", 1)
        g = g.replace('signingConfig = signingConfigs.getByName("debug")',
                      'signingConfig = if (file("upload.jks").exists()) signingConfigs.getByName("upload") else signingConfigs.getByName("debug")', 1)
        open(kts, "w", encoding="utf-8").write(g)
grv = "android/app/build.gradle"
if os.path.exists(grv):
    g = open(grv, encoding="utf-8").read()
    if "upload.jks" not in g:
        g = g.replace("    buildTypes {", """    signingConfigs {
        upload {
            storeFile file("upload.jks")
            storePassword System.getenv("KEY_PASS")
            keyAlias "dongne"
            keyPassword System.getenv("KEY_PASS")
        }
    }

    buildTypes {""", 1)
        g = g.replace("signingConfig signingConfigs.debug", 'signingConfig file("upload.jks").exists() ? signingConfigs.upload : signingConfigs.debug', 1)
        open(grv, "w", encoding="utf-8").write(g)
print("안드로이드 설정 완료")


# 네이버 지도: 안드로이드 6.0(SDK 23) 이상 — 넉넉히 24
import glob
for g in glob.glob("android/app/build.gradle*"):
    t = open(g, encoding="utf-8").read()
    t2 = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdk = 24", t)
    t2 = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", t2)
    if t2 != t:
        open(g, "w", encoding="utf-8").write(t2)


# 기념일 알림(flutter_local_notifications) · 시계 앱 알람: 권한·받개·desugaring (11-24)
s = open(path, encoding="utf-8").read()
for perm in ("POST_NOTIFICATIONS", "RECEIVE_BOOT_COMPLETED"):
    if f"android.permission.{perm}" not in s:
        s = s.replace("<application", f'<uses-permission android:name="android.permission.{perm}"/>\n    <application', 1)
if "com.android.alarm.permission.SET_ALARM" not in s:
    s = s.replace("<application", '<uses-permission android:name="com.android.alarm.permission.SET_ALARM"/>\n    <application', 1)
if "ScheduledNotificationReceiver" not in s:
    rec = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""
    s = s.replace("</application>", rec + "    </application>", 1)
if "android.intent.action.SET_ALARM" not in s and "<queries>" in s:
    s = s.replace("<queries>", """<queries>
        <intent>
            <action android:name="android.intent.action.SET_ALARM" />
        </intent>""", 1)
open(path, "w", encoding="utf-8").write(s)

for g in glob.glob("android/app/build.gradle*"):
    t = open(g, encoding="utf-8").read()
    kts = g.endswith(".kts")
    if "CoreLibraryDesugaring" not in t and "coreLibraryDesugaring" not in t:
        flag = "        isCoreLibraryDesugaringEnabled = true\n" if kts else "        coreLibraryDesugaringEnabled true\n"
        if "compileOptions {" in t:
            t = t.replace("compileOptions {\n", "compileOptions {\n" + flag, 1)
        else:
            t = t.replace("android {\n", "android {\n    compileOptions {\n" + flag + "    }\n", 1)
        dep = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' if kts else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
        if re.search(r"^dependencies \{", t, re.M):
            t = re.sub(r"^dependencies \{", "dependencies {\n    " + dep, t, count=1, flags=re.M)
        else:
            t += "\ndependencies {\n    " + dep + "\n}\n"
        open(g, "w", encoding="utf-8").write(t)
print("알림·알람 설정 완료")
