# Store-Readiness Audit — Nightlife Platform (`apps/mobile`)

**Scope:** App Store + Google Play submission readiness. Read-only audit. Target: `apps/mobile` only (`packages/nightlife_shared` ignored — dead code).
**Date:** 2026-07-01. **App version:** `1.0.0+1` (`apps/mobile/pubspec.yaml:19`).

Status legend: ✅ PASS · ❌ FIX-NOW (code/config, no external dependency) · ⏳ BLOCKED (boss / asset / paid account / Blaze) · ⚠️ VERIFY (check against live store docs or device).

---

## 1. Summary

| Status | Count |
|---|---|
| ✅ PASS | 17 |
| ❌ FIX-NOW | 12 |
| ⏳ BLOCKED | 7 |
| ⚠️ VERIFY | 8 |

### Verdict: 🚫 **CANNOT SUBMIT YET — multiple hard auto-rejects present.**

Both stores will auto-reject in the current state. The blocking issues are, in order:
1. **Default `com.example.*` bundle/application IDs** (both stores auto-reject).
2. **Default Flutter "blue F" app icon** on Android *and* iOS (both stores auto-reject).
3. **Placeholder Privacy Policy / Terms / support-email URLs** (`PLACEHOLDER-REPLACE-ME.example.com`) — both stores require a working privacy policy; these links open a dead domain.
4. **Android release is signed with the debug key** (Play refuses debug-signed uploads).
5. **Android Google Maps API key is a file path string, not a key** — Maps is broken on Android.
6. **Firebase Storage is disabled → every image-upload button is a visibly broken feature** (Apple 2.1 / Play broken-functionality).
7. **Placeholder display names** (`nl_flutter` / `Nl Flutter`) inconsistent with in-app "Nightlife Platform".

Most of #1–#7 are FIX-NOW *except* the ones needing a paid account / asset / Blaze (real icon asset, release keystore, enabling Storage or removing upload UI, hosted legal pages). See the two action lists below.

---

## 2. Action Lists

### ❌ FIX-NOW — code/config changes with no external dependency

| # | File:line | One-line fix |
|---|---|---|
| F1 | `apps/mobile/android/app/build.gradle.kts:13,29` | Change `namespace` + `applicationId` from `com.example.nl_flutter` to the real reverse-DNS id (e.g. `in.nightlifeapp.app`). |
| F2 | `apps/mobile/ios/Runner.xcodeproj/project.pbxproj:375,554,576` | Change `PRODUCT_BUNDLE_IDENTIFIER` from `com.example.nlFlutter` to the real id. |
| F3 | `apps/mobile/macos/Runner/Configs/AppInfo.xcconfig:11` | (If shipping macOS) change `com.example.nlFlutter`; else ignore macOS. |
| F4 | `apps/mobile/android/app/src/main/AndroidManifest.xml:10` | Change `android:label="nl_flutter"` → `"Nightlife Platform"` (match in-app name). |
| F5 | `apps/mobile/ios/Runner/Info.plist:10,18` | Change `CFBundleDisplayName` `Nl Flutter` and `CFBundleName` `nl_flutter` → `Nightlife Platform` / `Nightlife`. |
| F6 | `apps/mobile/macos/Runner/Configs/AppInfo.xcconfig:8,14` | `PRODUCT_NAME = nl_flutter` and copyright `com.example` → real values. |
| F7 | `apps/mobile/android/app/src/main/res/values/google_maps.xml:3` | Replace the **file-path string** with the actual Android Maps API key value. |
| F8 | `apps/mobile/lib/core/constants/app_constants.dart:6,8,12` | Replace the three `PLACEHOLDER-REPLACE-ME.example.com` URLs with real hosted Privacy/Terms URLs + real support email (needs the hosted pages to exist — see B1/B2 BLOCKED). |
| F9 | `apps/mobile/lib/screens/promoter/promoter_profile_screen.dart:127` | Referral link hardcodes `https://nightlife.app/` but deep links use `nightlifeapp.in` (AndroidManifest:41). Unify to one domain. |
| F10 | Every upload surface (see §E) | With Storage off, hide OR disable the profile-photo / venue-media / valid-ID upload buttons so a reviewer never hits a no-op that errors. Files: `profile_screen.dart:319`, `promoter_profile_screen.dart:132`, `club_profile_screen.dart:185`, `signup_screen.dart:237`. |
| F11 | `apps/mobile/ios/Runner/Info.plist:58-62` | Remove the `NSLocationTemporaryUsageDescriptionDictionary` (temporary/precise-on-demand) — the app only uses `whenInUse`; an unused key invites reviewer questions. (Optional hardening.) |
| F12 | `apps/mobile/lib/screens/user/event_details_screen.dart:1049,1052` | "Music/Crowd details coming soon" fallback strings read as unfinished to a reviewer — reword (e.g. "Not specified") or hide the row when empty. |

