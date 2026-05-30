# Building Ente Photos Android APK for Self-Hosting

Guide for building the Ente Photos Android app from source and sideloading it to connect to a self-hosted server.

---

## Prerequisites

| Tool                            | Version       | Install                                                                 |
| ------------------------------- | ------------- | ----------------------------------------------------------------------- |
| **Flutter**                     | 3.32.8        | [flutter.dev/get-started](https://docs.flutter.dev/get-started/install) |
| **Rust**                        | 1.90.0        | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh`       |
| **JDK**                         | 17            | Via package manager or [adoptium.net](https://adoptium.net/)            |
| **Android SDK**                 | compileSdk 36 | Via Android Studio SDK Manager                                          |
| **Android NDK**                 | 28.2.13676358 | Via Android Studio SDK Manager > SDK Tools > NDK                        |
| **Melos**                       | 6.0+          | `dart pub global activate melos`                                        |
| **flutter_rust_bridge_codegen** | latest        | `cargo install flutter_rust_bridge_codegen`                             |

Ensure `flutter doctor` passes for Android and that Rust Android targets are installed:

```bash
rustup target add aarch64-linux-android armv7-linux-androideabi
```

---

## Build Steps

### 1. Clone and initialize submodules

```bash
git clone https://github.com/ente-io/ente.git
cd ente
git submodule update --init --recursive
```

### 2. Bootstrap the mobile workspace

```bash
cd mobile
melos bootstrap
```

This links all local packages and runs `flutter pub get` across the workspace.

### 3. Generate Rust FFI bindings

Order matters — core bindings first, then Photos-specific bindings.

```bash
# Core bindings
cd packages/rust
flutter_rust_bridge_codegen generate

# Photos bindings
cd ../../apps/photos
flutter_rust_bridge_codegen generate
```

### 4. Set up signing

Create a keystore if you don't have one:

```bash
keytool -genkey -v -keystore ~/ente-photos.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ente
```

Create `mobile/apps/photos/android/key.properties`:

```properties
storeFile=/absolute/path/to/ente-photos.jks
keyAlias=ente
keyPassword=your-key-password
storePassword=your-store-password
```

Alternatively, use environment variables instead of `key.properties`:

```bash
export SIGNING_KEY_PATH=/absolute/path/to/ente-photos.jks
export SIGNING_KEY_ALIAS=ente
export SIGNING_KEY_PASSWORD=your-key-password
export SIGNING_STORE_PASSWORD=your-store-password
```

### 5. Build the APK

From `mobile/apps/photos/`:

```bash
flutter build apk \
  --dart-define=endpoint=https://your-server.example.com \
  --dart-define=cronetHttpNoPlay=true \
  --release \
  --flavor independent \
  --target-platform android-arm64
```

The APK will be at:

```
mobile/apps/photos/build/app/outputs/flutter-apk/app-independent-release.apk
```

#### Build options

| Flag                                          | Purpose                                                            |
| --------------------------------------------- | ------------------------------------------------------------------ |
| `--dart-define=endpoint=URL`                  | Bake in your server URL as the default endpoint                    |
| `--dart-define=cronetHttpNoPlay=true`         | Avoid Google Play Cronet dependency (required for non-Play builds) |
| `--flavor independent`                        | Self-hosting / sideload flavor (recommended)                       |
| `--target-platform android-arm64`             | ARM64 only (faster build, covers most modern phones)               |
| `--target-platform android-arm,android-arm64` | Both 32-bit and 64-bit ARM (broader compatibility)                 |

#### Debug build (for testing)

```bash
flutter run \
  --dart-define=endpoint=https://your-server.example.com \
  --flavor independent \
  --debug \
  -t lib/main.dart
```

---

## Connecting to Your Self-Hosted Server

There are two ways to configure the server endpoint. They can be used independently or together.

### Option A: Build-time (baked in)

Pass `--dart-define=endpoint=https://your-server.example.com` when building. This becomes the default endpoint for that APK.

### Option B: Runtime (no rebuild needed)

Works with any Ente Photos APK, including the official release:

1. Open the app to the login/signup screen
2. **Tap the screen 7 times**
3. Confirm the developer settings warning dialog
4. Enter your server URL (e.g., `https://your-server.example.com`)
5. The app pings `<url>/ping` and expects `{"message":"pong"}` to validate

The setting persists across app restarts via SharedPreferences.

### Endpoint priority

1. **Runtime setting** (SharedPreferences, set via developer settings) — highest
2. **Build-time constant** (`--dart-define=endpoint=...`)
3. **Default:** `https://api.ente.io`

---

## Sideloading

1. Transfer `app-independent-release.apk` to your phone (ADB, file share, email, etc.)
2. On your phone, enable **Settings > Install from unknown sources** for your file manager or browser
3. Open the APK and install
4. Launch the app and configure your server endpoint (see above)

Via ADB:

```bash
adb install app-independent-release.apk
```

---

## Build Flavors

| Flavor            | Application ID               | Use case                                          |
| ----------------- | ---------------------------- | ------------------------------------------------- |
| **`independent`** | `io.ente.photos.independent` | Sideloading and self-hosting (recommended)        |
| `fdroid`          | `io.ente.photos.fdroid`      | F-Droid distribution (strips billing permissions) |
| `playstore`       | `io.ente.photos`             | Google Play Store releases                        |
| `dev`             | `io.ente.photos.dev`         | Development and testing                           |

Use **`independent`** for self-hosting. This is the same flavor used for official GitHub releases.

---

## Network and SSL

The app's Android network security config (`network_security_config.xml`) allows:

- **Cleartext HTTP** to non-ente.io domains — your self-hosted server can use HTTP
- **User-installed CA certificates** are trusted — self-signed HTTPS certs work

No additional configuration is needed for custom SSL setups.

---

## Quick Reference

### Using Taskfile (recommended)

Requires [Task](https://taskfile.dev) v3+. Run from the repo root:

```bash
# Build with self-hosted endpoint baked in
task mobile:apk -- https://your-server.example.com

# Build without a baked-in endpoint (configure at runtime via developer settings)
task mobile:apk

# Install on connected device
task mobile:sideload
```

`mobile:apk` automatically handles submodule init, workspace bootstrap, Rust codegen, and building the release APK with the `independent` flavor.

### Manual steps

Full build from scratch without Taskfile:

```bash
# 1. Setup
cd ente
git submodule update --init --recursive

# 2. Bootstrap
cd mobile
melos bootstrap

# 3. Generate Rust bindings
cd packages/rust && flutter_rust_bridge_codegen generate
cd ../../apps/photos && flutter_rust_bridge_codegen generate

# 4. Create android/key.properties (see signing section)

# 5. Build
flutter build apk \
  --dart-define=endpoint=https://your-server.example.com \
  --dart-define=cronetHttpNoPlay=true \
  --release \
  --flavor independent \
  --target-platform android-arm64

# 6. Sideload
adb install build/app/outputs/flutter-apk/app-independent-release.apk
```

---

## Troubleshooting

**Rust compilation is slow on first build** — Cross-compiling Rust for Android ARM takes 10-20 minutes the first time. Subsequent builds are cached.

**Disk space** — A full build with Rust toolchains, Android SDK, and NDK requires ~10GB+ of free space.

**Firebase/push notifications** — The app builds and runs without Google services configuration. Push notifications won't work, but all other functionality is unaffected.

**"No connected devices"** — Ensure USB debugging is enabled on your phone and `adb devices` shows your device. For wireless debugging, use `adb connect <ip>:<port>`.

**Build fails at Rust step** — Verify Android NDK 28.2.13676358 is installed and that Rust Android targets are present: `rustup target list --installed` should show `aarch64-linux-android`.
