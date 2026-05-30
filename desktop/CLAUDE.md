# CLAUDE.md — Desktop

Development guide for the **Ente desktop client** (`desktop/`). For monorepo-wide context see the root `CLAUDE.md`; for the renderer UI see `web/CLAUDE.md`.

**Documented:** 2026-05-28
**Commit:** 8185f4a781

---

## Purpose

`desktop/` is an **Electron wrapper** that ships the `web/apps/photos` Next.js app as a native desktop application (macOS, Windows, Linux). The web app is the UI (renderer); the desktop layer's job is the **main process** — the native capabilities a browser can't provide.

What desktop adds on top of the web app:

- **Continuous backup** — watch folders on disk and auto-upload (chokidar)
- **On-device ML** — face detection + CLIP search via native ONNX Runtime (much faster than the web WASM build)
- **Video processing** — bundled FFmpeg (conversion, HLS, duration)
- **Native OS integration** — file dialogs, system tray, app menu, dock, Touch ID, OS keychain, auto-launch, auto-update
- **Large-file streaming** — move multi-GB files between disk and renderer without buffering in memory

## Domain Context

End-to-end encrypted photo storage. The desktop app is one of several clients (web, mobile, CLI) talking to the same Museum server. All encryption happens in the **renderer** (the web app's crypto). The main process handles plaintext file bytes on the local disk only — it never sees server credentials beyond what it stores in the OS keychain on the renderer's behalf.

## Dependencies

- **Internal**: At build time, builds and embeds `web/apps/photos` (the renderer). Shares the IPC type contract with `web/packages/base/types/ipc.ts`.
- **External**: `electron`, `electron-builder`, `electron-updater`, `electron-store`, `electron-log`, `ffmpeg-static`, `onnxruntime-node`, `chokidar`, `next-electron-server`, `comlink`, `node-stream-zip`, `zod`. Native `vips` binary (Linux/Windows) downloaded at install/build time.

## Dependents

None in-repo — this is a leaf application. Released independently via the `ente-io/photos-desktop` repo.

---

## ⚠️ Critical Constraints

1. **The three-file IPC contract must change in lockstep.** Adding or changing any native function exposed to the renderer means editing all three files in sync — there is no codegen. See the `[Note: types.ts <-> preload.ts <-> ipc.ts]` marker in `src/preload.ts:28`. The three files:
    - `web/packages/base/types/ipc.ts` — the typed `Electron` interface + docs (renderer side)
    - `desktop/src/preload.ts` — the bridge stub that calls `ipcRenderer`
    - `desktop/src/main/ipc.ts` — the `ipcMain` handler that dispatches to a service

2. **`src/preload.ts` cannot import from `src/`.** The sandbox disables Node integration in the preload, so it must be a single self-contained file. **Types-only** imports (e.g. `import type { ... } from "./types/ipc"`) are fine (erased at compile time); value imports from local modules are not. See `src/preload.ts:12-37,63-76`.

3. **`npm run lint` must pass before any commit** — it runs prettier (check) + ESLint (strict type-checked) + `tsc`. The `tsconfig.json` is aggressively strict: `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noUnusedLocals`, `noUnusedParameters`, `noImplicitReturns`, `noFallthroughCasesInSwitch`. Note `verbatimModuleSyntax` is intentionally **off** (ESM/CJS friction under Node). Non-null assertions (`!`) are intentionally **allowed** (ESLint override) — see the `[Note: non-null-assertions have better stack trace]` comment in `eslint.config.mjs`.

4. **Do not bump `electron-builder` off `26.0.14`.** Pinned due to a cross-arch macOS FFmpeg packaging break (upstream issue #9161). Verify a clean universal-mac build before changing it.

5. **The `vips` download URL is duplicated in two scripts.** `scripts/vips.js` (the `prepare`/postinstall path) and `scripts/beforeBuild.js` (the electron-builder per-arch hook) both fetch the architecture-specific binary from `github.com/ente-io/libvips-packaging`. Update **both** when upgrading vips. macOS uses native `sips` instead and needs no vips.

6. **The renderer is not served over HTTP.** It is served from the custom origin `ente://app` via `next-electron-server` (`src/main.ts:49,213`). CORS, deeplink, and origin-handling logic in `main.ts` assumes this scheme — don't switch it to `file://` or `http://`.

7. **Don't edit `app/` or `out/`** — both are git-ignored build output. `app/` is `tsc` output (the compiled main process); `out/` is the copied web build.

---

## Architecture Overview

Three (sometimes five) processes:

```
┌─────────────────────────────────────────────────────────────┐
│ Main process  (Node.js)   src/main.ts → app/main.js          │
│   • BrowserWindow lifecycle, tray, menu, dock, deeplinks      │
│   • Protocols: ente:// (serves renderer), stream:// (files)   │
│   • ipcMain handlers (src/main/ipc.ts) → services/*           │
└───────────────┬──────────────────────────┬───────────────────┘
                │ contextBridge             │ utilityProcess.fork
                │ (src/preload.ts)          │ + MessageChannelMain
                ▼                           ▼
┌──────────────────────────┐   ┌───────────────────────────────┐
│ Renderer (Chromium)      │   │ Utility processes (Node.js)    │
│   bundled web/apps/photos│◄──┤   ml-worker.ts  (ONNX)         │
│   served at ente://app   │   │   ffmpeg-worker.ts (FFmpeg)    │
│   window.electron API    │   │   comlink RPC over a MsgPort   │
└──────────────────────────┘   └───────────────────────────────┘
```

- **Main** (`src/main.ts`, compiled to `app/main.js`, referenced by `package.json` `"main"`): window lifecycle, registers the `ente://` and `stream://` protocols, tray/menu/dock, deeplink handling, CORS allowances.
- **Renderer**: the bundled Next.js export of `web/apps/photos`. In **dev** it's proxied to the Next dev server on `:3008` (HMR); in **prod** it's served from the copied `out/`. Reaches native functions only through `window.electron`, injected by the preload via `contextBridge.exposeInMainWorld("electron", …)` (`src/preload.ts:392`).
- **Preload** (`src/preload.ts`): isolated, single-file bridge. Defines the stub functions, then exposes them on `window.electron`.
- **Utility processes** (`src/main/services/ml-worker.ts`, `ffmpeg-worker.ts`): forked Node processes for CPU-heavy work. The renderer talks to them **directly** over a `MessageChannelMain` port (comlink RPC), so a 100–300ms inference doesn't stall the main process / UI. Lifecycle (fork, port wiring, terminate-on-logout) lives in `src/main/services/workers.ts`.

### Source layout

| Path                               | Contents                                                       |
| ---------------------------------- | -------------------------------------------------------------- |
| `src/main.ts`                      | Main process entry — window, protocols, tray, menu, lifecycle  |
| `src/preload.ts`                   | The IPC bridge (single file; `window.electron`)                |
| `src/types/ipc.ts`                 | Shared IPC types (kept in sync with the web copy)              |
| `src/main/ipc.ts`                  | `ipcMain.handle`/`.on` registration → dispatch to services     |
| `src/main/log.ts`, `log-worker.ts` | electron-log setup (main + utility processes)                  |
| `src/main/menu.ts`                 | Application menu (platform-specific)                           |
| `src/main/stream.ts`               | `stream://` protocol handler (large-file read/write/zip/video) |
| `src/main/services/`               | Feature implementations (one file per capability)              |
| `src/main/stores/`                 | electron-store persistence (user prefs, watches, safe storage) |
| `src/main/utils/`                  | Helpers (comlink port adapter, http, temp files, exec, paths)  |
| `src/main/types/`                  | Main-process-only types                                        |

Key services: `watch.ts` (folder watching), `ffmpeg.ts`/`ffmpeg-worker.ts`, `ml-worker.ts`/`workers.ts`, `app-update.ts`, `store.ts`/`safe-storage` (keychain), `dir.ts` (dialogs), `device-lock.ts` (Touch ID), `auto-launcher.ts`, `fs.ts`, `image.ts` (sips/vips), `upload.ts`, `zip.ts`, `logout.ts`.

---

## Established Pattern: Add an IPC method end-to-end

Use `invoke`/`handle` (two-way) so errors propagate to the renderer. Real example — `promptDeviceLock(reason)`:

1. **Type** — add the signature to the `Electron` interface in `web/packages/base/types/ipc.ts` (and mirror in `desktop/src/types/ipc.ts` if a shared type is involved).
2. **Bridge** — in `src/preload.ts`, add a stub and include it in the `exposeInMainWorld` object:
    ```ts
    const promptDeviceLock = (reason: string): Promise<boolean> =>
        ipcRenderer.invoke("promptDeviceLock", reason);
    // ... later, inside contextBridge.exposeInMainWorld("electron", { … promptDeviceLock … })
    ```
3. **Handler** — register it in `src/main/ipc.ts`:
    ```ts
    ipcMain.handle("promptDeviceLock", (_, reason: string) =>
        promptDeviceLock(reason),
    );
    ```
4. **Implementation** — write the logic in a `src/main/services/*.ts` (here `device-lock.ts`) and import it into `ipc.ts`.

Variants:

- **`send`/`on`** (fire-and-forget, one-way) for cases where exceptions needn't be caught (e.g. `logToDisk`, `updateAndRestart`). Renderer→main and main→renderer events both use this (e.g. `watchAddFile` events emitted to the renderer).
- **`stream://` protocol** for large files — never pass file bytes through `invoke`. See `src/main/stream.ts` (`read`, `read-zip`, `write`, `video`).

---

## Development Workflow

All commands run from `desktop/` with **npm** (`packageManager: npm@11.12.1`). Root `Taskfile.yml` equivalents in parentheses.

```bash
npm ci                           # runs postinstall (rebuild native modules) + prepare (vips)
npm run dev                      # (task desktop:dev) main + renderer concurrently; renderer HMR on :3008
npm run dev-main                 # tsc + electron . (main only)
npm run dev-renderer             # Next dev server for photos on :3008 (renderer only)
npm run lint                     # (task desktop:lint) prettier --check + eslint + tsc — MUST pass
npm run lint:fix                 # auto-fix prettier/eslint, then tsc
npm run build                    # (task desktop:build) build-renderer + build-main (full, signed)
npm run build:quick              # build-renderer + unsigned --dir build (fast local iteration)
npm run build:ci                 # build-renderer + tsc (no packaging)
```

- `postinstall` → `electron-builder install-app-deps` rebuilds C/C++ native modules (FFmpeg, ONNX, vips) against Electron's bundled Node — **required** after dependency changes.
- `prepare` → `node scripts/vips.js` downloads the vips binary for the current OS/arch.
- **Testing**: there is **no test framework** in `desktop/`. Verification = `npm run lint` (prettier + eslint + tsc) + manual testing of the running app. ML-parity checks live under `scripts/`.

### Build & renderer embedding

`build-renderer` runs the web Photos build and copies its static export into `desktop/out`:

```sh
cd ../web && yarn install --frozen-lockfile && yarn build:photos
cp -r ../web/apps/photos/out ../desktop/out   # (shx, cross-platform)
```

`_ENTE_IS_DESKTOP=1` is set so the web build produces the desktop variant.

---

## Native Integrations

| Capability                 | Tech / package                                                       | File(s)                                              |
| -------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------- |
| Folder watching            | `chokidar` v4 (macOS uses polling to dodge EMFILE)                   | `services/watch.ts`                                  |
| Video                      | `ffmpeg-static` in a utility process                                 | `services/ffmpeg.ts`, `ffmpeg-worker.ts`             |
| ML (faces, CLIP)           | `onnxruntime-node` in a utility process; models downloaded on demand | `services/ml-worker.ts`, `workers.ts`                |
| Auto-update                | `electron-updater` → GitHub releases on `ente-io/photos-desktop`     | `services/app-update.ts`                             |
| Secret storage             | Electron `safeStorage` → OS keychain                                 | `services/store.ts`, `stores/safe-storage.ts`        |
| File dialogs / open in OS  | Electron `dialog`, `shell`                                           | `services/dir.ts`                                    |
| Device lock                | Touch ID via `systemPreferences.promptTouchID` (macOS only)          | `services/device-lock.ts`                            |
| Auto-launch on login       | `auto-launch`                                                        | `services/auto-launcher.ts`                          |
| Tray / menu / dock         | Electron `Tray`, `Menu`                                              | `src/main.ts`, `src/main/menu.ts`                    |
| Image thumbnails / convert | `sips` (macOS) or `vips` (Linux/Win)                                 | `services/image.ts`                                  |
| Large-file & zip streaming | custom `stream://` protocol                                          | `src/main/stream.ts`, `services/zip.ts`, `upload.ts` |

---

## Build, Signing & Release

Packaging config: `electron-builder.yml`. `appId: io.ente.bhari-frame`, custom `ente` deeplink protocol.

- **macOS** — universal DMG (x64 + arm64), `hardenedRuntime: true`, notarized, `build/entitlements.mac.plist` (allows JIT / unsigned executable memory / dyld env — needed by Node/FFmpeg). `mergeASARs: false`.
- **Windows** — NSIS installer (x64, arm64), Azure code signing (`ENTE TECHNOLOGIES, INC.`).
- **Linux** — AppImage, deb, rpm, pacman (x64, arm64).
- `beforeBuild: scripts/beforeBuild.js` downloads the per-arch vips binary; `extraFiles` ships `build/` into `resources/`.

**Releases are managed from a separate repo**, `ente-io/photos-desktop` (electron-updater's auto-update feed doesn't work from a monorepo). The desktop **version is independent of the web app** (web is `0.0.0`; the renderer is embedded at build time). Tag commits as `photosd-v1.x.x`. Full checklist (CHANGELOG, WhatsNew, trigger script, nightly betas) in `docs/release.md`.

---

## Conventions

- **Formatting**: Prettier, 4-space indent, with `prettier-plugin-organize-imports` (imports auto-sorted) and `prettier-plugin-packagejson`. Config in `.prettierrc.json`.
- **Imports**: relative paths only — **no path aliases** in the main process.
- **Docs**: files lead with a JSDoc `@file` block; design rationale captured in `[Note: …]` comment markers (searchable across the repo). Read these before changing the code they annotate.
- **Paths**: normalize to POSIX (`/`) via `utils/electron.ts` `posixPath()` — the renderer and stored paths assume forward slashes even on Windows.

---

## Gotchas & Tribal Knowledge

- **Closing the window hides it, it does not quit.** This keeps long-running work (exports, folder watches) alive. Real quit is gated by the `shouldAllowWindowClose` flag in `src/main.ts`. Folder watches are tied to the window's lifetime.
- **Deeplinks differ by platform.** macOS delivers them via `app.on("open-url")`; Windows/Linux via `app.on("second-instance")` by scanning `argv` for an `ente://` arg (Chromium can reorder args, so search — don't index).
- **Dev needs a startup delay.** The main process waits for the Next dev server on `:3008` before `loadURL`, otherwise Electron errors with `ERR_CONNECTION_REFUSED`.
- **Auto-update can't be exercised in dev.** It requires signed builds; dev builds skip the check. Testing needs a throwaway release repo or `dev-app-update.yml`.
- **CORS is deliberately widened.** `main.ts` allows external links to open in the browser and permits cross-origin requests (e.g. OpenStreetMap map tiles) from the `ente://app` origin. Touch these helpers carefully.
- **Native modules must match Electron's Node.** If FFmpeg/ONNX/vips misbehave after a dependency change, re-run `npm ci` (triggers `electron-builder install-app-deps`).
- **Auto-launched startup hides the dock** on macOS (`app.dock?.hide()`), so a login-triggered launch isn't intrusive.
- **`ReadableStream` typing clash** — the preload references `lib="dom"`, which conflicts with Node's stream types (`[Note: Node and web stream type mismatch]` in `preload.ts`). Be deliberate with stream typings there.

---

## HOW TO

- **Add a native function the renderer can call** → follow _Add an IPC method end-to-end_ above (all three files).
- **Add a new native capability** → create `src/main/services/<name>.ts`, wire it through `ipc.ts` + `preload.ts` + the web types; persist any state via a `src/main/stores/` electron-store module.
- **Add a menu or tray item** → `src/main/menu.ts` / the tray setup in `src/main.ts`; gate macOS-only items on `process.platform === "darwin"`.
- **Bump Electron** → update `electron`, re-run `npm ci`, verify `npm run lint` and a universal-mac `npm run build:quick`. Do **not** bump `electron-builder` past `26.0.14` without a full mac build check.
- **Cut a release** → follow `docs/release.md` (separate `ente-io/photos-desktop` repo, `photosd-v1.x.x` tag).

## External Docs

- `desktop/docs/dev.md` — npm commands
- `desktop/docs/dependencies.md` — native dependency rationale
- `desktop/docs/release.md` — full release process
- `desktop/README.md` — quick start
- Root `CLAUDE.md`, `web/CLAUDE.md` — monorepo + renderer context
