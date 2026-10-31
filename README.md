# Keep in Mind (KIM) 🧠📱

> **100% Local-First Share-to-Self app with a native Android Home Screen widget.**  
> Keep your thoughts, articles, photos, voice notes, and documents organized privately on your device. No cloud, no tracking, no accounts.
> 
> Please note: this app is created with the aid of AI tools

---

## ✨ Features

- 📤 **Native Share-to-Self Target:** Share links, texts, images, and files directly to Keep in Mind from any Android app (Browser, YouTube, Photos, Files) without opening the app UI.
- 🧩 **Native Android Home Screen Widget:**
  - Configurable to display between 1 and 5 recent or pinned items.
  - Interactive scrollable list (`ListView` + `RemoteCollectionItems`) on Android.
  - Direct tap to view, add (`+`), or open full library.
  - Instant background updates whenever content is shared.
- 🎙️ **Voice Notes & Camera:** Record audio with configurable time limits or capture photos directly into your local library.
- 🏷️ **Smart Categorization & Search:** Auto-detects URLs, domains, attachments, and MIME types. Filter by tags or pinned status with instant search.
- 🛡️ **Privacy & Zero Cloud:**
  - All content and attachments reside exclusively in internal application storage.
  - Strict path traversal protection and URI scheme sanitization.
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
├── android/               # Android native integration
│   ├── .../KeepInMindWidgetProvider.kt  # AppWidgetProvider (ListView & RemoteCollectionItems)
│   └── .../MainActivity.kt              # Headless share receiver, widget sync, audio/camera bridge
├── lib/
│   ├── l10n/              # Modular multi-language localizations (7 languages)
│   ├── models/            # MemoryItem domain model and JSON serializers
│   ├── services/          # StorageService, ShareIntentService, WidgetSyncService
│   ├── ui/
│   │   ├── screens/       # HomeScreen, ItemDetailScreen, WidgetSettingsScreen
│   │   └── widgets/       # AddMemorySheet, HomeWidgetPreview, MemoryItemCard
│   └── utils/             # LocalFileHelper (sandboxed attachment I/O), TagHelper
└── test/                  # Unit and widget test suite
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (stable channel, 3.47+)
- Dart SDK (3.13+)
- Android SDK (API 34+ recommended, minSdk 21)
- Java 17

### Installation & Run

```bash
# Clone the repository
git clone https://github.com/Fharamir/keep_in_mind.git
cd keep_in_mind

# Install dependencies
flutter pub get

# Run test suite
flutter test

# Run on connected Android device
flutter run
```

---

## 🧪 Testing

The test suite covers:
- Share payload parsing and URL/domain auto-detection.
- Widget item selection algorithm and pin prioritization.
- Audio and file size constraint configurations.
- Multi-language resolution, fallback, and dynamic runtime override.
- Import JSON security hardening (rejection of `javascript:`, directory traversal sanitization, type coercion).

```bash
flutter test
```

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

