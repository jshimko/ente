# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Documented:** 2026-05-18
**Commit:** a203b25e7e
**Version:** 1.0.4+104

## Project Philosophy

Ente is focused on privacy, transparency and trust. It's a fully open-source, end-to-end encrypted platform for storing data in the cloud. When contributing, always prioritize:
- User privacy and data security
- End-to-end encryption integrity
- Transparent, auditable code
- Zero-knowledge architecture principles

## Project Overview

Ente Locker is a Flutter application for securely storing important documents. It's part of the Ente mobile monorepo and shares packages with the Ente Photos and Ente Auth apps. The app provides encrypted file storage with collections, sharing, structured information items (notes, credentials, contacts, physical records), and cross-platform support (iOS, Android, Linux, Windows, macOS).

## Commit & PR Guidelines

### Pre-commit/PR Checklist (RUN BEFORE EVERY COMMIT OR PR!)

**CRITICAL: CI will fail if ANY of these checks fail. Run ALL commands and ensure they ALL pass.**

```bash
# 1. Format Dart code for ente/mobile/app/locker
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

## Development Commands

### Build & Run

```bash
# From mobile/ directory - bootstrap all packages
melos bootstrap

# Clean the locker app specifically
melos run clean:locker

# Run the app (from this directory)
flutter run
# Or via melos with the standard flavor
melos run run:locker:apk

# Build for specific platforms
flutter build apk           # Android
flutter build ios           # iOS
melos run build:locker:ios  # Release iOS via melos
flutter build macos         # macOS
flutter build windows       # Windows
flutter build linux         # Linux
```

### Code Quality

```bash
# Run linter
flutter analyze

# Auto-format code
dart format .

