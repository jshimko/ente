# CLAUDE.md

Reference guide for the Ente web monorepo (`web/`). For root-level context see `../CLAUDE.md`.

**Purpose:** 13 web applications and 9 shared packages for Ente's E2EE cloud platform — Photos, Auth, Locker, and more.

**Documented:** 2026-04-04
**Commit:** 0618f522ee

---

## Commands

```bash
# Install dependencies from the committed lockfile (uses Yarn classic 1.22.22)
yarn install --frozen-lockfile

# Development servers
yarn dev                # Photos on :3000 (alias)
yarn dev:photos         # Photos on :3000
yarn dev:accounts       # Accounts on :3001
yarn dev:albums         # Shared albums on :3002
yarn dev:auth           # Auth on :3003
yarn dev:cast           # Cast on :3004
yarn dev:share          # Share/Locker on :3005
yarn dev:embed          # Embed on :3006
yarn dev:ensu           # Ensu (AI chat) on :3007
yarn dev:paste          # Paste on :3008
yarn dev:locker         # Locker on :3009
yarn dev:twoof3         # TwoOf3 on :3009
yarn dev:memories       # Memories on :3010
yarn dev:payments       # Payments (Vite, port 3001)

# Production builds (Turbo handles WASM and dependency ordering automatically)
yarn build              # Build all apps (via turbo build)
yarn build:<app>        # Build specific app (via turbo build --filter=<app>)

# Code quality — ONLY run when explicitly requested or before commits
yarn lint               # turbo (eslint + tsc) then prettier --check
yarn lint-fix           # turbo (eslint + tsc) then prettier --write

# Tests (WASM package only)
yarn test               # Vitest — crypto, auth, URL tests
yarn test:run           # Run tests (non-watch mode)
```

Use plain `yarn install` only when intentionally updating dependencies and
reviewing the resulting `yarn.lock` changes.

## Architecture

## Apps

| App        | Port | Framework | Purpose                                               |
| ---------- | ---- | --------- | ----------------------------------------------------- |
| `photos`   | 3000 | Next.js   | Main photo management, gallery, shared albums         |
| `accounts` | 3001 | Next.js   | Passkey management                                    |
| `albums`   | 3002 | Next.js   | Public albums for shared album and file links          |
| `auth`     | 3003 | Next.js   | 2FA code manager (TOTP)                               |
| `cast`     | 3004 | Next.js   | Chromecast/browser photo casting                      |
| `share`    | 3005 | Next.js   | Public file sharing (static export)                   |
| `embed`    | 3006 | Next.js   | Embeddable photo viewer (iframe)                      |
| `ensu`     | 3007 | Next.js   | AI chat interface (Wllama LLM, Tauri desktop)         |
| `paste`    | 3008 | Next.js   | Clipboard/paste sharing with QR codes (static export) |
| `locker`   | 3009 | Next.js   | Document storage (uses accounts-rs, multi-locale)     |
| `twoof3`   | 3009 | Next.js   | 2FA QR code generator                                 |
| `memories` | 3010 | Next.js   | Photo memories/highlights viewer (static export)      |
| `payments` | 3001 | **Vite**  | Stripe subscription management (**not** Next.js)      |

- All Next.js apps use `output: "export"` (static HTML — no SSR).
- Apps with `build:post` scripts (memories, paste, share) remove `404.html` for static deployment.

### App directory structure

```sh
web/
├── apps/              # Individual applications
│   ├── photos/        # Main photo management app
│   ├── albums/        # Public albums for shared album and file links
│   ├── accounts/      # Passkey support
│   ├── auth/          # 2FA authentication app
│   ├── cast/          # Chromecast/browser casting
│   ├── embed/         # Embeddable photo viewer (iframe-friendly)
│   ├── ensu/          # AI chat interface (Wllama LLM)
│   ├── locker/        # Document storage (uses accounts-rs)
│   ├── memories/      # Photo memories/highlights viewer
│   ├── paste/         # Clipboard/paste sharing with QR codes
│   ├── payments/      # Subscription management (Vite)
│   ├── share/         # Public file sharing
│   └── twoof3/        # 2FA QR code generator
│
├── packages/          # Shared code between apps
│   ├── base/          # Core UI components, crypto, i18n
│   ├── gallery/       # Photo gallery components
│   ├── accounts/      # Account management
│   ├── media/         # Media processing (FFmpeg, image conversion)
│   ├── utils/         # General utilities
│   ├── new/           # A temporary place for code shared by photos and albums
│   └── build-config/  # Shared build configuration
│
└── docs/          # Development documentation
```

