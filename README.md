# Tap & Talk — bilingual (Arabic / English) AAC app

A child taps a picture; the app speaks the phrase and shows the picture large on screen.
Fully offline. Nothing leaves the device unless a caregiver copies the data out.

## Why Flutter
Native speech engine (`flutter_tts`), local storage only, one codebase, installable as a plain APK.

## Run it
1. Install Flutter, then in this folder: `flutter create --platforms=android,ios --project-name aac_tap_talk .`
   (adds the platform folders without touching `lib/` or `assets/`).
2. **Android** — in `android/app/src/main/AndroidManifest.xml`, inside `<manifest>` add:
   ```xml
   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
   <uses-permission android:name="android.permission.CAMERA"/>
   <queries><intent><action android:name="android.intent.action.TTS_SERVICE"/></intent></queries>
   ```
   and set `minSdkVersion 23` (or `minSdk = 23`) in `android/app/build.gradle`.
   **iOS** — in `ios/Runner/Info.plist` add `NSMicrophoneUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`.
3. `flutter pub get`, then `flutter run`. For a shareable file: `flutter build apk --release`.

Arabic speech needs an Arabic voice on the phone (Android: Settings > System > Languages > Text-to-speech,
install "Arabic"). If a device has none, use the caregiver's **record voice** option for that item.

## Add a picture and phrase

**Caregiver (no code):** gear icon > solve the question > **Add picture** > choose/take a photo,
type the English and Arabic label and spoken phrase, optionally record your own voice > **Save**.
Drag rows in the list to reorder. The grid order never changes on its own.

**Developer (starter set):**
1. Put a square-ish image in `assets/images/` (e.g. `bath.jpg`).
2. Add to `assets/items.json`: `{"id":"bath","image":"assets/images/bath.jpg"}`
   (use `"emoji":"🛁"` instead of `image` for an emoji icon).
3. Add four lines to **both** `assets/i18n/en.json` and `ar.json`: `item.bath.label` and `item.bath.phrase`.
4. Starter items are copied to device storage on first launch, so on an installed app use
   caregiver > **Reset to starter set** (or reinstall) to see new starter items.

## Where things live
| What | File |
|---|---|
| Starter item list | `assets/items.json` |
| UI + item text (en / ar) | `assets/i18n/en.json`, `assets/i18n/ar.json` |
| Data, storage, speech | `lib/store.dart` |
| Child screen | `lib/main.dart` |
| Gate, settings, editor | `lib/caregiver.dart` |

Data is stored with `shared_preferences` plus a private `media/` folder (photos, recordings).
**Copy data to clipboard** in caregiver settings exports the item list as JSON for backup.
