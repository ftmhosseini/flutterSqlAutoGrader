# Mobile Deployment Guide — SQL Auto Grader Flutter App

**App ID (Android):** `com.cirook.sql`  
**Bundle ID (iOS):** `com.cirook.sql.ios`  
**Version:** `0.1.0+1` (versionName+versionCode in `pubspec.yaml`)  
**Firebase:** enabled (Firestore + Auth)

---

## Overview

| Platform | Store | Format |
|---|---|---|
| Android | Google Play | AAB (App Bundle) |
| iOS | App Store | IPA |

---

## Phase 1 — One-Time Setup

### Step 1 — Fix signing config in build.gradle.kts

Currently the release build uses debug keys — this must be fixed before uploading to any store.

**Create a keystore:**
```bash
keytool -genkey -v \
  -keystore ~/sql-grader-release.jks \
  -alias sql-grader-key \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

```bash
keytool -list -v -keystore path to sql-grader-release.jks
```

> ⚠️ Back up `~/sql-grader-release.jks` — losing it means you can never update the app.

**Create `android/key.properties`** (do not commit to git):
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=sql-grader-key
storeFile=/Users/fatemeh/sql-grader-release.jks
```

**Update `android/app/build.gradle.kts`** — replace the release signingConfig:
```kotlin
// Add before android {} block:
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) keyProperties.load(FileInputStream(keyPropertiesFile))

// Inside android {} block, add:
signingConfigs {
    create("release") {
        keyAlias = keyProperties["keyAlias"] as String
        keyPassword = keyProperties["keyPassword"] as String
        storeFile = file(keyProperties["storeFile"] as String)
        storePassword = keyProperties["storePassword"] as String
    }
}

// Change release buildType to:
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

**Add `key.properties` to `.gitignore`:**
```
android/key.properties
```

### Step 2 — Fix version in pubspec.yaml

```yaml
version: 1.0.0+1   # versionName+versionCode
                    # increment +1 (versionCode) for every upload
```

### Step 3 — Create Google Play Developer Account

1. Go to [play.google.com/console](https://play.google.com/console)
2. Pay **$25 one-time fee**
3. Complete identity verification
4. Create app → App name: `SQL Auto Grader` → Free → Create

### Step 4 — Create Apple Developer Account (for App Store)

1. Go to [developer.apple.com](https://developer.apple.com)
2. Pay **$99/year**
3. Enroll as Individual or Organization
4. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → New App
   - Platform: iOS
   - Bundle ID: `ca.arzook.sql_auto_grader`
   - SKU: `sql-auto-grader`

---

## Phase 2 — Build & Upload Each Release

### Bump version (every release)

In `pubspec.yaml`:
```yaml
version: 1.0.1+2   # increment the number after + each time
```

### Android — Build AAB

```bash
cd /Users/fatemeh/Desktop/SQL-Auto-Grader/flutter/sql_auto_grader
flutter clean
flutter pub get
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

**Upload to Play Console:**
1. Play Console → SQL Auto Grader → **Release → Production**
2. Create new release → Upload AAB
3. Add release notes → Review → Start rollout

### iOS — Build IPA

> Requires a Mac with Xcode installed and an Apple Developer account.

```bash
flutter clean
flutter pub get
flutter build ipa --release
```

Output: `build/ios/ipa/sql_auto_grader.ipa`

**Upload to App Store Connect:**

Option A — Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Product → Archive
3. Distribute App → App Store Connect → Upload

Option B — Transporter app (simpler):
1. Download [Transporter](https://apps.apple.com/app/transporter/id1450874784) from Mac App Store
2. Drag and drop the `.ipa` file
3. Click Deliver

Then in App Store Connect:
1. Go to your app → TestFlight or App Store tab
2. Select the build → Submit for review

---

## Store Listing Requirements (first release only)

### Google Play (required before approval)
- [ ] Short description (80 chars)
- [ ] Full description (4000 chars)
- [ ] App icon: 512×512 PNG
- [ ] Feature graphic: 1024×500 PNG
- [ ] At least 2 phone screenshots
- [ ] Privacy policy URL
- [ ] Content rating questionnaire
- [ ] Data safety form

### App Store (required before approval)
- [ ] App description
- [ ] App icon: 1024×1024 PNG (no alpha)
- [ ] At least 3 iPhone screenshots
- [ ] Privacy policy URL
- [ ] Age rating questionnaire
- [ ] App privacy details (data collection)

---

## Checklist Before First Submission

- [ ] `key.properties` created and `build.gradle.kts` updated (Android)
- [ ] `key.properties` added to `.gitignore`
- [ ] Keystore backed up safely
- [ ] Version bumped in `pubspec.yaml`
- [ ] Store listings complete on both platforms
- [ ] Privacy policy URL live (can use `sql.cirook.com/privacy`)
- [ ] Firebase rules reviewed for production

---

## Subsequent Releases (quick steps)

1. Make code changes
2. Increment version in `pubspec.yaml` (e.g. `1.0.1+2` → `1.0.2+3`)
3. `flutter build appbundle --release` → upload AAB to Play Console
4. `flutter build ipa --release` → upload IPA via Transporter
5. Add release notes on both platforms → submit

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "Version code already used" | Increment the number after `+` in `pubspec.yaml` |
| "App not signed" | Check `key.properties` path and passwords |
| iOS build fails | Run `pod install` in `ios/` folder, then retry |
| Firebase not working in release | Check `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are present |
| App rejected — missing privacy policy | Add a privacy policy page to `sql.cirook.com` |

---

## File Locations

| File | Path |
|---|---|
| Android keystore | `~/sql-grader-release.jks` (back up!) |
| Android signing config | `android/key.properties` |
| Android AAB output | `build/app/outputs/bundle/release/app-release.aab` |
| iOS IPA output | `build/ios/ipa/sql_auto_grader.ipa` |
| Firebase config (Android) | `android/app/google-services.json` |
| Firebase config (iOS) | `ios/Runner/GoogleService-Info.plist` |
