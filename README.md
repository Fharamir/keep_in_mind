# Keep in Mind (KIM) 🧠📱

[![Version](https://img.shields.io/badge/version-1.0.0%2B1-blue.svg)](pubspec.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Privacy: Zero Cloud](https://img.shields.io/badge/Privacy-100%25%20Local--First-brightgreen.svg)](PRIVACY_POLICY.md)
[![Platform: Android](https://img.shields.io/badge/Platform-Android%20(minSdk%2021)-orange.svg)](android/)

> **100% Local-First Share-to-Self app with a native Android Home Screen widget.**  
> Keep your thoughts, articles, photos, voice notes, videos, and documents organized privately on your device. No cloud, no tracking, no accounts.  
> 
> Read our full [Privacy Policy](PRIVACY_POLICY.md).  
> *Please note: this app is created with the aid of AI tools.*

---

## ✨ Features

- 📤 **Native Headless & Interactive Share-to-Self Target:**
  - Share links, texts, single or multiple images (`ACTION_SEND_MULTIPLE`), and documents from any Android app (Browser, YouTube, Gallery, Files) directly to Keep in Mind without opening the app UI.
  - Automatic file size checks with configurable limits and localized confirmation toasts across all supported languages.
- 🧩 **Native Android Home Screen Widget:**
  - Configurable to display between 1 and 5 recent or pinned items.
  - Interactive scrollable list (`ListView` + `RemoteCollectionItems`) on Android 12+ (API 31+).
  - Direct tap to view, add (`+`), or open full library.
  - Instant background updates whenever content is shared or modified.
- 🎙️ **Voice Notes, Camera & Native Media Playback:**
  - Record voice notes with configurable time limits or capture photos directly into your local library.
  - **In-App Audio Player**: Built-in player with play, pause, progress scrubbing, and duration tracking.
  - **In-App Video Player**: Native video rendering (`PlatformView` via `VideoView`) directly in item details without requiring external viewers.
  - **Text Previews**: In-line text preview for text documents and attachments.
- 🏷️ **Smart Categorization & Search:** Auto-detects URLs, domains, attachments, and MIME types. Filter by tags or pinned status with instant search.
- 🛡️ **Privacy & Zero Cloud:**
  - All content and attachments reside exclusively in internal application storage (`dev.fharamir.keepinmind`).
  - Strict path traversal protection, URI scheme sanitization, and sandboxed file access via Android `FileProvider`.
  - Zero analytics, zero trackers, zero network requests for telemetry.
- 📦 **JSON Backup & Restore:**
  - Export your entire library anytime to a portable JSON file (including base64 encoded attachments).
  - Restore on any new device or installation seamlessly.
- 🌍 **Multi-Language Support (7 Languages):**
  - English, Italiano, Español, Français, Deutsch, Português, 中文.
  - Automatically matches OS system locale with optional in-app manual override.

---

## 🏗️ Architecture

```
keep_in_mind/
├── android/                                 # Android native platform code (dev.fharamir.keepinmind)
│   ├── app/
│   │   ├── build.gradle.kts                # Build config with release signing & debug fallback
│   │   └── src/main/
│   │       ├── AndroidManifest.xml          # Permissions, share target filters, widget receiver
│   │       └── kotlin/dev/fharamir/keepinmind/
│   │           ├── KeepInMindWidgetProvider.kt # AppWidgetProvider (RemoteCollectionItems & ListView)
│   │           └── MainActivity.kt          # Headless share receiver, audio/video player, camera bridge
├── assets/
│   └── icons/                               # App icon and adaptive foreground assets
├── lib/
│   ├── l10n/                                # Multi-language localizations (7 languages)
│   ├── models/                              # MemoryItem domain model and JSON serializers
│   ├── services/                            # StorageService, ShareIntentService, WidgetSyncService
│   ├── ui/
│   │   ├── screens/                         # HomeScreen, ItemDetailScreen, WidgetSettingsScreen
│   │   └── widgets/                         # AddMemorySheet, HomeWidgetPreview, MemoryItemCard
│   └── utils/                               # LocalFileHelper (sandboxed I/O), TagHelper
├── test/                                    # Unit and widget test suite
├── PRIVACY_POLICY.md                        # Zero-tracking privacy commitment
└── LICENSE                                  # MIT License
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (stable channel, 3.47+)
- Dart SDK (^3.13.5)
- Android SDK (API 34+ recommended, minSdk 21)
- Java 17
- Android Gradle Plugin (AGP) 9.1.0 / Kotlin 2.4.0

### Installation & Run

```bash
# Clone the repository
git clone https://github.com/Fharamir/keep_in_mind.git
cd keep_in_mind

# Install dependencies
flutter pub get

# Run test suite
flutter test

# Run on connected Android device (Debug mode)
flutter run
```

---

## 📦 Building for Release

### 1. Configure Keystore (Optional for Local Builds)

The Gradle configuration (`android/app/build.gradle.kts`) automatically falls back to your debug keystore if no release key is provided.

To sign a production release build, create `android/key.properties`:

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=path/to/your/upload-keystore.jks
```

> **Note**: `key.properties` and keystore files (`*.jks`, `*.keystore`) are strictly ignored by `.gitignore`.

### 2. Build APK or App Bundle

```bash
# Build release APK
flutter build apk --release

# Build Google Play App Bundle
flutter build appbundle --release
```

The resulting binaries will be located in `build/app/outputs/flutter-apk/` and `build/app/outputs/bundle/release/`.

---

## 🧪 Testing

The automated test suite verifies:
- Share payload parsing and URL/domain auto-detection.
- Widget item selection algorithm and pin prioritization.
- Audio and file size constraint configurations.
- Multi-language resolution, fallback, and dynamic runtime override.
- Import JSON security hardening (rejection of `javascript:`, directory traversal sanitization, type coercion).

```bash
flutter test
```

---

## 🔒 Privacy Policy

Keep in Mind is built with user privacy and data ownership as its core foundation:
- **Zero Cloud / Zero Data Collection**: No remote analytics, no tracking, no third-party telemetry.
- **Hardware Permissions**: `android.permission.CAMERA` and `android.permission.RECORD_AUDIO` are requested exclusively at runtime when you choose to capture a photo or record a voice note.
- For complete details, see [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md).

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

