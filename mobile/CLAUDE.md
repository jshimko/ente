# CLAUDE.md

Reference guide for the Ente mobile monorepo workspace. For app-specific guidance, see the CLAUDE.md files linked in the navigation map below.

**Purpose:** Flutter/Dart monorepo containing three Ente mobile apps (Photos, Auth, Locker) and 24 shared packages, managed by Melos.

**Documented:** 2026-05-28
**Commit:** 8185f4a781

---

## Quick Navigation Map

| To work on...                  | Go to...                          | CLAUDE.md                        |
| ------------------------------ | --------------------------------- | -------------------------------- |
| Photos app                     | `apps/photos/`                    | `apps/photos/CLAUDE.md`         |
| Auth (2FA) app                 | `apps/auth/`                      | —                                |
| Locker (document storage) app  | `apps/locker/`                    | `apps/locker/CLAUDE.md`         |
| Authentication / account flows | `packages/accounts/`              | —                                |
| Encryption / crypto            | `packages/ente_crypto_api/`       | —                                |
| Shared UI components           | `packages/ui/`                    | —                                |
| Localization strings           | `packages/strings/`               | —                                |
| Network / HTTP layer           | `packages/network/`               | —                                |
| Contacts management            | `packages/contacts/`              | —                                |
| Rust FFI bindings              | `packages/rust/`                  | —                                |
| App configuration              | `packages/configuration/`         | —                                |
| Photos-specific plugins        | `apps/photos/plugins/`            | —                                |
| Native iOS/Android code        | `native/`                         | —                                |
| Melos workspace config         | `melos.yaml`                      | —                                |
| Lint rules                     | `analysis_options.yaml`           | —                                |

---

## Monorepo Structure

```
mobile/
├── apps/
│   ├── photos/              # Photo backup & management (v1.3.47+1788)
│   │   ├── lib/             # Main Dart source (services, ui, models, db, gateways)
│   │   ├── plugins/         # Photos-specific Flutter plugins
│   │   │   ├── ente_cast/           # Chromecast integration (variants wired at flavor layer)
│   │   │   ├── ente_crypto/         # Encryption primitives
│   │   │   ├── ente_feature_flag/   # Feature flags
│   │   │   ├── ente_qr/            # QR code handling
│   │   │   └── onnx_dart/          # ML/ONNX runtime
│   │   └── rust_builder/    # Photos-specific Rust FFI
│   ├── auth/                # 2FA authenticator app (v4.4.23+877)
│   │   └── lib/             # Main Dart source
│   └── locker/              # Secure document storage (v1.0.4+104)
│       └── lib/             # Main Dart source
├── packages/                # 24 shared Dart packages (see reference below)
├── native/                  # Native iOS/Android code (Swift, Kotlin)
│   ├── android/             # Kotlin/Gradle modules
│   └── darwin/              # Swift/Xcode projects
├── mobile-tests/            # Integration tests
├── melos.yaml               # Monorepo workspace config
├── pubspec.yaml             # Root pubspec (melos + flutter_lints)
└── analysis_options.yaml    # Shared lint rules (strict)
```

---

## Apps Summary

| App     | Package Name | Version        | Dart SDK         | Entry Point      | Platforms              |
| ------- | ------------ | -------------- | ---------------- | ---------------- | ---------------------- |
| Photos  | `photos`     | 1.3.47+1788    | >=3.10.0 <4.0.0 | `lib/main.dart`  | Android, iOS           |
| Auth    | `ente_auth`  | 4.4.23+877     | >=3.10.0 <4.0.0 | `lib/main.dart`  | Android, iOS, Desktop  |
| Locker  | `locker`     | 1.0.4+104      | >=3.10.0 <4.0.0 | `lib/main.dart`  | Android, iOS, Desktop  |

- **Photos** is the largest app (400+ dependencies, 28+ services, ML features, Rust integration)
- **Auth** is the 2FA authenticator with QR scanning, TOTP/HOTP support, cloud backup
- **Locker** is secure document storage with collections, sharing, and desktop support (window_manager, tray_manager)

---

## Shared Packages Reference

### Foundation (no internal dependencies)

| Package             | Directory                    | Purpose                                            |
| ------------------- | ---------------------------- | -------------------------------------------------- |
| `ente_base`         | `packages/base/`             | Shared models and types foundation                 |
| `ente_pure_utils`   | `packages/ente_pure_utils/`  | Pure Dart utilities (email validation, crypto, path)|
| `ente_events`       | `packages/events/`           | Event bus for cross-component communication        |
| `ente_strings`      | `packages/strings/`          | Localization strings (ARB files for i18n)          |
| `ente_icons`        | `packages/ente_icons/`       | Custom icon font (EnteIcons.ttf)                   |

