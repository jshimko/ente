# CLAUDE.md

Reference guide for the Ente Photos mobile app. For monorepo-wide guidance (shared packages, Melos, lint rules, design system), see `mobile/CLAUDE.md`.

**Purpose:** End-to-end encrypted photo backup and management app built with Flutter/Dart. Largest app in the Ente mobile monorepo (400+ dependencies, 50+ services, ML features, Rust FFI).

**Documented:** 2026-05-18
**Commit:** a203b25e7e

---

## Project Philosophy

Ente is focused on privacy, transparency and trust. It's a fully open-source, end-to-end encrypted platform for storing data in the cloud. When contributing, always prioritize:

- User privacy and data security
- End-to-end encryption integrity
- Transparent, auditable code
- Zero-knowledge architecture principles

---

## Monorepo Context

This is the Ente Photos mobile app within the Ente monorepo. The monorepo contains:

- Mobile apps (Photos, Auth, Locker) at `mobile/apps/`
- Shared packages at `mobile/packages/`
- Web, desktop, CLI, and server components in parent directories

### Package Architecture

The Photos app uses two types of packages:

- **Shared packages** (`../../packages/`): Common code shared across multiple Ente apps (Photos, Auth, Locker)
- **Photos-specific plugins** (`./plugins/`): Custom Flutter plugins specific to Photos app for separation and testability

---

## Commit & PR Guidelines

### Pre-commit/PR Checklist (RUN BEFORE EVERY COMMIT OR PR!)

**CRITICAL: CI will fail if ANY of these checks fail. Run ALL commands and ensure they ALL pass.**

```bash
# 1. Format Dart code
dart format .

# 2. Analyze flutter code for errors and warnings
flutter analyze
```

**Why CI might fail even after running these:**