### ⏳ BLOCKED — needs boss decision / asset / paid account / Blaze

| # | Item | Blocker |
|---|---|---|
| B1 | Real hosted **Privacy Policy** page at a live URL. | Content + hosting decision (boss/legal). Feeds F8. |
| B2 | Real hosted **Terms of Service** page + real **support inbox**. | Same. Feeds F8. |
| B3 | Real **app icon** asset (1024² master → all densities + iOS set + Android adaptive). | Design asset. Current icons are the default Flutter logo (§A). |
| B4 | Android **release signing keystore** (`.jks` + `key.properties`, wired into a real `signingConfigs.release`). | Secret/keystore generation + secure storage decision. |
| B5 | **Enable Firebase Storage** (requires Blaze billing) OR ship v1 with all upload UI removed. | Paid account (Blaze) — or product decision to defer uploads. Drives F10. |
| B6 | **Demo/review credentials** for user + promoter + clubAdmin (app is login-gated). | Boss must provision + approve reviewer accounts. |
| B7 | Hosted **deep-link verification files** — `assetlinks.json` (Android App Links) and `apple-app-site-association` (iOS Universal Links) on the `nightlifeapp.in` domain, plus the iOS Associated Domains entitlement. | Domain/hosting + Apple team id (§H). Not blocking approval, but deep links silently fail without it. |

### ⚠️ VERIFY — check against live store docs / device

- V1: Android `targetSdk`/`compileSdk` resolve from the installed Flutter SDK (not pinned) — confirm the built AAB targets Play's current minimum (API 35 as of 2024-08; verify current) (§A).
- V2: iOS **Privacy Manifest** (`PrivacyInfo.xcprivacy`) is absent — verify whether the Firebase SDK versions in use ship their own, or whether the app needs its own required-reason-API + data-type declarations (§B).
- V3: Confirm the Google Maps API keys (Android value once fixed, iOS `Info.plist:28`) are **restricted** to the app's bundle id / SHA-1 in Google Cloud Console (§H).
- V4: Verify Apple **age rating** questionnaire + Google **IARC** content rating are completed for a nightlife/alcohol-adjacent 18+ app (§F).
- V5: Confirm on-device that account deletion completes end-to-end (reauth → Auth user gone) and that the "delete" entry is reachable in all 3 role UIs (§D — code path verified, device check recommended).
- V6: Verify no `NSUserTrackingUsageDescription` is needed — confirm the Firebase Analytics config does not enable cross-app tracking / IDFA (currently no ATT code present) (§B).
- V7: Confirm `ITSAppUsesNonExemptEncryption=false` (`Info.plist:29`) is accurate for the shipped crypto (standard HTTPS only → typically fine) (§B).
- V8: Verify the fallback event-poster assets (`assets/images/posters/`, `assets/images/nightlife/`) are owned/licensed for store distribution (§E).

---

## A. App identity & build config