### Crypto & Security

| Package                      | Directory                             | Purpose                                         |
| ---------------------------- | ------------------------------------- | ----------------------------------------------- |
| `ente_crypto_api`            | `packages/ente_crypto_api/`           | Abstract crypto interface (key derivation, encrypt/decrypt) |
| `ente_crypto_dart_adapter`   | `packages/ente_crypto_dart_adapter/`  | Dart implementation of crypto API (adapter pattern) |
| `ente_rust`                  | `packages/rust/`                      | Rust FFI via flutter_rust_bridge (crypto, networking) |

### Configuration & Infrastructure

| Package              | Directory                     | Purpose                                                 |
| -------------------- | ----------------------------- | ------------------------------------------------------- |
| `ente_configuration` | `packages/configuration/`     | Centralized config (flutter_secure_storage, SharedPreferences) |
| `ente_logging`       | `packages/logging/`           | Structured logging with Sentry integration              |
| `ente_network`       | `packages/network/`           | HTTP client (Cronet on Android, native adapter on iOS)  |

### UI & Presentation

| Package            | Directory                      | Purpose                                                    |
| ------------------ | ------------------------------ | ---------------------------------------------------------- |
| `ente_ui`          | `packages/ui/`                 | Design system: buttons, dialogs, layout, theming (52 Dart files) |
| `ente_components`  | `packages/ente_components/`    | Shared design-system components (color tokens, app bar, bottom sheets, icon sizing) |
| `log_viewer`       | `packages/log_viewer/`         | In-app log viewer with SQLite storage and filtering        |
| `ente_qr_ui`       | `packages/qr/`                 | QR code generation and sharing UI                          |

### Feature Packages

| Package            | Directory                  | Purpose                                              |
| ------------------ | -------------------------- | ---------------------------------------------------- |
| `ente_accounts`    | `packages/accounts/`       | Auth flows (login, SRP, passkeys, 2FA, recovery)     |
| `ente_lock_screen` | `packages/lock_screen/`    | Biometric auth, PIN entry, privacy screen            |
| `ente_sharing`     | `packages/sharing/`        | Cryptographic sharing and share link generation      |
| `ente_contacts`    | `packages/contacts/`       | Shared contacts client, cache, and Rust orchestration |
| `ente_legacy`      | `packages/legacy/`         | Legacy services (emergency contacts, backwards compat)|

### Utilities

| Package        | Directory              | Purpose                                          |
| -------------- | ---------------------- | ------------------------------------------------ |
| `ente_utils`   | `packages/utils/`      | File/archive ops, email, app info, sharing       |

### Platform Plugins (Native)

| Package               | Directory                         | Platforms       | Purpose                                    |
| --------------------- | --------------------------------- | --------------- | ------------------------------------------ |
| `native_video_editor` | `packages/native_video_editor/`   | Android, iOS    | Video trim/crop/rotate without re-encoding |
| `scoped_dir_access`   | `packages/scoped_dir_access/`     | iOS, macOS, Android | Security-scoped bookmarks, SAF access  |
| `backup_exclusion`    | `packages/backup_exclusion/`      | iOS             | Prevent iCloud backup of sensitive data    |

---

## Package Dependency Graph

```
                    ┌──────────────────────────────────────┐
                    │         Apps (Photos, Auth, Locker)   │
                    └──────────────┬───────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                     ▼
        ente_legacy          ente_sharing          ente_lock_screen
              │                    │                     │
              └────────┬───────────┘                     │
                       ▼                                 ▼
                 ente_accounts ◄──────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
     ente_ui      ente_network   ente_configuration
         │             │             │
         └──────┬──────┘             │
                ▼                    ▼
          ente_logging         ente_crypto_api
                                    │
                        ┌───────────┤
                        ▼           ▼
            ente_crypto_dart    ente_rust (FFI)
              _adapter

    ─── Foundation (no internal deps) ───
    ente_base  ente_pure_utils  ente_events  ente_strings  ente_icons
```

---

## Architecture Patterns (Shared Across Apps)

### Service Locator (Manual DI)
All apps use lazy-initialized singletons. No DI framework (no GetIt, no Riverpod).
```dart
FlagService? _flagService;
FlagService get flagService => _flagService ??= FlagService(...);
```
- Photos: `apps/photos/lib/service_locator.dart` (379 lines, 40 lazy getters)
- Locker/Auth: Services initialized in `main.dart` (Locker also has a small local `ServiceLocator` for downloads; Auth has no service locator)

### Event Bus
Cross-component communication via `ente_events` package (`event_bus` from pub.dev).
```dart
Bus.instance.fire(CollectionsUpdatedEvent());
Bus.instance.on<CollectionsUpdatedEvent>().listen((_) => setState(() {}));
```
Common events: `SignedInEvent`, `SignedOutEvent`, `CollectionsUpdatedEvent`, `BackupUpdatedEvent`, `SyncStatusUpdate`

