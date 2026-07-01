# Migration Checklist — pre-submission value swaps

Documentation only. Nothing here is changed automatically — this is the exact
list of files+lines where placeholder / default values live so the real values
can be swapped in mechanically before Play Store / App Store submission.

Line numbers were accurate at the time of writing; re-grep if the files have
moved. Generated (not hand-maintained) files — `google-services.json`,
`GoogleService-Info.plist`, `firebase_options.dart`, `apps/mobile/firebase.json`
— should ideally be **regenerated** via `flutterfire configure` against the
company Firebase project rather than hand-edited, which will update the project
ID, app IDs, and API keys together.

---

## 1. Bundle ID / applicationId

Current defaults: `com.example.nl_flutter` (Android), `com.example.nlFlutter` (iOS).
Neither store accepts a `com.example.*` id.

**Android**
- `apps/mobile/android/app/build.gradle.kts:13` — `namespace = "com.example.nl_flutter"`
- `apps/mobile/android/app/build.gradle.kts:29` — `applicationId = "com.example.nl_flutter"`
- `apps/mobile/android/app/google-services.json:12` — `"package_name": "com.example.nl_flutter"` (regenerate)
- `apps/mobile/android/app/src/main/kotlin/com/example/nl_flutter/MainActivity.kt:1` — `package com.example.nl_flutter` (also move the file to the new package folder path)

**iOS**
- `apps/mobile/ios/Runner.xcodeproj/project.pbxproj:375` — `PRODUCT_BUNDLE_IDENTIFIER = com.example.nlFlutter;`
- `apps/mobile/ios/Runner.xcodeproj/project.pbxproj:554` — `PRODUCT_BUNDLE_IDENTIFIER = com.example.nlFlutter;`
- `apps/mobile/ios/Runner.xcodeproj/project.pbxproj:576` — `PRODUCT_BUNDLE_IDENTIFIER = com.example.nlFlutter;`
- `apps/mobile/ios/Runner.xcodeproj/project.pbxproj:391` — `...nlFlutter.RunnerTests;` (test target)
- `apps/mobile/ios/Runner.xcodeproj/project.pbxproj:408` — `...nlFlutter.RunnerTests;` (test target)
- `apps/mobile/ios/Runner.xcodeproj/project.pbxproj:423` — `...nlFlutter.RunnerTests;` (test target)
- `apps/mobile/ios/Runner.xcodeproj/GoogleService-Info.plist:12` — `com.example.nlFlutter` (regenerate)

**Dart (generated — prefer regenerating)**
- `apps/mobile/lib/firebase_options.dart:66` — `iosBundleId: 'com.example.nlFlutter',` (ios)
- `apps/mobile/lib/firebase_options.dart:74` — `iosBundleId: 'com.example.nlFlutter',` (macos)

---

## 2. App display name

Current default project name shows as `nl_flutter` / `Nl Flutter`. The in-app
`AppConstants.appName` is already `'Nightlife Platform'`; only the native/web
display names below are still the default.

- `apps/mobile/android/app/src/main/AndroidManifest.xml:10` — `android:label="nl_flutter"`
- `apps/mobile/ios/Runner/Info.plist:10` — `<string>Nl Flutter</string>` (CFBundleDisplayName)
- `apps/mobile/ios/Runner/Info.plist:18` — `<string>nl_flutter</string>` (CFBundleName)
- `apps/mobile/web/manifest.json:2` — `"name": "nl_flutter",`
- `apps/mobile/web/manifest.json:3` — `"short_name": "nl_flutter",`
- `apps/mobile/web/manifest.json:8` — `"description": "A new Flutter project."` (also default; update if the PWA ships)

---

## 3. Firebase project ID

Current: `party-app-1774e` (personal project). Confirm the company project ID,
then prefer `flutterfire configure` to regenerate all four generated files at
once (it also refreshes app IDs, API keys, storage bucket, and auth domain).

