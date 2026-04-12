# Taskfile Guide

Unified task runner for the Ente monorepo. All commands run from the repo root.

**Requires:** [Task](https://taskfile.dev/installation/) v3+

```bash
# macOS
brew install go-task

# or via go
go install github.com/go-task/task/v3/cmd/task@latest
```

## Quick Reference

```bash
task                # List all available tasks
task install        # Install deps for all components
task build          # Build everything
task lint           # Lint everything
task test           # Run all tests
task format         # Format all code
task clean          # Clean all build artifacts
```

## Web (Photos, Auth, Locker, and 10 more apps)

**Prerequisites:** Node.js, Yarn 1.22+

Web tasks accept an app name after `--`. Defaults to `photos` if omitted.

Available apps: `photos`, `accounts`, `albums`, `auth`, `cast`, `share`, `embed`, `ensu`, `paste`, `locker`, `twoof3`, `memories`, `payments`

```bash
# Development
task web:dev                # Start Photos dev server on :3000
task web:dev -- auth        # Start Auth dev server on :3003
task web:dev -- locker      # Start Locker dev server on :3009

# Building
task web:build              # Build Photos
task web:build -- auth      # Build Auth
task web:build-wasm         # Build Rust WASM package (prerequisite for most apps)

# Code quality
task web:lint               # Run prettier + eslint + tsc
task web:lint-fix           # Auto-fix lint issues
task web:test               # Run WASM package tests

# Cleanup
task web:clean              # Remove node_modules and build outputs
```

**Caching:** `web:install` skips if `yarn.lock` hasn't changed and `node_modules` exists. `web:build` and `web:lint` skip if source files haven't changed.

## Server (Museum API)

**Prerequisites:** Go 1.23+, Docker

```bash
# Docker Compose (recommended for development)
task server:up              # Start Museum + Postgres + MinIO (foreground)
task server:up-d            # Start in background
task server:down            # Stop the stack
task server:logs            # Tail container logs
task server:db              # Open psql shell to dev database

# Native development
task server:build           # Build the museum binary
task server:dev             # Start with hot reload (requires air)

# Code quality
task server:lint            # Run go vet + staticcheck
task server:test            # Run Go tests

# Cleanup
task server:clean           # Remove build artifacts
```

**Caching:** `server:build` and `server:lint` skip if Go source files haven't changed.

## Mobile (Photos, Auth, Locker — Flutter)

**Prerequisites:** [fvm](https://fvm.app), Melos

Mobile tasks accept an app name after `--`. Defaults to `photos` if omitted.

```bash
# Setup
task mobile:bootstrap       # Link packages and run flutter pub get

# Development
task mobile:run             # Run Photos on connected device
task mobile:run -- auth     # Run Auth
task mobile:run -- locker   # Run Locker

# Building
task mobile:build           # Build Photos APK
task mobile:build -- auth   # Build Auth APK

# Android sideloading (self-hosting)
task mobile:apk             # Build release APK (independent flavor, arm64)
task mobile:apk -- https://your-server.example.com  # Bake in a custom server endpoint
task mobile:sideload        # Install built APK on connected device via ADB

# Code quality
task mobile:lint            # Run flutter analyze
task mobile:format          # Format all Dart code

# Code generation
task mobile:codegen         # Regenerate flutter_rust_bridge bindings
task mobile:submodules      # Initialize git submodules (one-time)

# Cleanup
task mobile:clean           # flutter clean in all projects
```

**Caching:** `mobile:bootstrap` skips if lock files haven't changed and `.dart_tool` exists. `mobile:lint` skips if Dart source files haven't changed. `mobile:submodules` skips if all submodules are already initialized.

## Desktop (Electron)

**Prerequisites:** Node.js, Yarn 1.22+

```bash
task desktop:dev            # Start Electron + Next.js dev
task desktop:build          # Full build (renderer + electron-builder)
task desktop:lint           # Run prettier + eslint + tsc
task desktop:clean          # Remove node_modules and build outputs
```

**Caching:** `desktop:install` skips if `yarn.lock` hasn't changed. `desktop:build` and `desktop:lint` skip if source files haven't changed.

## CLI

**Prerequisites:** Go 1.23+

```bash
task cli:build              # Build the ente CLI binary
task cli:clean              # Remove build artifacts
```

**Caching:** `cli:build` skips if Go source files haven't changed.

## Docs

**Prerequisites:** Node.js, Yarn 1.22+

```bash
task docs:dev               # Start VitePress dev server
task docs:build             # Production build
task docs:format            # Format with Prettier
task docs:format-check      # Check formatting (no write)
task docs:clean             # Remove node_modules and build outputs
```

**Caching:** `docs:install` skips if `yarn.lock` hasn't changed. `docs:build` and `docs:format-check` skip if source files haven't changed.

## Rust (Core crypto, CLI, media inspector)

**Prerequisites:** Rust/Cargo

```bash
task rust:build             # Debug build (core, cli, photos crates)
task rust:build-release     # Release build
task rust:test              # Run all tests
task rust:lint              # Run clippy with -D warnings
task rust:fmt               # Format all Rust code
task rust:fmt-check         # Check formatting (no write)
task rust:clean             # cargo clean in all crates
```

**Caching:** `rust:build`, `rust:lint`, and `rust:fmt-check` skip if Rust source files haven't changed.

## Common Workflows

### First time setup

```bash
task install                # Install deps for web, desktop, docs, and mobile
```

### Working on the web Photos app

```bash
task server:up-d            # Start API server in background
task web:dev                # Start Photos dev on :3000
# ... make changes ...
task web:lint               # Check before committing
```

### Working on Auth (web)

```bash
task server:up-d
task web:dev -- auth        # Auth on :3003
```

### Working on the server

```bash
task server:up              # Start full stack (foreground, see logs)
# In another terminal:
task server:db              # Open psql shell
task server:test            # Run tests
task server:lint            # Lint before committing
```

### Working on mobile

```bash
task server:up-d            # Start API server
task mobile:run             # Run Photos on device
# ... make changes ...
task mobile:lint
task mobile:format
```

### Pre-commit check (all components)

```bash
task lint                   # Lint everything in parallel
task test                   # Run all tests
```

### Full rebuild from scratch

```bash
task clean                  # Remove all artifacts (uses clean.sh)
task install                # Reinstall all dependencies
task build                  # Build everything
```

## How Caching Works

Tasks with `sources` and `generates` directives use checksum-based caching. When you run a cached task, Taskfile computes checksums of the source files and compares them to the last successful run. If nothing changed, the task prints `Task "X" is up to date` and skips execution.

Checksums are stored in the `.task/` directory (gitignored). Delete it to force all tasks to re-run:

```bash
rm -rf .task
```

Install tasks (`web:install`, `desktop:install`, `docs:install`, `mobile:bootstrap`) also check whether the output directory (e.g., `node_modules`) exists. This means deleting `node_modules` will trigger a reinstall even if the lock file hasn't changed.

Tasks that always run regardless of caching: dev servers, Docker commands, tests, format/fix commands, and clean tasks.