### Gateway Pattern (API Layer)
Services call gateways, gateways use Dio for HTTP.
```
UI → Service → Gateway → Dio → Ente Server
                  ↓
              SQLite DB → Event Bus → UI refresh
```
Photos gateways live in `apps/photos/lib/gateways/`, grouped into ~11 subdirectories (`billing/`, `cast/`, `collections/`, `emergency/`, `entity/`, `files/`, `push/`, `social/`, `storage_bonus/`, `trash/`, `users/`) holding ~18 gateway classes, each constructed with a `Dio` instance.

### SQLite Database Layer
- Photos: uses both `sqlite_async` and `sqflite` (plus `sqflite_migration`) with versioned migrations (`PRAGMA user_version`)
- Locker: `sqflite` with sync-time tracking for incremental sync
- Base mixin: `SqlDbBase` (`apps/photos/lib/db/common/base.dart`) handles migration scripts atomically

### Rust FFI (flutter_rust_bridge)
Performance-critical operations (ML inference, crypto, vector search) run in Rust:
- Shared bindings: `packages/rust/` → generates `frb_generated.dart`
- Photos-specific: `apps/photos/rust_builder/` → ML compute in isolated `MLComputer` isolate
- Codegen: a single `melos run codegen:rust` regenerates all bindings — it runs the repo-pinned FRB generator via `cargo codegen frb` in `rust/`

### Code Generation
- **Freezed** (`3.2.0`): Immutable models with `.freezed.dart` + `.g.dart`
- **JSON Serializable** (`6.10.0`): JSON serialization
- **intl_utils** (`2.8.10`): Localization from ARB files → `AppLocalizations`
- **flutter_rust_bridge** (`2.12.0`): Rust FFI bindings (see Rust FFI above)
- Run: `dart run build_runner build --delete-conflicting-outputs`

---

## Development Commands

### Melos (from `mobile/` directory)

```bash
melos bootstrap                    # Link all local packages (ALWAYS use instead of flutter pub get)
melos run codegen:rust             # Generate all Rust bindings (runs `cargo codegen frb` in rust/)
melos run get:all                  # flutter pub get --enforce-lockfile in all projects
melos run get:plugins              # flutter pub get --enforce-lockfile in apps/photos/plugins/* only
melos run clean:all                # flutter clean in all projects
melos run clean:plugins            # flutter clean in apps/photos/plugins/* only
```

### App-Specific (via Melos)

```bash
# Run apps
melos run run:photos:apk           # Run Photos (--flavor independent)
melos run run:auth:apk             # Run Auth
melos run run:locker:apk           # Run Locker

# Build apps
melos run build:photos:apk         # Release APK for Photos
melos run build:auth:appbundle     # Release AppBundle for Auth
melos run build:locker:ios         # Release iOS for Locker

# Clean apps
melos run clean:photos
melos run clean:auth
melos run clean:locker
```

### Direct Flutter (from app directory)

```bash
flutter run -t lib/main.dart --flavor independent   # Dev run
flutter build apk --release                          # Android release
flutter build ios --release                          # iOS release
flutter analyze                                      # Lint check
dart format .                                        # Format code
flutter test                                         # Run tests
```

### Root Taskfile (from repo root)

```bash
task mobile:bootstrap              # melos bootstrap
task mobile:run                    # Run Photos
task mobile:run -- auth            # Run Auth
task mobile:build                  # Build Photos APK
task mobile:lint                   # flutter analyze
task mobile:format                 # dart format
task mobile:codegen                # Regenerate Rust bindings
```

---

## Linting & Code Quality

Strict rules enforced in `analysis_options.yaml` (shared across all apps/packages):

| Rule                         | Severity | Notes                                     |
| ---------------------------- | -------- | ----------------------------------------- |
| `require_trailing_commas`    | ERROR    | `dart format .` auto-fixes this           |
| `prefer_final_fields`        | ERROR    | Use `final` for non-reassigned fields     |
| `cancel_subscriptions`       | ERROR    | Must cancel `StreamSubscription` in `dispose()` |
| `unused_import`              | ERROR    | No unused imports                         |
| `always_use_package_imports` | WARNING  | Use `package:` imports, never relative    |
| `unawaited_futures`          | WARNING  | Explicitly handle or `unawaited()` futures|
| `prefer_const_constructors`  | WARNING  | Use `const` where possible                |
| `prefer_double_quotes`       | IGNORED  | Not enforced despite being listed         |

