# CLAUDE.md

Root reference guide for the Ente monorepo. For component-specific guidance, see the CLAUDE.md files linked in the navigation map below.

**Purpose:** Fully open-source, end-to-end encrypted cloud platform with three products: Ente Photos, Ente Auth (2FA), and Ente Locker (document storage).

**Documented:** 2026-04-04
**Commit:** 0618f522ee

---

## Quick Navigation Map

| To work on...                 | Go to...        | CLAUDE.md                                                      |
| ----------------------------- | --------------- | -------------------------------------------------------------- |
| Web apps (Photos, Auth, etc.) | `web/`          | `web/CLAUDE.md`                                                |
| Mobile apps (Flutter)         | `mobile/`       | `mobile/apps/photos/CLAUDE.md`, `mobile/apps/locker/CLAUDE.md` |
| Desktop app (Electron)        | `desktop/`      | —                                                              |
| API server ("Museum")         | `server/`       | `server/CLAUDE.md`                                             |
| CLI tool                      | `cli/`          | —                                                              |
| Shared Rust core              | `rust/`         | —                                                              |
| User-facing docs site         | `docs/`         | `docs/CLAUDE.md`, `docs/docs/CLAUDE.md`                        |
| E2EE architecture docs        | `architecture/` | —                                                              |
| Infrastructure / workers      | `infra/`        | —                                                              |

---

## Repository Structure

```
ente/
├── server/           # Go API server ("Museum") — Gin, PostgreSQL
├── web/              # Next.js/React/TypeScript web apps (Yarn workspaces)
│   ├── apps/         # photos, auth, accounts, albums, cast, embed, ensu, locker, memories, paste, payments, share, twoof3
│   └── packages/     # accounts, accounts-rs, base, build-config, gallery, media, new, utils, wasm
├── mobile/           # Flutter/Dart mobile apps (Melos monorepo)
│   ├── apps/         # photos, auth, locker
│   └── packages/     # 22 shared packages (accounts, crypto, ui, network, etc.)
├── desktop/          # Electron wrapper around web Photos app
├── cli/              # Go CLI for data export and account management
├── rust/             # Shared Rust core (crypto, auth, media inspection)
│   ├── apps/         # Tauri-wrapped desktop apps (ensu)
│   ├── core/         # ente-core — pure Rust, no FFI
│   ├── cli/          # ente-rs — Rust CLI binary
│   ├── photos/       # ente_media_inspector
│   ├── ensu/         # LLM chat stack
│   └── uniffi/       # UniFFI bindings for native platforms
├── docs/             # VitePress documentation site (ente.com/help)
├── architecture/     # E2EE architecture docs and SVG diagrams
├── infra/            # ML models, Cloudflare Workers, deployment services
└── Tiltfile          # Local K8s dev with Tilt (orbstack)
```

---

## Technology Stack

| Component | Language     | Framework/Runtime           | Key Dependencies                                |
| --------- | ------------ | --------------------------- | ----------------------------------------------- |
| Server    | Go 1.23      | Gin                         | PostgreSQL, AWS SDK (S3), SRP, Stripe, Firebase |
| Web       | TypeScript   | Next.js 15, React 19, MUI 7 | libsodium-wrappers, Yarn 1.22, Turborepo         |
| Mobile    | Dart/Flutter | Flutter 3.32.8              | Melos, sqlite_async, ONNX Runtime, FFmpeg       |
| Desktop   | TypeScript   | Electron 41                 | electron-builder, ONNX, FFmpeg                  |
| CLI       | Go 1.23      | Cobra                       | go-keyring, go-resty                            |
| Rust      | Rust         | tokio, wasm-bindgen         | libsodium, UniFFI, Flutter Rust Bridge          |
| Docs      | Markdown     | VitePress 1.6               | Yarn                                            |

---

## Development Commands