| Check | Status | Evidence |
|---|---|---|
| Android applicationId | ❌ FIX-NOW | `android/app/build.gradle.kts:29` `applicationId = "com.example.nl_flutter"` (and `namespace` line 13). `com.example.*` is auto-rejected by Play. TODO comment still present at line 28,40. |
| iOS bundle id | ❌ FIX-NOW | `ios/Runner.xcodeproj/project.pbxproj:375,554,576` `PRODUCT_BUNDLE_IDENTIFIER = com.example.nlFlutter`. RunnerTests targets `…nlFlutter.RunnerTests` (391/408/423 — test-only, ignore). |
| macOS bundle id | ⚠️ VERIFY | `macos/Runner/Configs/AppInfo.xcconfig:11` `com.example.nlFlutter`. Only matters if macOS is a shipping target. |
| Android display name | ❌ FIX-NOW | `AndroidManifest.xml:10` `android:label="nl_flutter"`. |
| iOS display name | ❌ FIX-NOW | `Info.plist:10` `CFBundleDisplayName = "Nl Flutter"`, `:18` `CFBundleName = "nl_flutter"`. In-app name is `Nightlife Platform` (`lib/core/constants/app_constants.dart:2`) — mismatch. |
| **App icon (Android)** | ❌ FIX-NOW / ⏳ B3 | `res/mipmap-*/ic_launcher.png` are the **default Flutter blue-"F" icon** (verified by rendering `mipmap-xxxhdpi/ic_launcher.png`; sizes 442–1443 B match stock template). No adaptive icon (no `mipmap-anydpi-v26`/foreground). Auto-reject on Play. |
| **App icon (iOS)** | ❌ FIX-NOW / ⏳ B3 | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` has a full size set, but `Icon-App-1024x1024@1x.png` renders as the **default Flutter logo**. Auto-reject on App Store. |
| Version | ✅ PASS | `pubspec.yaml:19` `version: 1.0.0+1` → Android versionName/Code + iOS `CFBundleShortVersionString`/`CFBundleVersion` via `$(FLUTTER_BUILD_*)`. Sane for first release. |
| **Android release signing** | ❌ FIX-NOW / ⏳ B4 | `build.gradle.kts:42` `signingConfig = signingConfigs.getByName("debug")` in the `release` block. No `key.properties`/`.jks` present. Debug-signed builds **cannot be published to Play**. |
| Android output = AAB | ⚠️ VERIFY | No explicit bundle config needed (Play accepts AAB via `flutter build appbundle`); confirm the CI/build command produces `.aab`, not `.apk`. R8/shrink is enabled (`build.gradle.kts:46-51`) with real `proguard-rules.pro` — good. |
| targetSdk/compileSdk | ⚠️ VERIFY (V1) | `build.gradle.kts:14,33` use `flutter.compileSdkVersion` / `flutter.targetSdkVersion` (resolved from the installed Flutter SDK, not pinned; `.metadata` = stable channel). Confirm the produced AAB targets Play's current minimum API. |

---

## B. Privacy & data disclosure

| Check | Status | Evidence |
|---|---|---|
| Privacy Policy URL | ❌ FIX-NOW / ⏳ B1 | `app_constants.dart:6-7` `privacyPolicyUrl = 'https://PLACEHOLDER-REPLACE-ME.example.com/privacy'`. |
| Terms URL | ❌ FIX-NOW / ⏳ B2 | `app_constants.dart:8-9` `termsOfServiceUrl = '…/terms'` (placeholder). |
| Support email | ❌ FIX-NOW / ⏳ B2 | `app_constants.dart:12-13` `supportEmail = 'support@PLACEHOLDER-REPLACE-ME.example.com'`. |
| Links rendered & tappable | ✅ PASS | Wired to `AppConstants` and rendered on Welcome (`welcome_screen.dart:124,126`), Promoter profile (`promoter_profile_screen.dart:334,339`), Club profile (`club_profile_screen.dart:470,475`), User settings (`user_settings_screen.dart:140,146`), Help (`help_support_screen.dart:189,209`). They *work* — they just point at a dead domain until F8. |

### Data Collection Inventory (for Apple App Privacy + Google Data Safety)

| Data type | Collected where | Destination | Purpose |
|---|---|---|---|
| Name, email, phone | `auth_service.dart:334-368` (`saveCurrentUserProfile`) | Firestore `users/{uid}` | Account creation / app functionality. |
| Password | FirebaseAuth (`signUp`/`signIn`) | Firebase Auth | Authentication (not stored in Firestore). |
| Date of birth, gender | `auth_service.dart:341-343`; signup fields | Firestore `users/{uid}` | Age gate (18+) / profile. |
| Instagram / Snapchat IDs | `auth_service.dart:342-343` | Firestore `users/{uid}` | Profile (optional). |
| **Government/valid ID image** | `signup_screen.dart:182` → `storage_service.dart:39` `valid_ids/{uid}/…` | Firebase Storage | Venue/promoter verification (sensitive). Currently non-functional (Storage off). |
| Profile / venue photos | `storage_service.dart:62,114` `profile_photos/{uid}/…` | Firebase Storage | Profile media (currently non-functional). |
| **Precise location** (GPS) | `location_service.dart:79-95` (`LocationAccuracy.high`) | Firestore `users/{uid}` (`updateUserLastKnownLocation`, `firestore_service.dart:1354`) + on-device distance | Nearby events / distance / map. Stored server-side → must be disclosed as **precise location, linked to user**. |
| Coarse location / city | derived from geocode | Firestore `users/{uid}.lastKnownCity` | Event filtering. |
| **FCM push token** | `notification_service.dart:84-92` | Firestore `users/{uid}.fcmToken` | Push notifications. |
| Crash data | `main.dart:26-38` FirebaseCrashlytics (native only) | Firebase Crashlytics | Stability / diagnostics. |
| Analytics events | `analytics_service.dart` (screen views, login, RSVP funnel, search, city) | Firebase Analytics | Product analytics. |
| IP address | implicit (Firebase/GMP backend) | Google | Standard backend telemetry — disclose. |

> Both questionnaires must reflect **precise location + a government-ID upload + analytics**. Under-disclosure here is a common rejection.

| iOS Privacy Manifest | ⚠️ VERIFY (V2) | No `PrivacyInfo.xcprivacy` anywhere under `apps/mobile/ios`. Verify whether the bundled Firebase SDK versions supply their own required-reason-API/data manifests or the app must add one (Apple requires privacy manifests for apps using required-reason APIs). |
| ATT / tracking | ✅ PASS (V6) | No `google_sign_in`/IDFA/ATT code; no `NSUserTrackingUsageDescription`. Analytics/Crashlytics as configured are first-party (not cross-app tracking) → ATT prompt not required *unless* IDFA/tracking is enabled in the Firebase console (verify V6). |
| Non-exempt encryption | ✅ PASS (V7) | `Info.plist:29-30` `ITSAppUsesNonExemptEncryption = false`. Correct for standard HTTPS-only; verify no custom crypto is added (V7). |

---

## C. Permissions

**iOS `Info.plist` usage strings:**
| Key | Line | Status |
|---|---|---|
| `NSLocationWhenInUseUsageDescription` | 56-57 | ✅ present, reads sensibly ("nearby events, venue distance, map directions"). |
| `NSLocationTemporaryUsageDescriptionDictionary` (`NearbyEvents`) | 58-62 | ⚠️ unused — app never requests temporary precise auth. Recommend removing (F11). |
| `NSPhotoLibraryUsageDescription` | 63-64 | ✅ present (profile pic + valid ID). Note: real photo use is currently broken (Storage off). |
| Background mode `remote-notification` | 95-98 | ✅ justified by FCM. No unused background modes. |

- **No `NSCameraUsageDescription`** — correct, `ImagePicker` uses `ImageSource.gallery` only (`profile_screen.dart:320`, `signup_screen.dart:238`, etc.). ✅

**Android `uses-permission` (`AndroidManifest.xml`):**
| Permission | Line | Status |
|---|---|---|
| `INTERNET` | 2 | ✅ required. |
| `ACCESS_FINE_LOCATION` | 3 | ✅ used (`location_service.dart` high accuracy). |
| `ACCESS_COARSE_LOCATION` | 4 | ✅ used. |
| `POST_NOTIFICATIONS` | 7 | ✅ Android 13+; requested at runtime by `notification_service.dart:35`. |
| Background location | — | ✅ PASS — **no `ACCESS_BACKGROUND_LOCATION`** → avoids the Play background-location declaration form. |

- **Location consent rationale before OS prompt** — ✅ PASS. `ensureLocationPermissionWithRationale` (`location_permission_flow.dart:102-121`) shows the rationale dialog *then* calls `LocationService.requestPermission()`, and is used at every location entry point: home (`home_screen.dart:169`), map view (`map_view_screen.dart:194`), venue picker (`venue_location_picker.dart:141`).

---

## D. Account & data lifecycle

| Check | Status | Evidence |
|---|---|---|
| In-app account deletion exists | ✅ PASS | Shared flow `widgets/delete_account_dialogs.dart` (two-step confirm + password). |
| Reachable for all 3 roles | ✅ PASS (V5) | User: `user_settings_screen.dart:74,162` ("Delete account"). Promoter: `promoter_profile_screen.dart:250,364`. Club admin: `club_profile_screen.dart:283,501`. |
| Actually deletes Firebase Auth user | ✅ PASS | `auth_service.dart:612` `await user.delete()` after the Firestore soft-delete batch and Storage cleanup. Not soft-delete-only. |
| Data retention to disclose | ⚠️ note | Soft-delete writes `deletedAt` + `isActive:false`, `status:'rejected'` on `users`/`promoters`/`clubs`/`referralCodes` (`auth_service.dart:561-591`) **before** the Auth delete. Disclose that some records are retained (marked deleted) rather than immediately purged. |

---

## E. Functional completeness (no broken/placeholder features)

**Image upload = the top functional-rejection risk.** Firebase Storage is not enabled (`storage_service.dart:169` "Storage is not enabled yet (pending Blaze)"; `auth_service.dart:602`; `signup_screen.dart:173`). Every upload surface picks an image, shows a progress spinner, then fails with an error snackbar — a reviewer sees a **broken feature** (Apple 2.1/4.2, Play).

| Surface | File:line | Reviewer sees | Recommendation |
|---|---|---|---|
| User profile photo | `profile_screen.dart:319-411` | picks image → spinner → `FirebaseException` → error snackbar (`:411`). **Broken.** | Hide/disable the "change photo" affordance until Storage is on (F10). |
| Promoter avatar | `promoter_profile_screen.dart:132-198` | same broken path → snackbar (`:196`). | Hide/disable. |
| Venue media (profile/cover) | `club_profile_screen.dart:185-233` | same. | Hide/disable. |
| Valid-ID upload (signup) | `signup_screen.dart:237` → `:182` | Upload is **best-effort/non-fatal** (`:189-193` swallows failure; signup still succeeds) → less severe, but the "Choose from gallery"/"Uploaded for review" UI (`:1040,1010`) implies a working upload that doesn't persist. | Disable the ID picker or relabel so it doesn't promise a stored document. |
| Event poster upload | `storage_service.dart:23` | Reachable only if the clubAdmin create-event UI exposes a poster picker — verify; if exposed, same broken path. | Verify + hide if present. |

**Other placeholder/broken-feature scan:**
- "Music/Crowd details coming soon" — `event_details_screen.dart:1049,1052` (empty-field fallbacks; reword — F12). ⚠️
- Favorites "Liked Clubs" is a static placeholder ("Favorite venues will be listed here.") with no data — a dead section a reviewer may flag. `favorites_screen.dart` (`_FavoriteSection` "Liked Clubs"). ❌ recommend hiding until saved-clubs UI ships.
- No `lorem`/`demo`/`seed`/fake-metrics found in product code. Promoter dashboard explicitly uses real RSVP counts only (`promoter_dashboard_screen.dart:278,459,1253`). ✅
- **No hardcoded credentials / test accounts** in `lib/` (`superadmin@…`, `test@…`, passwords) — none found. ✅
- `firebase_options.dart:44-78` contains Firebase **client API keys** — these are **not secrets** (they identify, not authorize) and are expected to ship. ✅ (Access control is enforced by `firestore.rules`/`storage.rules`.)

---

## F. Age rating & content

| Check | Status | Evidence |
|---|---|---|
| 18+ DOB gate on user signup | ✅ PASS | `signup_screen.dart:354-372` shared `_dobField()` validator: rejects `< 18` with "You must be at least 18 years old" (`:371`); date picker `lastDate` = 18 years ago (`:80-83`). |
| 18+ DOB gate on promoter signup | ✅ PASS | Same `_dobField()` is used for BOTH roles — "Gender + DOB (with 18+ age gate) apply to BOTH User and Promoter" (`:588,593`); DOB passed for promoters too (`:151-153`). |
| Mature age rating implications | ⚠️ VERIFY (V4) | Nightlife/alcohol-adjacent → will need a mature rating (Apple age rating questionnaire; Google IARC). Complete both questionnaires honestly (alcohol references, user-generated content, 18+). |

---

## G. Login & review access

| Check | Status | Evidence |
|---|---|---|
| App is login-gated | ⚠️ note / ⏳ B6 | `RoleRouterScreen` requires auth before any events are visible. Reviewers need working demo credentials for **user + promoter + clubAdmin** — provide in App Store Connect "App Review Information" and Play "App access". |
| Email/password only | ✅ PASS | No `google_sign_in` / `sign_in_with_apple` / Facebook / OAuth anywhere in `lib/`. |
| Sign in with Apple required? | ✅ PASS | **No** — Apple mandates Sign in with Apple only when a third-party/social login is offered. This app offers only first-party email/password, so SIWA is not required. |

---

## H. Deep links & external services

| Check | Status | Evidence |
|---|---|---|
| Android App Links | ⚠️ / ⏳ B7 | `AndroidManifest.xml:37-43` has `android:autoVerify="true"` intent filters for `https://nightlifeapp.in` + `www.` — but **no `assetlinks.json`** exists in the repo (it must be hosted at `https://nightlifeapp.in/.well-known/assetlinks.json`). Without it, `https` App Links won't auto-verify. Custom scheme `nightlife://open` (`:44-49`) works without verification. |
| iOS Universal Links | ⚠️ / ⏳ B7 | **No `.entitlements` file** and no Associated Domains under `apps/mobile/ios` → universal links unconfigured. Custom URL scheme `nightlife` is registered (`Info.plist:82-93`) and works. `apple-app-site-association` not present (host-side). |
| Domain consistency | ❌ FIX-NOW (F9) | Deep links use `nightlifeapp.in` (manifest) but the promoter referral link hardcodes `https://nightlife.app/` (`promoter_profile_screen.dart:127`). A tapped referral link would not route back into the app. Unify. |
| Google Maps key (Android) | ❌ FIX-NOW (F7) | `res/values/google_maps.xml:3` value is the literal string `apps/mobile/android/app/src/main/res/values/google_maps.xml` (a **path, not a key**), referenced by `AndroidManifest.xml:13-15`. Maps SDK will fail to authenticate on Android. |
| Google Maps key (iOS) | ✅ PASS / ⚠️ V3 | `Info.plist:27-28` `GoogleMapsApiKey = AIzaSyCKtdhajms0wCdKgHh7cliQZ4I7q-eNSsE` (a real key). Verify it is **restricted** to the iOS bundle id (V3). |
| FCM / notifications wired | ✅ PASS | `notification_service.dart:28-82` init, Android channel `nightlife_high`, permission request (`:35`), token persisted (`:84`), iOS `UIBackgroundModes: remote-notification` (`Info.plist:95-98`), Android `POST_NOTIFICATIONS` runtime request. |