Additional ERROR-level rules are enforced (e.g., `avoid_empty_else`, `exhaustive_cases`, `directives_ordering`, `unrelated_type_equality_checks`, `unnecessary_const`, `camel_case_types`). See `analysis_options.yaml` for the full set.

**Mandatory pre-commit checks:**
```bash
dart format .        # Must produce no changes
flutter analyze      # Must pass with zero issues
```

---

## Design System

All apps share the Ente design system via `packages/ui/`:

```dart
// Access colors (call at top of build methods, reuse throughout)
final colors = getEnteColorScheme(context);
colors.primary700    // Example usage

// Access text styles
final textTheme = getEnteTextTheme(context);
textTheme.body       // Example usage
```

**Never hardcode colors or text styles.** Always use the design system tokens.

Shared UI components in `packages/ui/lib/`: buttons (`gradient_button`, `icon_button_widget`), dialogs (`dialog_widget`, `action_sheet_widget`), layout helpers, toast utilities.

---

## Encryption Model (Mobile)

All data is encrypted client-side before upload. The server has zero knowledge of contents.

**Key hierarchy:**
1. **masterKey** — generated on signup via BIP39 (24-word mnemonic), stored in platform secure storage
2. **keyEncryptionKey (KEK)** — derived from password via Argon2
3. **collectionKey** — per-album/folder, encrypted with masterKey
4. **fileKey** — per-file, encrypted with collectionKey

**Storage on device:**
- Secure Storage (iOS Keychain / Android EncryptedSharedPreferences): master key, secret key, auth token
- SharedPreferences: non-sensitive configuration
- SQLite: encrypted file metadata, per-file/collection encryption keys

**Crypto packages:**
- `ente_crypto_api` — abstract interface for all crypto operations
- `ente_crypto_dart_adapter` — Dart implementation (wraps `ente_crypto_dart` from git)
- `ente_rust` — Rust implementation for performance-critical paths
- `apps/photos/plugins/ente_crypto/` — Photos-specific crypto plugin

---

## Common Tasks

### Add a new shared package
1. Create package in `packages/<name>/` with `pubspec.yaml`
2. Run `melos bootstrap` to link it
3. Import in apps via `package:ente_<name>/...`

### Add a Photos-specific plugin
1. Create plugin in `apps/photos/plugins/<name>/`
2. Already included in melos workspace (`apps/photos/plugins/*` glob in `melos.yaml`)
3. Run `melos bootstrap`

### Run an app locally
```bash
cd mobile && melos bootstrap
melos run run:photos:apk    # or run:auth:apk or run:locker:apk
```

### Generate Rust bindings
```bash
cd mobile && melos run codegen:rust   # Runs `cargo codegen frb` in rust/ (repo-pinned FRB generator)
```

### Add a localization string
1. Add key to `lib/l10n/intl_en.arb` in the relevant app
2. Run `flutter pub get` to regenerate `AppLocalizations`
3. Use: `AppLocalizations.of(context).yourKey` or `context.l10n.yourKey`

---

## Critical Gotchas

1. **Always `melos bootstrap`** — never use `flutter pub get` directly; it won't link local packages
2. **Trailing commas are errors** — `require_trailing_commas` is enforced at ERROR level; `dart format .` auto-fixes
3. **`flutter_secure_storage` pinned at v9.0.0** — due to a bug where lockscreen keys don't persist after reinstall (GitHub issue #870)
4. **Package imports only** — `always_use_package_imports` is enforced; never use relative imports across packages
5. **Large service files** — Photos `collections_service.dart` is 84KB+; some services exceed 70K lines. Be mindful of context limits
6. **Melos `--scope` must match the `pubspec.yaml` `name` field** — Photos (`photos`) and Locker (`locker`) match, but the auth scripts use `--scope="auth"` while the app is named `ente_auth`, so `run:auth:apk` / `build:auth:appbundle` / `clean:auth` match no package. Run or build Auth from `apps/auth/` directly
7. **Rust codegen must run after Rust source changes** — a single `melos run codegen:rust` (`cargo codegen frb` in `rust/`) regenerates all bindings
8. **Desktop apps need window init before `runApp()`** — Locker and Auth initialize `windowManager` in `main.dart` before the app starts
9. **Flutter 3.38.10 required** — pinned in `mobile/.fvmrc` and in every CI workflow (`FLUTTER_VERSION: "3.38.10"`); matches the `>=3.10.0 <4.0.0` Dart SDK constraint in `apps/*/pubspec.yaml`. Melos invokes Flutter via the FVM symlink (`sdkPath: .fvm/flutter_sdk` in `melos.yaml`), so `fvm install 3.38.10` is required before running any `melos run …` commands
10. **Cancel stream subscriptions** — `cancel_subscriptions` is ERROR level; always cancel in `dispose()`