A root `Taskfile.yml` provides unified commands across all components. Requires [Task](https://taskfile.dev) v3+. See `TASKFILE.md` for full documentation and common workflows.

```bash
task                        # List all available tasks
task install                # Install deps for all components
task build                  # Build everything
task lint                   # Lint everything
task test                   # Run all tests
task format                 # Format all code
task clean                  # Clean all build artifacts
```

### Web (`web/`)

```bash
task web:install            # Install deps for web workspace
task web:dev                # Photos on :3000 (default)
task web:dev -- auth        # Auth on :3003
task web:dev -- locker      # Locker on :3009
task web:build              # Build Photos
task web:build -- <app>     # Build specific app
task web:build-wasm         # Build Rust WASM package
task web:lint               # Format + lint + typecheck
task web:lint-fix           # Auto-fix lint issues
task web:test               # Run WASM package tests
```

### Mobile (`mobile/`)

```bash
task mobile:bootstrap       # Link all local packages
task mobile:run             # Run Photos on device
task mobile:run -- auth     # Run Auth
task mobile:build           # Build Photos APK
task mobile:lint            # Static analysis (must pass before commit)
task mobile:format          # Format Dart code
task mobile:codegen         # Regenerate Rust bindings
```

### Server (`server/`)

```bash
task server:install         # Download Go modules
task server:up              # Local dev cluster (Museum + Postgres + MinIO)
task server:up-d            # Start in background
task server:down            # Stop the stack
task server:logs            # Tail container logs
task server:db              # Open psql shell to dev database
task server:build           # Build server binary
task server:dev             # Start with hot reload (air)
task server:lint            # go vet + staticcheck
task server:test            # Run Go tests
```

### Desktop (`desktop/`)

```bash
task desktop:install        # Install dependencies
task desktop:dev            # Start Electron + Next.js dev
task desktop:build          # Full build (renderer + electron-builder)
task desktop:lint           # prettier + eslint + tsc
```

### CLI (`cli/`)

```bash
task cli:install            # Install dependencies
task cli:build              # Build CLI binary
```

### Docs (`docs/`)

```bash
task docs:install           # Install dependencies
task docs:dev               # Dev server on :5173
task docs:build             # Production build
task docs:format            # Format with Prettier
```

### Rust (`rust/`)

```bash
task rust:build             # Build all crates (debug)
task rust:test              # Run all tests
task rust:lint              # clippy with -D warnings
task rust:fmt               # Format all Rust code
```

---

## Architecture Overview

### End-to-End Encryption Model

All data is encrypted client-side before leaving the device. The server stores only encrypted data and has zero knowledge of contents.

**Key hierarchy:**

1. **masterKey** — generated on signup, never leaves device unencrypted
2. **keyEncryptionKey (KEK)** — derived from user password via Argon2 (min 128MB memory)
3. **collectionKey** — per-album/folder, encrypted with masterKey
4. **fileKey** — per-file, encrypted with collectionKey

**Crypto primitives** (via libsodium / Rust ente-core):

- XChaCha20-Poly1305 (secretbox / file streams)
- X25519 (key exchange for sharing)
- Argon2 (password-based key derivation)
- BIP39 (24-word mnemonic recovery key)

**Sharing:** Asymmetric encryption — sender encrypts collectionKey with recipient's public key.

### Authentication

Multi-layer auth implemented via SRP (Secure Remote Password):

1. Email verification (OTP)
2. SRP — password never sent in plaintext
3. Optional: WebAuthn/passkeys, TOTP, email MFA
4. Recovery keys for account recovery

Auth flow details: `rust/core/docs/auth.md`
Crypto wire formats: `rust/core/docs/crypto.md`

### Data Flow

```
Client → encrypt(fileKey) → encrypt(collectionKey) → upload to Museum → replicate to 3 S3 providers
```

Museum (server) is stateless. All persistent state lives in PostgreSQL (metadata, encrypted keys) and S3 (encrypted file data).

### Cross-Platform Code Sharing

```
rust/core/ (ente-core)
  ├── → web via wasm-bindgen (web/packages/wasm/)
  ├── → mobile via Flutter Rust Bridge (mobile/packages/rust/)
  └── → CLI via direct Rust dependency (rust/cli/)
```

---

## Component Relationships

- **Desktop** renders the **web** Photos app inside Electron, adding native file system access, auto-update, and tray
- **Mobile** and **web** share the **Rust** core for crypto and auth via FFI/WASM
- **Server** ("Museum") is the unified API backend for all clients
- All clients talk to the same Museum API and share the same PostgreSQL/S3 backend
- **Auth** (2FA) shares credentials with **Photos** — same user account
- **Memories** is a standalone **web** app (`web/apps/memories/`) for public sharing of photo memories (curated "shares" and auto-generated "lanes" with face crops). Not included in the `ghcr.io/ente-io/web` Docker image — requires custom build. Mobile Photos app has home screen widgets (iOS/Android) for displaying and sharing memories. Server API: authenticated endpoints at `/memory-share`, public endpoints at `/public-memory` (via `X-Auth-Access-Token` header). Shares auto-expire after 7 days.

---

## Database & Migrations

- Server uses PostgreSQL with 238 migration files in `server/migrations/`
- Mobile apps use SQLite via `sqlite_async` / `sqflite`
- Web apps use browser-side storage

### Core Server Tables

| Table                | Purpose                                                            |
| -------------------- | ------------------------------------------------------------------ |
| `users`              | User accounts                                                      |
| `files`              | Encrypted photo/file metadata                                      |
| `collections`        | Albums/folders                                                     |
| `collection_shares`  | E2EE sharing between users                                         |
| `key_attributes`     | Encrypted key material (KEK params, etc.)                          |
| `tokens`             | Session tokens                                                     |
| `otts`               | One-time tokens (email OTP)                                        |
| `memory_shares`      | Public memory share metadata (E2EE keys, access tokens, 7-day TTL) |
| `memory_share_files` | Files within a memory share (position, per-file encrypted keys)    |

---

## Self-Hosting

Quickstart: `docker compose up` in `server/` (Museum + Postgres + MinIO on port 8080).

Detailed guides in `docs/docs/self-hosting/`:

- Docker Compose: `installation/quickstart.md`
- Kubernetes/Helm: `guides/photos-k8s-helm.md`
- Configuration: `installation/config.md` (museum.yaml reference)
- S3 buckets: hardcoded names `b2-eu-cen`, `wasabi-eu-central-2-v3`, `scw-eu-fr-v3` (any provider works)
- Memories app: **not included** in `ghcr.io/ente-io/web` Docker image — requires custom build. Museum config: `apps.public-memories` / env `ENTE_APPS_PUBLIC_MEMORIES` (default: `https://memories.ente.io`)

Mobile/desktop apps: tap onboarding screen 7 times to access developer settings and enter custom server endpoint.

---

## Common Tasks

### To add a new web app

1. Create app in `web/apps/<name>/`
2. Add to Yarn workspaces in `web/package.json`
3. Add dev/build scripts to root `web/package.json`

### To add a new mobile package

1. Create package in `mobile/packages/<name>/`
2. Add to `mobile/melos.yaml`
3. Run `melos bootstrap` to link

### To add Rust functionality accessible from clients

1. Implement in `rust/core/` (pure Rust, no FFI)
2. Expose via `rust/uniffi/` for mobile (Flutter Rust Bridge)
3. Expose via `web/packages/wasm/` for web (wasm-bindgen)
4. Run `flutter_rust_bridge_codegen generate` for mobile bindings

### To run the full local stack

```bash
# Terminal 1: Server
task server:up

# Terminal 2: Web
task web:dev

# Mobile: point to local server via developer settings
```

---

## Critical Gotchas

1. **Task runner at root** — a `Taskfile.yml` provides unified commands across all components (see `TASKFILE.md`). Each component still manages its own deps (Yarn, Melos, Go modules, Cargo).
2. **Database backup is essential** — PostgreSQL contains encrypted key material. Without it, S3 data is permanently inaccessible.
3. **S3 bucket names are hardcoded** in server config (`b2-eu-cen`, `wasabi-eu-central-2-v3`, `scw-eu-fr-v3`). Names are arbitrary; any S3 provider works.
4. **HTTPS required** — Museum rejects HTTP in production.
5. **Docker Compose 2.30+** required for server's post_start lifecycle hooks.
6. **Mobile: always use `melos bootstrap`** instead of `flutter pub get` to properly link local packages.
7. **Web: use Yarn** (not npm) for package management.
8. **Mobile linting is strict** — `dart format .` and `flutter analyze` must pass with zero issues before any commit.
9. **Large service files** — some mobile services exceed 70k lines. Be mindful of context when editing.
10. **Encryption keys must persist** — if self-hosting with Helm, set `credentials.encryption` and `jwt` explicitly or keys regenerate on upgrade, breaking existing data.

---

## Security & Audits

- Externally audited by **Cure53**, **Symbolic Software**, and **Fallible**
- Security vulnerabilities: email <security@ente.com>
- Architecture docs: `architecture/README.md`
- Crypto implementation: `rust/core/docs/crypto.md`

---

## External Resources

- **Product site:** <https://ente.com>
- **Documentation:** <https://ente.com/help>
- **GitHub:** <https://github.com/ente-io/ente>
- **Discord:** <https://ente.com/discord>
- **Discussions:** <https://github.com/ente-io/ente/discussions>
