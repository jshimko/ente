# CLAUDE.md

Root reference guide for the Ente monorepo. For component-specific guidance, see the CLAUDE.md files linked in the navigation map below.

**Purpose:** Fully open-source, end-to-end encrypted cloud platform with three products: Ente Photos, Ente Auth (2FA), and Ente Locker (document storage).

**Documented:** 2026-04-03
**Commit:** a875a1703f

---

## Quick Navigation Map

| To work on...            | Go to...                | CLAUDE.md                        |
| ------------------------ | ----------------------- | -------------------------------- |
| Web apps (Photos, Auth, etc.) | `web/`             | `web/CLAUDE.md`                  |
| Mobile apps (Flutter)    | `mobile/`               | `mobile/apps/photos/CLAUDE.md`, `mobile/apps/locker/CLAUDE.md` |
| Desktop app (Electron)   | `desktop/`              | —                                |
| API server ("Museum")    | `server/`               | `server/CLAUDE.md`               |
| CLI tool                 | `cli/`                  | —                                |
| Shared Rust core         | `rust/`                 | —                                |
| User-facing docs site    | `docs/`                 | `docs/CLAUDE.md`, `docs/docs/CLAUDE.md` |
| E2EE architecture docs   | `architecture/`         | —                                |
| Infrastructure / workers | `infra/`                | —                                |

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
└── infra/            # ML models, Cloudflare Workers, deployment services
```

---

## Technology Stack

| Component | Language     | Framework/Runtime         | Key Dependencies                              |
| --------- | ------------ | ------------------------- | --------------------------------------------- |
| Server    | Go 1.23      | Gin                       | PostgreSQL, AWS SDK (S3), SRP, Stripe, Firebase |
| Web       | TypeScript   | Next.js 15, React 19, MUI 7 | libsodium-wrappers, Yarn 1.22                |
| Mobile    | Dart/Flutter | Flutter 3.32.8            | Melos, sqlite_async, ONNX Runtime, FFmpeg     |
| Desktop   | TypeScript   | Electron 41               | electron-builder, ONNX, FFmpeg                |
| CLI       | Go 1.23      | Cobra                     | go-keyring, go-resty                          |
| Rust      | Rust         | tokio, wasm-bindgen       | libsodium, UniFFI, Flutter Rust Bridge        |
| Docs      | Markdown     | VitePress 1.6             | Yarn                                          |

---

## Development Commands

### Web (`web/`)

```bash
yarn install                # Install deps (Yarn 1.22)
yarn dev:photos             # Photos on :3000
yarn dev:accounts           # Accounts on :3001
yarn dev:albums             # Albums on :3002
yarn dev:auth               # Auth on :3003
yarn dev:cast               # Cast on :3004
yarn dev:share              # Share on :3005
yarn dev:embed              # Embed on :3006
yarn dev:ensu               # Ensu on :3007
yarn dev:paste              # Paste on :3008
yarn dev:locker             # Locker on :3009
yarn dev:memories           # Memories on :3010
yarn dev:twoof3             # TwoOf3 on :3009
yarn dev:payments           # Payments (workspace dev)
yarn build                  # Build Photos (alias)
yarn build:<app>            # Build specific app
yarn lint                   # Format + lint + typecheck
yarn lint-fix               # Auto-fix lint issues
```

### Mobile (`mobile/`)

```bash
melos bootstrap             # Link all local packages
flutter run -t lib/main.dart --flavor independent   # Run Photos
dart format .               # Format Dart code
flutter analyze             # Static analysis (must pass before commit)
```

### Server (`server/`)

```bash
docker compose up --build   # Local dev cluster (Museum + Postgres + MinIO)
go build -o bin/museum ./cmd/museum   # Build server binary
```

### Desktop (`desktop/`)

```bash
yarn install
yarn build-renderer         # Build Next.js Photos app
yarn build-main             # Compile TS + electron-builder
```

### CLI (`cli/`)

```bash
go build -o bin/ente main.go   # Build CLI binary
```

### Docs (`docs/`)

```bash
yarn install
yarn dev                    # Dev server on :5173
yarn build                  # Production build
yarn pretty                 # Format with Prettier
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

| Table                    | Purpose                                    |
| ------------------------ | ------------------------------------------ |
| `users`                  | User accounts                              |
| `files`                  | Encrypted photo/file metadata              |
| `collections`            | Albums/folders                             |
| `collection_shares`      | E2EE sharing between users                 |
| `key_attributes`         | Encrypted key material (KEK params, etc.)  |
| `tokens`                 | Session tokens                             |
| `otts`                   | One-time tokens (email OTP)                |
| `memory_shares`          | Public memory share metadata (E2EE keys, access tokens, 7-day TTL) |
| `memory_share_files`     | Files within a memory share (position, per-file encrypted keys) |

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
cd server && docker compose up --build

# Terminal 2: Web
cd web && yarn install && yarn dev

# Mobile: point to local server via developer settings
```

---

## Critical Gotchas

1. **No unified monorepo tool** — each component manages its own deps (Yarn, Melos, Go modules, Cargo). There is no `turbo`, `nx`, or `lerna`.
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
- Security vulnerabilities: email security@ente.com
- Architecture docs: `architecture/README.md`
- Crypto implementation: `rust/core/docs/crypto.md`

---

## External Resources

- **Product site:** https://ente.com
- **Documentation:** https://ente.com/help
- **GitHub:** https://github.com/ente-io/ente
- **Discord:** https://ente.com/discord
- **Discussions:** https://github.com/ente-io/ente/discussions