**Root config**
- `firebase.json:6` — `"projectId": "party-app-1774e"` (android default)
- `firebase.json:13` — `"projectId": "party-app-1774e"` (dart)
- `.firebaserc:3` — `"default": "party-app-1774e"`

**Mobile app config (generated)**
- `apps/mobile/firebase.json:1` — single-line JSON, two `"projectId":"party-app-1774e"` occurrences
- `apps/mobile/android/app/google-services.json:4` — `"project_id": "party-app-1774e"`
- `apps/mobile/android/app/google-services.json:5` — `"storage_bucket": "party-app-1774e.firebasestorage.app"`
- `apps/mobile/ios/Runner.xcodeproj/GoogleService-Info.plist` — `PROJECT_ID` / `STORAGE_BUCKET` / `GCM_SENDER_ID` (regenerate)

**Dart (generated — `apps/mobile/lib/firebase_options.dart`)**
- `:47` `projectId: 'party-app-1774e',` (web)
- `:48` `authDomain: 'party-app-1774e.firebaseapp.com',` (web)
- `:49` `storageBucket: 'party-app-1774e.firebasestorage.app',` (web)
- `:57` `projectId: 'party-app-1774e',` (android)
- `:58` `storageBucket: 'party-app-1774e.firebasestorage.app',` (android)
- `:64` `projectId: 'party-app-1774e',` (ios)
- `:65` `storageBucket: 'party-app-1774e.firebasestorage.app',` (ios)
- `:72` `projectId: 'party-app-1774e',` (macos)
- `:73` `storageBucket: 'party-app-1774e.firebasestorage.app',` (macos)
- `:81` `projectId: 'party-app-1774e',` (windows)
- `:82` `authDomain: 'party-app-1774e.firebaseapp.com',` (windows)
- `:83` `storageBucket: 'party-app-1774e.firebasestorage.app',` (windows)

> Note: `firebase_options.dart` and the two GoogleService files also contain the
> Firebase **API keys** and numeric **app IDs** (sender id `338930228171`, app ids
> `1:338930228171:...`). These are tied to the project and are refreshed together
> when you regenerate with `flutterfire configure`.

---

## 4. Placeholder URLs / email

All three live in `apps/mobile/lib/core/constants/app_constants.dart` and use the
`PLACEHOLDER-REPLACE-ME.example.com` sentinel. They must be replaced with the
real hosted legal pages / support inbox before submission.

- `apps/mobile/lib/core/constants/app_constants.dart:6-7` — `privacyPolicyUrl` = `https://PLACEHOLDER-REPLACE-ME.example.com/privacy`
- `apps/mobile/lib/core/constants/app_constants.dart:8-9` — `termsOfServiceUrl` = `https://PLACEHOLDER-REPLACE-ME.example.com/terms`
- `apps/mobile/lib/core/constants/app_constants.dart:12-13` — `supportEmail` = `support@PLACEHOLDER-REPLACE-ME.example.com`

These constants are the single source of truth; every in-app Privacy/Terms link
(welcome, user Settings, Help & Support, promoter profile, club profile) and the
support-email links (Help & Support, profile help sheet) already read from them,
so only these three lines need editing.

---

## 5. Related (not blockers, but tied to the same rename)

- `apps/mobile/lib/screens/promoter/promoter_profile_screen.dart:127` — promoter
  referral deep-link base `https://nightlife.app/?ref=$_referralCode`. Confirm the
  production web domain; it must match the Android App Links host
  (`apps/mobile/android/app/src/main/AndroidManifest.xml`, `nightlifeapp.in`) and
  the iOS associated-domain / `CFBundleURLTypes` (`apps/mobile/ios/Runner/Info.plist`).
- Google Maps API keys are hardcoded and should be platform/bundle-restricted in
  GCP after the bundle IDs change:
  - `apps/mobile/ios/Runner/Info.plist:28` (`GoogleMapsApiKey`)
  - `apps/mobile/android/app/src/main/res/values/google_maps.xml` (currently holds
    an invalid non-key string — needs a real, restricted Android Maps key)
  - `apps/mobile/web/index.html:22` (Maps JS SDK key)