---

## Packages

| Package                            | Type      | Purpose                                                                      |
| ---------------------------------- | --------- | ---------------------------------------------------------------------------- |
| `base` (ente-base)                 | React/TS  | Core: UI components, crypto, HTTP client, i18n, theming, Next.js config      |
| `utils` (ente-utils)               | Pure TS   | Framework-agnostic utilities (arrays, promises, type guards) — zero deps     |
| `gallery` (ente-gallery)           | React/TS  | Photo gallery: viewer (PhotoSwipe), upload, download, FFmpeg, maps (Leaflet) |
| `media` (ente-media)               | TS        | Media types, metadata, HEIC conversion, live photos                          |
| `new` (ente-new)                   | React/TS  | **Temporary** — shared photos/albums code (will be split later)              |
| `accounts` (ente-accounts)         | React/TS  | Auth UI + SRP login (JS-based crypto via libsodium)                          |
| `accounts-rs` (ente-accounts-rs)   | React/TS  | Auth UI + SRP login (Rust WASM crypto — newer, used by locker)               |
| `wasm` (ente-wasm)                 | Rust→WASM | Rust core crypto/auth compiled to WebAssembly via wasm-pack                  |
| `build-config` (ente-build-config) | Config    | Shared tsconfig, eslint, prettier configs                                    |

### Package dependency layers

```
ente-utils          (no deps — pure TS utilities)
    ↑
ente-base           (React, MUI, libsodium, i18n, HTTP)
    ↑
ente-media          (file types, metadata, HEIC)
    ↑
ente-gallery        (PhotoSwipe, FFmpeg, upload/download)
    ↑
ente-new            (photos + albums app logic)

ente-wasm           (Rust core → WASM, independent)
    ↑
ente-accounts-rs    (WASM-based auth, newer)

ente-accounts       (JS-based auth, older — uses libsodium directly)
```

### Key modules in `packages/base/`

| Module                      | Purpose                                                                       |
| --------------------------- | ----------------------------------------------------------------------------- |
| `http.ts`                   | Custom fetch wrapper with retry, `authenticatedRequestHeaders()`, `HTTPError` |
| `crypto/index.ts`           | High-level crypto API (delegates to `crypto/libsodium.ts` or worker)          |
| `crypto/libsodium.ts`       | libsodium-wrappers-sumo bindings                                              |
| `session.ts`                | Master key session management                                                 |
| `token.ts`                  | Auth token storage (IndexedDB)                                                |
| `origins.ts`                | API endpoint URLs (`apiOrigin()`, `uploaderOrigin()`, `albumsAppOrigin()`)    |
| `app.ts`                    | App name detection, `isDesktop` flag                                          |
| `i18n.ts`                   | i18next setup (49 locale directories, 20 supported)                           |
| `kv.ts`                     | Key-value storage abstraction                                                 |
| `context.ts`                | `BaseContext` — logout, dialog, error handling                                |
| `next.config.base.js`       | Shared Next.js config (static export, WASM, Emotion, env vars)                |
| `components/`               | ~30 shared MUI components (EnteLogo, MiniDialog, RowButton, etc.)             |
| `components/utils/theme.ts` | MUI theme with light/dark schemes, CSS variables                              |

---

## Import Conventions

```typescript
// Internal packages — use ente-* prefix (resolved via Yarn workspaces)
import { authenticatedRequestHeaders } from "ente-base/http";
import { encryptBox, decryptBox } from "ente-base/crypto";
import { assertNever } from "ente-utils/type-guards";
import { FileType } from "ente-media/file-type";

// App-local imports — relative to src/ (baseUrl in tsconfig)
import { GalleryPage } from "components/GalleryPage";
import { uploadService } from "services/upload";
```

No custom path aliases — relies on `baseUrl: "./src"` and Yarn workspace resolution.

---

## Architecture Patterns

### State management

- **React Context** — `BaseContext` (ente-base), `PhotosAppContext` (ente-new)
- **No Redux/Zustand** — hooks + context for all state
- **Persistence**: IndexedDB (auth tokens via `token.ts`), localStorage (settings via `kv.ts`)

### API communication

- Custom `fetch()` wrapper in `packages/base/http.ts`
- Retry with exponential backoff (`retryAsyncOperation()`)
- Auth via `X-Auth-Token` and `X-Client-Package` headers
- Default API: `https://api.ente.io` (configurable via `NEXT_PUBLIC_ENTE_ENDPOINT`)