---

## I. Stability & manifest hygiene

| Check | Status | Evidence |
|---|---|---|
| Crashlytics + global handlers | ✅ PASS | `main.dart:26-38` `FlutterError.onError` + `PlatformDispatcher.instance.onError` → Crashlytics (native), plus `AppErrorBoundary` (`:132-188`) fallback UI. Crashlytics disabled on web only. |
| Empty/offline states | ✅ PASS (mostly) | Screens use `StreamBuilder`/`FutureBuilder` with `LoadingView`/`ErrorStateView` (`state_views.dart`); Firestore offline persistence on (`main.dart:50-53`); `RoleRouterScreen:58-66` handles profile-load error. Recommend a device pass on airplane mode (V5-adjacent). |
| Unawaited futures / sensitive logging | ✅ PASS | Only `debugPrintStack(stackTrace:)` used (16 sites) — no `print()`, and no GPS/token/email logged. `debugPrint` is a no-op in release builds. |
| `android:exported` explicit | ✅ PASS | `AndroidManifest.xml:18` `MainActivity android:exported="true"` (required for the LAUNCHER + deep-link filters). Only one component. |
| `usesCleartextTraffic` | ✅ PASS | Not set → defaults to false on modern targets. Debug manifest only adds `INTERNET` (`src/debug/AndroidManifest.xml`), no cleartext. |
| `android:allowBackup` | ⚠️ VERIFY | Not explicitly set in `AndroidManifest.xml` → defaults to `true`. Not a blocker, but consider `android:allowBackup="false"` given auth/location data. |

---

## Appendix — files inspected
`android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/{debug,profile}/AndroidManifest.xml`, `android/app/src/main/res/values/google_maps.xml`, `android/app/src/main/res/mipmap-*/ic_launcher.png`, `android/app/proguard-rules.pro`, `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`, `macos/Runner/Configs/AppInfo.xcconfig`, `lib/core/constants/app_constants.dart`, `lib/main.dart`, `lib/firebase_options.dart`, `lib/services/{auth,firestore,storage,notification,location,analytics}_service.dart`, `lib/widgets/{location_permission_flow,delete_account_dialogs}.dart`, `lib/screens/auth/{signup,welcome,login,role_router}_*.dart`, `lib/screens/user/{profile,user_settings,favorites,event_details,help_support}_screen.dart`, `lib/screens/promoter/promoter_{profile,dashboard}_screen.dart`, `lib/screens/club/club_{profile,admin_dashboard}_screen.dart`, `pubspec.yaml`, `firebase.json`, `firestore.rules`, `storage.rules`.