- Skipping any command above
- Assuming auto-fix tools handle everything (they don't)
- Not fixing warnings that flutter reports
- Making changes after running the checks

### Commit & PR Message Rules

**These rules apply to BOTH commit messages AND pull request descriptions**

- Keep messages CONCISE (no walls of text)
- Subject line under 72 chars (no body text unless critical)
- NO emojis
- NO promotional text or links
- NO Co-Authored-By lines

### Additional Guidelines

- Check `git status` before committing to avoid adding temporary/binary files
- Never commit to main branch
- All CI checks must pass - run the checklist commands above before committing or creating PR

---

## Development Commands

### Using Melos (Monorepo Management)

```bash
# From mobile/ directory - bootstrap all packages
melos bootstrap

# Run Photos app specifically
melos run:photos:apk

# Build Photos APK
melos build:photos:apk

# Clean Photos app
melos clean:photos
```

### Direct Flutter Commands

```bash
# Development run
flutter run --flavor independent

# Build release APK
flutter build apk --release --flavor independent

# iOS build
cd ios && pod install && cd ..
flutter build ios
```

### Code Quality

```bash
# Static analysis and linting
flutter analyze .

# Run tests
flutter test
```

---

## Architecture Overview

### Entry Points & Initialization Flow

Boot sequence:

1. `main()` in `lib/main.dart` -- FFmpeg, Rive, MediaKit init, theme loading
2. `_init()` -- Configuration, NetworkClient, ServiceLocator, all services init
3. `EnteApp` in `lib/app.dart` -- MaterialApp with AdaptiveTheme, locale, deeplinks
4. `HomeWidget` in `lib/ui/tabs/home_widget.dart` -- Main tab navigation

Background boot (Workmanager):

1. `callbackDispatcher()` in `lib/utils/bg_task_utils.dart` -- registered entry point
2. `_runMinimally()` -- minimal services: Config, Network, Sync, optional ML

| File                                     | Purpose                                                      |
| ---------------------------------------- | ------------------------------------------------------------ |
| `lib/main.dart`                          | App entry point, background task dispatcher, sync scheduling |
| `lib/app.dart`                           | Root widget (EnteApp), locale changes, deeplink routing      |
| `lib/app_mode.dart`                      | App mode enum (`enteGallery` / `localGallery`); local gallery is the no-account on-device library experience |
| `lib/service_locator.dart`               | All service singletons (39 lazy getters)                     |
| `lib/core/configuration.dart`            | User config, encryption keys, secure storage (26KB)          |
| `lib/core/network/network.dart`          | Dio HTTP clients (enteDio, nonEnteDio)                       |
| `lib/core/network/endpoint_config.dart`  | Server endpoint config decoupled from startup; listens for `EndpointUpdatedEvent` for runtime endpoint switching |
| `lib/core/network/ente_interceptor.dart` | Auth token injection, error handling                         |
| `lib/core/event_bus.dart`                | Event bus singleton (`Bus.instance`)                         |
| `lib/ente_theme_data.dart`               | Light/dark Material theme definitions                        |

### Key Architecture Patterns

| Pattern          | Implementation                               | Access                                                     |
| ---------------- | -------------------------------------------- | ---------------------------------------------------------- |
| Service Locator  | `lib/service_locator.dart`                   | `ServiceLocator.instance`, 39 lazy getters at module level |
| Event Bus        | `lib/core/event_bus.dart`                    | `Bus.instance.on<T>().listen()` / `Bus.instance.fire()`    |
| Gateway Pattern  | `lib/gateways/` (11 subdirs)                 | Services -> Gateways -> Dio -> Museum API                  |
| SQLite DB Layer  | `lib/db/` (13 top-level + `db/ml/` subsystem) | `sqlite_async` with `SqlDbBase` mixin from `db/common/`   |
| Rust FFI         | `rust/` + `rust_builder/`                    | `flutter_rust_bridge` codegen — ML inference, image decoding (Android HEIC/.hif), crypto; `EntePhotosRust.init()` |
| Isolate Compute  | `services/machine_learning/ml_computer.dart` | Dedicated isolate for ML inference                         |
| Background Tasks | `lib/utils/bg_task_utils.dart`               | Workmanager (iOS 30min, Android 15min intervals)           |
| Caching          | `lib/core/cache/`                            | `LRUMap`, image/thumbnail/video caches                     |

### Security Architecture

- End-to-end encryption with `ente_crypto` plugin (libsodium via flutter_sodium)
- BIP39 mnemonic-based key generation (24 words)
- Secure storage using platform-specific implementations (iOS Keychain, Android EncryptedSharedPreferences)
- App lock and privacy screen features via `ente_lock_screen` package

### Endpoint Configuration

The Photos server endpoint is configured independently of app startup via `core/network/endpoint_config.dart`. `NetworkClient.init()` constructs `EndpointConfig(preferences)` and listens for `EndpointUpdatedEvent` to switch backends at runtime — this is what powers the developer-settings flow for pointing the app at a self-hosted Museum instance without restarting.

### Internal Feature Gating

Experimental features ship behind the `internalUser` flag in `plugins/ente_feature_flag/`. Examples in production: video streaming toggle, Rust ML rollout, video editor codec selection. The flag respects a debug-mode default plus a persistent toggle stored at `ls.internal_user_disabled`. Read it via `flagService.internalUser`.

---

## Services Navigation Map

All services in `lib/services/`. Most are singletons accessed via lazy getters in `service_locator.dart`.

### Sync & Backup

| Service                 | File                                      | Purpose                                      |
| ----------------------- | ----------------------------------------- | -------------------------------------------- |
| SyncService             | `services/sync/sync_service.dart`         | Main sync orchestrator (local + remote)      |
| LocalSyncService        | `services/sync/local_sync_service.dart`   | Device file discovery and tracking           |
| RemoteSyncService       | `services/sync/remote_sync_service.dart`  | Server synchronization                       |
| TrashSyncService        | `services/sync/trash_sync_service.dart`   | Trash management sync                        |
| BackupPreferenceService | `services/backup_preference_service.dart` | Backup settings (WiFi-only, videos, folders) |
| LocalFileUpdateService  | `services/local_file_update_service.dart` | Device file change detection                 |

### Collections & Files

| Service              | File                                      | Purpose                                      |
| -------------------- | ----------------------------------------- | -------------------------------------------- |
| CollectionsService   | `services/collections_service.dart`       | Album management, encryption, sharing (84KB) |
| FilesService         | `services/files_service.dart`             | File metadata operations                     |
| FavoritesService     | `services/favorites_service.dart`         | Favorite/starred items                       |
| HiddenService        | `services/hidden_service.dart`            | Hidden collection management                 |
| DeduplicationService | `services/deduplication_service.dart`     | Duplicate detection and removal              |
| IgnoredFilesService  | `services/ignored_files_service.dart`     | Files excluded from backup                   |
| FileMagicService     | `services/file_magic_service.dart`        | File magic metadata updates                  |
| FileDataService      | `services/filedata/filedata_service.dart` | File data management                         |

### Search & Discovery

| Service            | File                                 | Purpose                          |
| ------------------ | ------------------------------------ | -------------------------------- |
| SearchService      | `services/search_service.dart`       | Multi-type search with ML (65KB) |
| SmartAlbumsService | `services/smart_albums_service.dart` | Auto-generated albums            |
| DateParseService   | `services/date_parse_service.dart`   | Natural language date parsing    |

### Machine Learning

| Service                | File                                                                     | Purpose                        |
| ---------------------- | ------------------------------------------------------------------------ | ------------------------------ |
| MLService              | `services/machine_learning/ml_service.dart`                              | ML pipeline orchestration      |
| FaceRecognitionService | `services/machine_learning/face_ml/face_recognition_service.dart`        | Face detection & recognition   |
| PersonService          | `services/machine_learning/face_ml/person/person_service.dart`           | Person/cluster management      |
| SemanticSearchService  | `services/machine_learning/semantic_search/semantic_search_service.dart` | CLIP-based image search        |
| SimilarImagesService   | `services/machine_learning/similar_images_service.dart`                  | Visual similarity detection    |
| ComputeController      | `services/machine_learning/compute_controller.dart`                      | ML compute workload management |
| MLComputer             | `services/machine_learning/ml_computer.dart`                             | Dedicated ML isolate           |
| FaceThumbnailGenerator | `services/machine_learning/face_thumbnail_generator.dart`                | Face crop thumbnails           |

**Model integrity:** ML model files are hash-checked on download. When the ONNX runtime fails on a model (e.g., corrupted CLIP text encoder), the model file is deleted, indexing pauses, and the file is re-downloaded on the next sync. This avoids infinite retry loops on broken model state and is the primary reason both decoders writing empty ML results is preferable to throwing.

### Memories

| Service                       | File                                                  | Purpose                                      |
| ----------------------------- | ----------------------------------------------------- | -------------------------------------------- |
| MemoryLaneService             | `services/memory_lane/memory_lane_service.dart`       | On-this-day memories                         |
| MemoryLaneCacheService        | `services/memory_lane/memory_lane_cache_service.dart` | Memory lane caching                          |
| SmartMemoriesService          | `services/smart_memories_service.dart`                | AI-powered memory curation orchestrator      |
| SmartMemoriesClipCalculator   | `services/smart_memories_clip_calculator.dart`        | CLIP-driven memory candidate scoring         |
| SmartMemoriesPeopleCalculator | `services/smart_memories_people_calculator.dart`      | People/face-based memory grouping            |
| SmartMemoriesTimeCalculator   | `services/smart_memories_time_calculator.dart`        | Time-window memory selection                 |
| SmartMemoriesTripCalculator   | `services/smart_memories_trip_calculator_v2.dart`     | Trip/location memory detection (v2)          |
| MemoriesCacheService          | `services/memories_cache_service.dart`                | Memory caching                               |
| MemoryShareService            | `services/memory_share_service.dart`                  | Public memory sharing (7-day TTL)            |
| VideoMemoryService            | `services/video_memory_service.dart`                  | Video memory creation                        |

### Social & Sharing

| Service                       | File                                            | Purpose                      |
| ----------------------------- | ----------------------------------------------- | ---------------------------- |
| SocialService                 | `services/social_service.dart`                  | Comments, collaboration      |
| SocialSyncService             | `services/social_sync_service.dart`             | Social data synchronization  |
| SocialNotificationCoordinator | `services/social_notification_coordinator.dart` | Social notification handling |

### Account & Billing

| Service        | File                                    | Purpose                         |
| -------------- | --------------------------------------- | ------------------------------- |
| UserService    | `services/account/user_service.dart`    | Authentication, user management |
| BillingService | `services/account/billing_service.dart` | Subscription management         |
| PasskeyService | `services/account/passkey_service.dart` | Passkey/WebAuthn authentication |

### Platform & System

| Service                    | File                                         | Purpose                            |
| -------------------------- | -------------------------------------------- | ---------------------------------- |
| HomeWidgetService          | `services/home_widget_service.dart`          | Home screen widget sync            |
| AlbumHomeWidgetService     | `services/album_home_widget_service.dart`    | Album data for home screen widget  |
| MemoryHomeWidgetService    | `services/memory_home_widget_service.dart`   | Memory data for home screen widget |
| PeopleHomeWidgetService    | `services/people_home_widget_service.dart`   | People data for home screen widget |
| FamilyService              | `services/family_service.dart`               | Family plan management             |
| LocalAuthenticationService | `services/local_authentication_service.dart` | Local biometric/PIN auth           |
| PushService                | `services/push_service.dart`                 | Firebase push notifications        |
| NotificationService        | `services/notification_service.dart`         | In-app notifications               |
| UpdateService              | `services/update_service.dart`               | App update checking                |
| WakeLockService            | `services/wake_lock_service.dart`            | Screen wake lock for uploads       |
| AppLifecycleService        | `services/app_lifecycle_service.dart`        | App lifecycle tracking             |
| AppNavigationService       | `services/app_navigation_service.dart`       | Programmatic navigation            |

### Other

| Service                    | File                                               | Purpose                           |
| -------------------------- | -------------------------------------------------- | --------------------------------- |
| EntityService              | `services/entity_service.dart`                     | Collaborative entity operations   |
| LocationService            | `services/location_service.dart`                   | Location data extraction, mapping |
| MagicCacheService          | `services/magic_cache_service.dart`                | Magic metadata caching (18KB)     |
| StorageBonusService        | `services/storage_bonus_service.dart`              | Referral storage tracking         |
| RitualsService             | `services/rituals/rituals_service.dart`            | Daily/recurring reminders         |
| WrappedService             | `services/wrapped/wrapped_service.dart`            | Year-end photo highlights         |
| WrappedCacheService        | `services/wrapped/wrapped_cache_service.dart`      | Wrapped data caching              |
| PhotosContactsService      | `services/photos_contacts_service.dart`            | Photos-specific contacts          |
| ContactIdentityResolver    | `services/contacts/contact_identity_resolver.dart` | Contact identity resolution       |
| PermissionService          | `services/permission/service.dart`                 | Permission management             |
| LanguageService            | `services/language_service.dart`                   | Language/locale management        |
| RemoteAssetsService        | `services/remote_assets_service.dart`              | Remote asset fetching             |
| IsolatedFFmpegService      | `services/isolated_ffmpeg_service.dart`            | FFmpeg in isolated process        |
| TextEmbeddingsCacheService | `services/text_embeddings_cache_service.dart`      | Text embedding cache              |
| VideoPreviewService        | `services/video_preview_service.dart`              | Video preview generation          |

---

## Database Reference

All databases in `lib/db/`. Uses `sqlite_async` with migration via `PRAGMA user_version`. The `SqlDbBase` mixin in `db/common/base.dart` provides migration plumbing; conflict resolution helpers live in `db/common/conflict_algo.dart`.

### Top-level databases

| Database           | File                           | Stores                             |
| ------------------ | ------------------------------ | ---------------------------------- |
| FilesDB            | `db/files_db.dart`             | Encrypted file metadata            |
| CollectionsDB      | `db/collections_db.dart`       | Albums and collections             |
| DeviceFilesDB      | `db/device_files_db.dart`      | Local device file index for backup |
| TrashDB            | `db/trash_db.dart`             | Deleted files                      |
| MemoriesDB         | `db/memories_db.dart`          | Memory records                     |
| MemorySharesDB     | `db/memory_shares_db.dart`     | Shared memories                    |
| EntitiesDB         | `db/entities_db.dart`          | Collaborative entities             |
| SocialDB           | `db/social_db.dart`            | Comments, social data              |
| UploadLocksDB      | `db/upload_locks_db.dart`      | Upload state tracking              |
| FileUpdationDB     | `db/file_updation_db.dart`     | File sync status                   |
| GalleryDownloadsDB | `db/gallery_downloads_db.dart` | Downloaded files                   |
| OfflineFilesDB     | `db/offline_files_db.dart`     | Offline mode files                 |
| IgnoredFilesDB     | `db/ignored_files_db.dart`     | Files excluded from backup         |

### ML database subsystem (`db/ml/`)

| File                              | Purpose                                          |
| --------------------------------- | ------------------------------------------------ |
| `db.dart`                         | ML DB orchestrator                               |
| `schema.dart`                     | ML table schemas and migrations                  |
| `base.dart`                       | Shared mixin for ML DB tables                    |
| `clip_vector_db.dart`             | CLIP image/text embedding vectors                |
| `cluster_centroid_vector_db.dart` | Face cluster centroid vectors                    |
| `pet_vector_db.dart`              | Pet detection embedding vectors                  |
| `db_model_mappers.dart`           | Face/CLIP model ↔ DB row mapping                 |
| `db_pet_model_mappers.dart`       | Pet model ↔ DB row mapping                       |
| `filedata.dart`                   | ML-side file data table                          |

---

## API Gateways Reference

All gateways in `lib/gateways/`. Each accepts `Dio` via constructor. Services call gateways; gateways call Museum API.

| Gateway       | Directory                 | Endpoints                              |
| ------------- | ------------------------- | -------------------------------------- |
| Collections   | `gateways/collections/`   | Album CRUD, sharing, file management   |
| Files         | `gateways/files/`         | Upload, download, metadata, magic data |
| Users         | `gateways/users/`         | Auth, passkeys, user info              |
| Billing       | `gateways/billing/`       | Payments, subscriptions                |
| Trash         | `gateways/trash/`         | Trash operations                       |
| Social        | `gateways/social/`        | Comments, collaboration                |
| Push          | `gateways/push/`          | Push notification registration         |
| Cast          | `gateways/cast/`          | Chromecast integration                 |
| Emergency     | `gateways/emergency/`     | Emergency contact sharing              |
| Entity        | `gateways/entity/`        | Generic entity operations              |
| Storage Bonus | `gateways/storage_bonus/` | Referral program                       |

---

## UI Screens Reference

All UI in `lib/ui/`.

| Directory          | Purpose         | Key Screens                          |
| ------------------ | --------------- | ------------------------------------ |
| `ui/home/`         | Photo gallery   | Home gallery grid                    |
| `ui/tabs/`         | Main navigation | `home_widget.dart` -- tab bar        |
| `ui/viewer/`       | File viewer     | Image/video viewer, people, location |
| `ui/collections/`  | Albums          | Album list, create, share            |
| `ui/account/`      | Auth screens    | Login, signup, password reset        |
| `ui/settings/`     | Settings        | Preferences, about, storage          |
| `ui/payment/`      | Subscription    | Plans, billing, family               |
| `ui/sharing/`      | Sharing         | Album sharing, public links          |
| `ui/social/`       | Social          | Comments, collaboration              |
| `ui/map/`          | Location map    | Map view with photo markers          |
| `ui/family/`       | Family plan     | Family sharing management            |
| `ui/cast/`         | Casting         | Chromecast UI                        |
| `ui/wrapped/`      | Year wrap       | Year-end highlights                  |
| `ui/rituals/`      | Reminders       | Daily/recurring reminders            |
| `ui/picker/`       | Pickers         | File/album picker flows              |
| `ui/tools/`        | Editing         | Image/video editing, app lock        |
| `ui/actions/`      | Context menus   | File/album actions                   |
| `ui/components/`   | Shared widgets  | Component subdirectories             |
| `ui/common/`       | Common widgets  | Theme-aware reusable components      |
| `ui/growth/`       | Referrals       | Growth/referral UI                   |
| `ui/notification/` | Notifications   | In-app notification UI               |
| `ui/offline/`      | Offline         | Offline mode UI                      |

---

## Key Events Reference

64 event types in `lib/events/`. Most important:

| Event                        | When Fired                                |
| ---------------------------- | ----------------------------------------- |
| `SyncStatusUpdate`           | During sync progress stages               |
| `FilesUpdatedEvent`          | File metadata changes (add/update/delete) |
| `CollectionUpdatedEvent`     | Album modifications                       |
| `LocalPhotosUpdatedEvent`    | Device photo library changes              |
| `MemoriesChangedEvent`       | Memory creation or update                 |
| `PeopleChangedEvent`         | Face cluster updates                      |
| `TrashUpdatedEvent`          | Trash additions or removals               |
| `SubscriptionPurchasedEvent` | Payment completed                         |
| `ComputeControlEvent`        | ML compute start/stop                     |
| `EndpointUpdatedEvent`       | Server URL changed                        |
| `BackupFoldersUpdatedEvent`  | Backup folder selection changed           |
| `FileUploadedEvent`          | Individual file upload completed          |
| `UserDetailsChangedEvent`    | User profile or family status changes     |

---

## Key Models Reference

All models in `lib/models/`, organized by domain (account, collection, file, location, memories, ml, search, etc.).

| Model              | File                                    | Description                                      |
| ------------------ | --------------------------------------- | ------------------------------------------------ |
| `EnteFile`         | `models/file/file.dart`                 | Core file with encryption metadata, keys, nonces |
| `FileType`         | `models/file/file_type.dart`            | Image, video, live photo type enum               |
| `Collection`       | `models/collection/collection.dart`     | Album with encryption and sharing info           |
| `Person`           | `models/ml/face/person.dart`            | Face cluster (person)                            |
| `Face`             | `models/ml/face/face.dart`              | Individual face detection result                 |
| `Memory`           | `models/memories/memory.dart`           | Memory event data                                |
| `SmartMemory`      | `models/memories/smart_memory.dart`     | AI-generated memory                              |
| `LocationTag`      | `models/location_tag/location_tag.dart` | Named location bookmark                          |
| `GalleryType`      | `models/gallery_type.dart`              | Gallery display mode enum                        |
| `DeviceCollection` | `models/device_collection.dart`         | Device folder/album                              |
| `UserDetails`      | `models/user_details.dart`              | User profile and storage info                    |

---

## Project Structure

```
lib/
├── core/                  # Configuration, constants, networking, caching, error reporting
│   ├── cache/             # LRU maps, image/thumbnail/video caches
│   ├── network/           # Dio HTTP clients, auth interceptor
│   └── error-reporting/   # Sentry integration, super_logging
├── data/                  # Static data (holidays, months, years)
├── emergency/             # Emergency contact recovery (pages, service, models)
├── theme/                 # Theme definitions (colors, effects, text styles)
├── services/              # Business logic (58+ services)
│   ├── sync/              # Local, remote, trash sync
│   ├── machine_learning/  # ML pipeline orchestration
│   │   ├── face_ml/       # Face detection, recognition, clustering, person
│   │   ├── semantic_search/  # CLIP-based image search
│   │   └── pet_ml/        # Pet detection
│   ├── memory_lane/       # On-this-day memories
│   ├── rituals/           # Daily reminders
│   ├── wrapped/           # Year-end highlights
│   ├── account/           # User service, billing
│   ├── contacts/          # Contact identity resolution
│   ├── filedata/          # File metadata service
│   ├── filter/            # Search filter implementations
│   └── permission/        # Permission management
├── ui/                    # UI screens and components
├── models/                # Data models (account, collection, file, location, memories, ml, etc.)
├── db/                    # SQLite database layer (13 top-level DBs + db/ml/ + db/common/)
│   ├── common/            # SqlDbBase mixin, conflict-resolution algorithms
│   └── ml/                # Face/CLIP/pet vector DBs, schema, mappers
├── utils/                 # Utilities and helpers
├── gateways/              # API gateway interfaces (11 subdirectories)
├── module/                # Upload/download management
│   ├── upload/            # Multipart upload, S3 XML parsing
│   └── download/          # Download queue, file URL resolution
├── events/                # Event bus events (64 types)
├── states/                # UI state classes
├── extensions/            # Dart extensions on core types
├── l10n/                  # Localization ARB files
└── generated/             # Auto-generated code (intl, protos)
```

---

## Photos-Specific Plugins

Located in `plugins/`. These are NOT shared with Auth/Locker.

| Plugin              | Directory                    | Purpose                                                                                              |
| ------------------- | ---------------------------- | ---------------------------------------------------------------------------------------------------- |
| `ente_crypto`       | `plugins/ente_crypto/`       | Encryption via libsodium (flutter_sodium)                                                            |
| `ente_cast`         | `plugins/ente_cast/`         | Chromecast interface (Google Play vs F-Droid implementations are wired in at the app/flavor layer)   |
| `ente_feature_flag` | `plugins/ente_feature_flag/` | Feature flags including the `internalUser` gate for experimental features                            |
| `ente_qr`           | `plugins/ente_qr/`           | QR code generation/scanning                                                                          |
| `onnx_dart`         | `plugins/onnx_dart/`         | ONNX ML model runtime                                                                                |

---

## Build Variants

| Flavor        | Use Case                     | App ID                       |
| ------------- | ---------------------------- | ---------------------------- |
| `independent` | Default development          | `io.ente.photos.independent` |
| `dev`         | Development with `.env` file | `io.ente.photos.dev`         |
| `playstore`   | Google Play release          | `io.ente.photos`             |
| `fdroid`      | F-Droid (no Google services) | `io.ente.photos.fdroid`      |

- Android: Min SDK 26, Target SDK 36, NDK 28.2.13676358
- iOS: Deployment target 14.0+

---

## Common Tasks (Photos-Specific)

### Add a new service

1. Create file in `lib/services/` (or appropriate subdirectory)
2. Add lazy getter in `service_locator.dart` following the `_myService` / `get myService` pattern
3. If service needs early init, wire it in `_init()` in `main.dart`
4. Fire events via `Bus.instance.fire()` for cross-service communication

### Add a new screen

1. Create in `lib/ui/<category>/`
2. Use `getEnteColorScheme(context)` and `getEnteTextTheme(context)` at top of `build()`
3. Check `ui/components/` and `../../packages/ui/` for reusable widgets before creating new ones
4. Navigate via `AppNavigationService.instance.pushPage(widget)`

### Add a new database table

1. Create or extend a DB class in `lib/db/`
2. Use `SqlDbBase` mixin from `db/common/` for migration support
3. Increment `PRAGMA user_version` and add migration logic
4. Use `sqlite_async` for all database operations

### Add a new API gateway

1. Create in `lib/gateways/<domain>/`
2. Constructor takes `Dio` (use `enteDio` from ServiceLocator)
3. Add lazy getter in `service_locator.dart`
4. Consume from the corresponding service

### Add a new event

1. Create in `lib/events/`, extend `Event` from `event_bus` package
2. Fire: `Bus.instance.fire(MyEvent())`
3. Listen: `Bus.instance.on<MyEvent>().listen((event) { ... })`
4. Cancel subscription in `dispose()`

### Add a new model

1. Create in `lib/models/<domain>/`
2. Use `freezed` + `json_serializable` for immutable data classes with JSON support
3. Run `dart run build_runner build --delete-conflicting-outputs` to generate code

---

## Localization (Flutter)

- Add new strings to `lib/l10n/intl_en.arb` (English base file)
- Use `AppLocalizations` to access localized strings in code
- Example: `AppLocalizations.of(context).yourStringKey`
- Run code generation after adding new strings: `flutter pub get`
- Translations managed via Crowdin for other languages

---

## Key Dependencies

- **Flutter 3.38.10** with Dart SDK >=3.10.0 <4.0.0
- **Media**: `photo_manager`, `video_editor`, `ffmpeg_kit_flutter`, `media_kit`
- **Storage**: `sqlite_async`, `flutter_secure_storage`
- **ML/AI**: Custom ONNX runtime (`onnx_dart` plugin), `ml_linalg`
- **Rust**: `flutter_rust_bridge` 2.12.0 for ML inference, HEIC decoding, crypto
- **Forks**: Heavy use of git-forked dependencies (`ffmpeg-kit`, `flutter_sodium`, `video_editor`, `media_kit`, `panorama`, `privacy_screen`, `battery_info`, etc.) for privacy/feature control. Always check `pubspec.yaml` git references before bumping these.
- **Network**: `dio` with `native_dio_adapter`
- **State**: `event_bus` for pub/sub, `adaptive_theme` for theming
- **Contacts**: `ente_contacts` shared package for contacts management

---

## Development Setup Requirements

1. Install Flutter v3.38.10 and Rust
2. Install Flutter Rust Bridge: `cargo install flutter_rust_bridge_codegen`
3. Generate Rust bindings: `flutter_rust_bridge_codegen generate`

---

## Critical Coding Requirements

### 1. Code Quality - MANDATORY

**Every code change MUST pass `dart format .` and `flutter analyze` with zero issues**

- Run `dart format .` first to format all Dart code
- Run `flutter analyze` after EVERY code modification
- Resolve ALL issues (info, warning, error) - no exceptions
- The codebase has zero issues by default, so any issue is from your changes
- DO NOT commit or consider work complete until both commands pass cleanly

### 2. Component Reuse - MANDATORY

**Always try to reuse existing components**

- Use a subagent to search for existing components before creating new ones
- Only create new components if none exist that meet the requirements
- Check both UI components in `lib/ui/` and shared components in `../../packages/`

### 3. Design System - MANDATORY

**Never hardcode colors or text styles**

- Always use the Ente design system for colors and typography
- Use a subagent to find the appropriate design tokens
- Access colors via theme: `getEnteColorScheme(context)`
- Access text styles via theme: `getEnteTextTheme(context)`
- Call above theme getters only at the top of (`build`) methods and re-use them throughout the component
- If you MUST use custom colors/styles (extremely rare), explicitly inform the user with a clear warning

### 4. Documentation Sync - MANDATORY

**Keep spec documents synchronized with code changes**

- When modifying code, also update any associated spec documents
- Check for related spec files in `docs/` or project directories
- Ensure documentation reflects the current implementation
- Update examples in specs if behavior changes

### 5. Database Methods - BEST PRACTICE

**Prioritize readability in database methods**

- For small result sets (e.g., 1-2 stale entries), prefer filtering in Dart for cleaner, more readable code
- For large datasets, use SQL WHERE clauses for performance - they're much more efficient in SQLite

---

## Important Notes

- Large service files (some 70k+ lines) - consider file context when editing
- 400+ dependencies - check existing libraries before adding new ones
- When adding functionality, check both `../../packages/` for shared code and `./plugins/` for Photos-specific plugins
- Performance-critical paths use Rust integration
- Always follow existing code conventions and patterns in neighboring files

# Individual Preferences

- @~/.claude/ente-photos-instructions.md