# Run lint on specific file
flutter analyze lib/path/to/file.dart
```

### Testing

Unit tests live under `test/`:

```
test/services/files/download/file_downloader_test.dart
test/services/files/offline/offline_file_storage_test.dart
test/services/info_file_service_test.dart
test/test_utils/configuration_test_util.dart
test/utils/file_util_test.dart
```

```bash
flutter test                                       # Run all tests
flutter test test/services/info_file_service_test.dart  # Run specific test
```

`test/test_utils/configuration_test_util.dart` provides shared fixtures for tests that need an initialized `Configuration`.

## Architecture

### Monorepo Structure

Locker is one of three apps in `/apps/` (Photos, Auth, Locker) that share common packages from `/packages/`:

**Shared Packages:**
- `ente_accounts` - User authentication and account management
- `ente_base` - Base models, types, and `EnteBaseDatabase`
- `ente_configuration` - App configuration (extended by local `services/configuration.dart`)
- `ente_contacts` - Shared contacts client (wrapped locally by `LockerContactsDisplayService`)
- `ente_crypto_api` - Abstract crypto interface (key derivation, encrypt/decrypt)
- `ente_crypto_dart_adapter` - Dart implementation of crypto API (adapter pattern)
- `ente_events` - Event bus for app-wide events
- `ente_icons` - Custom icon font (EnteIcons.ttf)
- `ente_legacy` - Legacy services (emergency contacts, emergency kit)
- `ente_lock_screen` - App lock/authentication UI and settings
- `ente_logging` - Structured logging
- `ente_network` - HTTP client and network layer
- `ente_pure_utils` - Pure Dart utilities (email validation, crypto, path)
- `ente_rust` - Rust FFI bindings via flutter_rust_bridge
- `ente_sharing` - Sharing models and utilities
- `ente_strings` - Localization strings
- `ente_ui` - Common UI components and theming
- `ente_utils` - Platform utilities and helpers

### Core Services (Singletons)

All major services follow the singleton pattern with `static final instance` getters unless noted. Grouped by area:

**Configuration & Auth**
1. **Configuration** (`lib/services/configuration.dart`) - Extends `BaseConfiguration` from `ente_configuration`; stores user settings, account info, and app state. Initialized with database instances and `SharedPreferences`.
2. **UserService** (from `ente_accounts`) - Manages authentication and account details. Fires `SignedInEvent` / `SignedOutEvent` on the event bus.
3. **LockScreenSettings** (from `ente_lock_screen`) - Biometric / PIN settings and privacy screen state.

**Collections**
4. **CollectionApiClient** (`lib/services/collections/collections_api_client.dart`) - HTTP gateway for collection CRUD. Called by `CollectionService`.
5. **CollectionService** (`lib/services/collections/collections_service.dart`) - Manages collections (folders) and the files within them. Maintains the `_collectionIDToCollections` local cache, performs incremental sync, and owns encryption-key resolution for collections and files.
6. **FavoritesService** (`lib/services/favorites_service.dart`) - Manages favorite/starred items within collections.

**Files**
7. **FileUploader** (`lib/services/files/upload/file_upload_service.dart`) - Encrypts and uploads files; invoked from `UploaderPage`.
8. **MetadataUpdaterService** (`lib/services/files/sync/metadata_updater_service.dart`) - File caption / metadata edits.
9. **OfflineFilesService** (`lib/services/files/offline/offline_files_service.dart`) - Manages offline copies of selected files.
10. **ServiceLocator** (`lib/services/files/download/service_locator.dart`) - Download manager and signed-URL resolution for file downloads. (Locally scoped; do not confuse with the Photos app's global `service_locator.dart`.)

**Links & Sharing**
11. **LinksClient** (`lib/services/files/links/links_client.dart`) - HTTP gateway for public share links.
12. **LinksService** (`lib/services/files/links/links_service.dart`) - Handles shareable public links for collections.

**Trash / Info / Updates**
13. **TrashService** (`lib/services/trash/trash_service.dart`) - Manages deleted files and trash operations.
14. **InfoFileService** (`lib/services/info_file_service.dart`) - Handles structured information files (notes, credentials, contacts, physical records).
15. **UpdateService** (`lib/services/update_service.dart`) - Checks for app updates.

**Legacy / Contacts**
16. **EmergencyContactService** (from `ente_legacy`) - Emergency-contact flows.
17. **LegacyKitService** (from `ente_legacy`) - Emergency-kit features and other legacy bridges.
18. **LockerContactsDisplayService** (`lib/services/contacts_display_service.dart`) - Locker-side wrapper around `ente_contacts`. Uses static methods (not a singleton); initialized via `LockerContactsDisplayService.init(...)`.

### Database Layer

SQLite databases managed via `sqflite`:
- **LockerDB** (`lib/services/db/locker_db.dart`) - Main database for collections and files. Extends `EnteBaseDatabase` from `ente_base`.
- **TrashTable** (`lib/services/db/trash_table.dart`) - Table managed inside `LockerDB`, not a separate database.

Sync times are tracked per table to enable incremental syncing.

### Event-Driven Architecture

The app uses an event bus (`ente_events` package) for cross-component communication:

**Key Events:**
- `SignedInEvent` / `SignedOutEvent` - Authentication state changes
- `CollectionsUpdatedEvent` - Triggers UI refresh when collections change
- `BackupUpdatedEvent` - File upload progress/completion

**Pattern:** Services fire events, UI components listen and call `setState()`.

### UI Structure

**Main pages (`lib/ui/pages/`):**
- `HomePage` - Main dashboard with collections grid, recents, and FAB. Extends `UploaderPage`.
- `CollectionPage` - Single-collection view with its files. Extends `UploaderPage`.
- `AllCollectionsPage` - Full collection list filtered by type (home / incoming / outgoing).
- `TrashPage` - Deleted-files management.
- `OnboardingPage` - First-run onboarding flow.
- `DeleteAccountPage` - Account-deletion workflow.
- `SavePage` (`save_page.dart`) - Bottom sheet for creating new info items.
- `FileUploadScreen` (`file_upload_screen.dart`) - Alternative upload entry point used when not embedded in an `UploaderPage`.
- `BaseInfoPage` - Abstract base for structured-information pages, with subclasses:
  - `AccountCredentialsPage`
  - `PersonalNotePage`
  - `EmergencyContactPage`
  - `PhysicalRecordsPage`

**Settings (`lib/ui/settings/`):**
- `SettingsPage` - Settings root.
- Subpages in `lib/ui/settings/pages/`: `about_page.dart`, `account_settings_page.dart`, `general_settings_page.dart`, `security_settings_page.dart`, `settings_search_page.dart`, `support_page.dart`, `theme_settings_page.dart`.

**Sharing UI (`lib/ui/sharing/`):**
- `share_collection_bottom_sheet.dart` - Entry sheet for sharing a collection.
- `album_participants_page.dart` + `manage_album_participant.dart` + `add_participant_page.dart` + `add_email_bottom_sheet.dart` - Participant management.
- `manage_links_widget.dart` + `album_share_info_widget.dart` - Public-link management.
- `pickers/` - Permission / role pickers for participants.

**Navigation:**
- `DrawerPage` (`lib/ui/drawer/drawer_page.dart`) - App navigation drawer.

**Other UI directories:**
- `lib/ui/collections/` - Collection grid widgets (e.g., `CollectionFlexGridView`).
- `lib/ui/components/` - Reusable building blocks.
- `lib/ui/viewer/` - File viewer (actions, date helpers).
- `lib/ui/mixins/` - Cross-page mixins (e.g., `SearchMixin`).

**Key UI Patterns:**
- Pages extend `StatefulWidget` and pull in reusable behavior via mixins (e.g., `SearchMixin`).
- `UploaderPage` / `UploaderPageState` is the base class for pages that handle file uploads.
- Collections use `CollectionFlexGridView` for responsive grid layouts.
- Search is integrated via `SearchMixin` with a search bar in the AppBar.

#### Save Modal Pattern

`lib/ui/pages/save_page.dart` exposes `SaveBottomSheet` together with the `SaveOptionType` enum (`document`, `note`, `physicalRecord`, `credentials`). The bottom sheet is the canonical entry point for creating new info items: the user selects an option and is routed to the matching `BaseInfoPage` subclass. Prefer this flow over instantiating `BaseInfoPage` subclasses directly so the picker, analytics, and routing stay consistent.

### File Upload Flow

1. User selects a file via the `file_picker` package.
2. `UploaderPage.uploadFiles()` picks a collection (or creates one).
3. `FileUploader` (`file_upload_service.dart`) encrypts and uploads to the server.
4. `CollectionService.sync()` is called to fetch updated state.
5. `CollectionsUpdatedEvent` fires → UI refreshes.

### Crypto & Encryption

Files and collections are end-to-end encrypted:
- **Collection keys:** encrypted with the user's master key.
- **File keys:** encrypted with the collection key.
- `CryptoHelper` (`lib/utils/crypto_helper.dart`) provides key-derivation utilities.
- `ente_crypto_api` provides the abstract crypto interface.
- `ente_crypto_dart_adapter` provides the Dart implementation of the crypto API.

### Notable Utilities

Helpers worth knowing about before adding new ones:

`lib/utils/`
- `collection_actions.dart`, `file_actions.dart` - Primary operation helpers used by pages (delete, move, restore, share, etc.).
- `file_util.dart`, `file_icon_utils.dart` - File handling and icon resolution by MIME / extension.
- `collection_sort_util.dart` - Collection sort orders.
- `info_item_utils.dart` - Metadata for structured info-item types (titles, icons, route mapping).
- `crypto_helper.dart` - Key-derivation helpers (see Crypto & Encryption above).

`lib/extensions/`
- `collection_extension.dart`
- `user_extension.dart`

### Platform-Specific Code

**Desktop (Windows / Linux / macOS):**
- Window management via `window_manager` and the locker-side `WindowListenerService`, both initialized in `main.dart` before `runApp()`.
- System tray support via `tray_manager` (icon and context menu set up in `_initSystemTray()`).

**Mobile (iOS / Android):**
- Share-intent handling via `listen_sharing_intent`.
- `HomePage.initializeSharing()` processes files shared from other apps.
- High refresh rate enabled on Android via `flutter_displaymode`.

### Localization

- Uses Flutter's built-in `l10n` system.
- Localization files in `lib/l10n/` - 26 locale `.arb` files.
- Generated code via `flutter gen-l10n` (configured in `l10n.yaml`).
- Shared strings from the `ente_strings` package.
- Access in widgets via `context.l10n.keyName`.

## Code Style & Linting

The project uses strict linting rules defined in `ente/mobile/analysis_options.yaml` (which `analysis_options.yaml` here extends):

**Key enforced rules:**
- `require_trailing_commas` (ERROR) - All function/constructor calls must have trailing commas
- `always_use_package_imports` (WARNING) - Use `package:` imports, not relative
- `prefer_final_fields` (ERROR) - Prefer `final` for non-reassigned fields
- `prefer_const_constructors` (WARNING) - Use `const` constructors where possible
- `unawaited_futures` (WARNING) - Explicitly handle or ignore futures
- `cancel_subscriptions` (ERROR) - Cancel `StreamSubscription`s in `dispose()`
- `prefer_double_quotes` - Use double quotes for strings

**To fix trailing comma errors:** run `dart format .` which auto-adds them.

## Important Patterns

### Service Initialization

`main.dart` initializes services in a strict order (see `lib/main.dart:189-230`). The rule of thumb is that any `*ApiClient` / `*Client` service initializes before the higher-level service that wraps it.

```
 1. CryptoUtil.init()
 2. LockerDB.instance.init()
 3. Configuration.instance.init([preferences, packageInfo])
 4. Network.instance.init(Configuration.instance)
 5. UserService.instance.init(...)
 6. LockScreenSettings.instance.init(Configuration.instance)
 7. CollectionApiClient.instance.init()
 8. CollectionService.instance.init(preferences)
 9. FavoritesService.instance.init()