### Crypto (E2EE)

Three layers:

1. `packages/base/crypto/index.ts` — high-level API
2. `packages/base/crypto/libsodium.ts` — JS implementation
3. `packages/wasm/src/crypto.rs` — Rust WASM alternative

Crypto runs in Web Workers to avoid blocking the main thread.

### Styling

- **MUI 7** with Emotion CSS-in-JS
- Theme in `packages/base/components/utils/theme.ts`
- `styled()` and `sx` prop for component styling
- CSS variables via `cssVariables: { colorSchemeSelector: "class" }`

---

## Environment Variables

| Variable                             | Default                    | Purpose            |
| ------------------------------------ | -------------------------- | ------------------ |
| `NEXT_PUBLIC_ENTE_ENDPOINT`          | `https://api.ente.io`      | Museum API server  |
| `NEXT_PUBLIC_ENTE_ALBUMS_ENDPOINT`   | `https://albums.ente.io`   | Shared albums host |
| `NEXT_PUBLIC_ENTE_PHOTOS_ENDPOINT`   | `https://web.ente.io`      | Photos app URL     |
| `NEXT_PUBLIC_ENTE_SHARE_ENDPOINT`    | `https://share.ente.io`    | Locker/share app   |
| `NEXT_PUBLIC_ENTE_MEMORIES_ENDPOINT` | `https://memories.ente.io` | Memories app       |
| `NEXT_PUBLIC_ENTE_OFFICIAL_ALBUMS_APP` | _(unset)_                  | Flag for official albums deployment |

Build-injected (via `next.config.base.js`): `gitSHA`, `appName`, `isDesktop`, `desktopAppVersion`.

---

## Build System

- **Yarn 1.22.22** workspaces: `apps/*` + `packages/*`
- **Turborepo** (`turbo.json`) manages task dependencies, ordering, and caching across all workspaces
- **WASM builds automatically** — Turbo's `dependsOn: ["^build"]` ensures WASM builds before dependent apps
- **WASM build**: `wasm-pack build --target bundler` → outputs `packages/wasm/pkg/`
- **Next.js base config**: `packages/base/next.config.base.js` — static export, Emotion, WASM support
- **Lint**: `turbo lint tsc` runs eslint and tsc across workspaces (cached), then `prettier --check` runs separately
- **Prettier**: tabWidth 4, organize-imports plugin, packagejson plugin
- **TypeScript**: strict mode, ES2020 target, bundler module resolution
- **Transpiled packages**: `ente-base`, `ente-utils`, `ente-new`, `ente-wasm`

---

## Common Tasks

### Add a new web app

1. Create `apps/<name>/` with `src/pages/_app.tsx`, `next.config.js`, `tsconfig.json`, `eslint.config.mjs`
2. `next.config.js` should import from `ente-base/next.config.base.js`
3. Add `dev:<name>` and `build:<name>` scripts to root `package.json`

### Add a new shared package

1. Create `packages/<name>/` with `package.json` (name: `ente-<name>`)
2. Add tsconfig extending `ente-build-config/tsconfig-next.json` or `tsconfig-typecheck.json`
3. Consuming apps import via `ente-<name>/module`
4. If needed in browser, add to `transpilePackages` in `next.config.base.js`

### Point to a local Museum server

Set `NEXT_PUBLIC_ENTE_ENDPOINT=http://localhost:8080` in the app's `.env.local`

### Build WASM after Rust changes

```bash
yarn build:wasm    # Rebuilds packages/wasm/pkg/ from Rust source
```

---

## Gotchas

1. **WASM must build first** — Turbo handles this automatically via `dependsOn: ["^build"]` in `turbo.json`
2. **payments uses Vite, not Next.js** — different build system, no `next.config.js`
3. **accounts vs accounts-rs** — two auth implementations; `accounts-rs` (Rust WASM) is newer, used by locker; `accounts` (JS libsodium) is used by most other apps
4. **tabWidth 4** — Prettier is configured for 4-space indentation
5. **Static exports only** — all Next.js apps use `output: "export"`, no server-side rendering
6. **Legacy env vars fail the build** — `NEXT_PUBLIC_ENTE_ACCOUNTS_URL` and `NEXT_PUBLIC_ENTE_FAMILY_URL` cause build failures with instructions to use museum config instead
7. **Lint is two-phase** — `yarn lint` first runs `turbo lint tsc` (eslint + typecheck across workspaces, cached), then runs `prettier --check` separately
8. **ente-new is temporary** — shared photos/albums code that will eventually be split into separate concerns