10. OfflineFilesService.instance.init()
11. LinksClient.instance.init()
12. LinksService.instance.init()
13. ServiceLocator.instance.init(...)
14. UpdateService.instance.init(preferences, packageInfo)
15. TrashService.instance.init(preferences)
16. EmergencyContactService.instance.init(UserService.instance, ...)
17. LockerContactsDisplayService.init(...)
18. LegacyKitService.instance.init(...)
```

On desktop, `windowManager.ensureInitialized()` and `WindowListenerService.instance.init()` run before this sequence begins.

### Sync Pattern

Many operations follow this pattern:
```dart
// 1. Call API
await _apiClient.someOperation(params);

// 2. Sync to update local state
await CollectionService.instance.sync();

// 3. Event bus notifies UI (optional, sync may fire it)
Bus.instance.fire(CollectionsUpdatedEvent());
```

**Important:** Avoid calling `setState()` or manual reloads after operations that trigger `sync()` - the sync fires `CollectionsUpdatedEvent` which already refreshes the UI.

### File References

When referencing code locations in messages, use the format:
```
lib/services/collections/collections_service.dart:123
```

## Common Gotchas

1. **Multiple Flutter apps in monorepo:** Always use `melos bootstrap` instead of `flutter pub get` to properly link local packages.
2. **Window management:** Desktop window initialization must happen before `runApp()` in `main.dart`.
3. **Trailing commas:** The linter is strict about this - always add them to avoid CI failures.
4. **Package imports:** Never use relative imports for files in other packages; always use `package:` syntax.
5. **Sync timing:** File-upload operations should NOT manually call `_loadCollections()` in the callback to avoid duplicate UI refreshes (see `HomePage.onFileUploadComplete()`).
6. **Two `ServiceLocator`s in the monorepo:** Locker's `ServiceLocator` lives at `lib/services/files/download/service_locator.dart` and is scoped to download/URL resolution. The Photos app has a separate, broader `service_locator.dart`. Don't confuse them when copying patterns across apps.
7. **`LockerContactsDisplayService` is not a singleton:** Initialize via the static `LockerContactsDisplayService.init(...)` call; there is no `instance` getter.

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
- For info-item creation flows, route through `SaveBottomSheet` / `SaveOptionType` rather than constructing `BaseInfoPage` subclasses directly

### 3. Design System - MANDATORY
**Never hardcode colors or text styles**
- Always use the Ente design system for colors and typography
- Use a subagent to find the appropriate design tokens
- Access colors via theme: `getEnteColorScheme(context)`
- Access text styles via theme: `getEnteTextTheme(context)`
- Call the above theme getters only at the top of `build` methods and reuse them throughout the component
- If you MUST use custom colors/styles (extremely rare), explicitly inform the user with a clear warning

### 4. Database Methods - BEST PRACTICE
**Prioritize readability in database methods**
- For small result sets (e.g., 1-2 stale entries), prefer filtering in Dart for cleaner, more readable code
- For large datasets, use SQL WHERE clauses for performance - they're much more efficient in SQLite
