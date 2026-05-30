#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# --- Flags ---
DRY_RUN=false
GIT_CLEAN=false
SKIP_CONFIRM=false

# --- Colors ---
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# --- Usage ---
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Remove all build artifacts, caches, and generated files from the Ente monorepo.
Resets the repo to a state identical to a fresh git clone.

Options:
  -n, --dry-run     Show what would be deleted without deleting anything
  -y, --yes         Skip the confirmation prompt
      --git-clean   Run git clean -fdx as a final pass (catches anything missed)
  -h, --help        Show this help message
EOF
    exit 0
}

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)   DRY_RUN=true; shift ;;
        -y|--yes)       SKIP_CONFIRM=true; shift ;;
        --git-clean)    GIT_CLEAN=true; shift ;;
        -h|--help)      usage ;;
        *)              echo "Unknown option: $1"; usage ;;
    esac
done

# --- Helpers ---

info() {
    echo -e "\n${BOLD}${GREEN}==> $1${NC}"
}

# Remove directories (rm -rf), skipping non-existent paths and git-tracked content
rm_dir() {
    for p in "$@"; do
        if [[ -e "$p" || -L "$p" ]]; then
            if [[ -d "$p" && -n "$(git -C "$REPO_ROOT" ls-files "$p" 2>/dev/null)" ]]; then
                continue
            fi
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${YELLOW}[dry-run]${NC} rm -rf $p"
            else
                rm -rf "$p"
                echo "  removed $p"
            fi
        fi
    done
}

# Remove files (rm -f), skipping non-existent paths and git-tracked files
rm_file() {
    for p in "$@"; do
        if [[ -e "$p" || -L "$p" ]]; then
            if git -C "$REPO_ROOT" ls-files --error-unmatch "$p" >/dev/null 2>&1; then
                continue
            fi
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${YELLOW}[dry-run]${NC} rm -f $p"
            else
                rm -f "$p"
                echo "  removed $p"
            fi
        fi
    done
}

# Find and remove directories by name under a base path
find_rm_dirs() {
    local base="$1" name="$2"
    [[ -d "$base" ]] || return 0
    find "$base" -type d -name "$name" -prune 2>/dev/null | while read -r d; do
        if [[ -n "$(git -C "$REPO_ROOT" ls-files "$d" 2>/dev/null)" ]]; then
            continue
        fi
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "  ${YELLOW}[dry-run]${NC} rm -rf $d"
        else
            rm -rf "$d"
            echo "  removed $d"
        fi
    done
}

# Find and remove files by name pattern under a base path
find_rm_files() {
    local base="$1" pattern="$2"
    [[ -d "$base" ]] || return 0
    find "$base" -type f -name "$pattern" 2>/dev/null | while read -r f; do
        if git -C "$REPO_ROOT" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
            continue
        fi
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "  ${YELLOW}[dry-run]${NC} rm -f $f"
        else
            rm -f "$f"
            echo "  removed $f"
        fi
    done
}

# --- Cleaning sections ---

clean_global() {
    info "Global patterns"

    # Directories (most impactful first)
    find_rm_dirs "$REPO_ROOT" "node_modules"
    find_rm_dirs "$REPO_ROOT" "target"
    find_rm_dirs "$REPO_ROOT" ".dart_tool"
    find_rm_dirs "$REPO_ROOT" ".gradle"
    find_rm_dirs "$REPO_ROOT" ".turbo"
    find_rm_dirs "$REPO_ROOT" ".build"
    find_rm_dirs "$REPO_ROOT" "xcuserdata"
    find_rm_dirs "$REPO_ROOT" "DerivedData"
    find_rm_dirs "$REPO_ROOT" "Pods"
    find_rm_dirs "$REPO_ROOT" "__pycache__"

    find_rm_dirs "$REPO_ROOT" ".cargo"

    # Files
    find_rm_files "$REPO_ROOT" ".DS_Store"
    find_rm_files "$REPO_ROOT" "*.tsbuildinfo"
    find_rm_files "$REPO_ROOT" "next-env.d.ts"
}

clean_web() {
    info "Web (web/)"
    local web="$REPO_ROOT/web"
    [[ -d "$web" ]] || return 0

    find_rm_dirs "$web" ".next"
    find_rm_dirs "$web" ".next-dev"
    find_rm_dirs "$web" ".next-desktop"

    # Remove out/ and dist/ from apps only (not from node_modules/target)
    for app_dir in "$web"/apps/*; do
        [[ -d "$app_dir" ]] || continue
        rm_dir "$app_dir/out" "$app_dir/dist" "$app_dir/.next" "$app_dir/.next-dev" "$app_dir/.next-desktop"
    done
    rm_dir "$web/apps/ensu/next"
    rm_dir "$web/packages/wasm/pkg"
    find_rm_files "$web" ".env*.local"
}

clean_desktop() {
    info "Desktop (desktop/)"
    local desk="$REPO_ROOT/desktop"
    [[ -d "$desk" ]] || return 0

    rm_dir "$desk/app"
    rm_dir "$desk/dist"
    rm_dir "$desk/out"
    rm_file "$desk/.env"
    find_rm_files "$desk" ".env.*.local"
    # Downloaded binaries in build/
    if [[ -d "$desk/build" ]]; then
        find_rm_files "$desk/build" "magick*"
        if [[ "$DRY_RUN" == true ]]; then
            find "$desk/build" -name "vips*" 2>/dev/null | while read -r f; do
                echo -e "  ${YELLOW}[dry-run]${NC} rm -rf $f"
            done
        else
            find "$desk/build" -name "vips*" -exec rm -rf {} + 2>/dev/null || true
        fi
    fi
}

clean_mobile() {
    info "Mobile (mobile/)"

    # APK that `task mobile:apk` copies to the repo root
    rm_file "$REPO_ROOT/app-independent-release.apk"

    local mob="$REPO_ROOT/mobile"
    [[ -d "$mob" ]] || return 0

    # Root-level Flutter artifacts
    rm_file "$mob/.flutter-plugins" "$mob/.flutter-plugins-dependencies" "$mob/.packages"
    rm_dir "$mob/.pub-cache" "$mob/.pub" "$mob/build"

    # Per app
    for app in photos auth locker; do
        local app_dir="$mob/apps/$app"
        [[ -d "$app_dir" ]] || continue

        rm_file "$app_dir/.flutter-plugins" "$app_dir/.flutter-plugins-dependencies" "$app_dir/.packages"
        rm_dir "$app_dir/.pub-cache" "$app_dir/.pub" "$app_dir/build" "$app_dir/.fvm"
        rm_file "$app_dir/.env"
        find_rm_files "$app_dir" "*.log"

        # Android
        rm_dir "$app_dir/android/.gradle" "$app_dir/android/app/build" "$app_dir/android/.kotlin"
        rm_file "$app_dir/android/local.properties"

        # iOS / macOS ephemeral
        rm_dir "$app_dir/ios/Flutter/ephemeral"
        rm_dir "$app_dir/macos/Flutter/ephemeral" "$app_dir/macos/build"
    done

    # Photos-app generated code
    local photos="$mob/apps/photos"
    if [[ -d "$photos" ]]; then
        if [[ -d "$photos/lib/src/rust" ]]; then
            find_rm_files "$photos/lib/src/rust" "*"
        fi
        if [[ -d "$photos/rust/src" ]]; then
            find_rm_files "$photos/rust/src" "frb_generated*"
        fi
        if [[ -d "$photos/test" ]]; then
            find_rm_files "$photos/test" "*.mocks.dart"
        fi
        if [[ -d "$photos/lib/generated/intl" ]]; then
            find_rm_files "$photos/lib/generated/intl" "app_localizations*.dart"
        fi
    fi

    # Auth-app specific
    local auth="$mob/apps/auth"
    if [[ -d "$auth" ]]; then
        if [[ -d "$auth/lib/l10n/arb" ]]; then
            find_rm_files "$auth/lib/l10n/arb" "*.dart"
        fi
        rm_dir "$auth/dist"
    fi

    # Per package
    for pkg_dir in "$mob"/packages/*; do
        [[ -d "$pkg_dir" ]] || continue
        rm_file "$pkg_dir/.flutter-plugins-dependencies"
        rm_dir "$pkg_dir/build"
    done
}

clean_mobile_native() {
    info "Mobile Native (mobile/native/)"
    local nat="$REPO_ROOT/mobile/native"
    [[ -d "$nat" ]] || return 0

    # Build directories
    rm_dir "$nat/android/packages/rust/build"
    rm_dir "$nat/darwin/Packages/Rust/build"
    rm_dir "$nat/darwin/Apps/ensu/build"
    rm_dir "$nat/darwin/Apps/ensu/build-native-check"

    # Generated JNI libs
    rm_dir "$nat/android/apps/ensu/crypto-auth-core/src/main/jniLibs"
    rm_dir "$nat/android/packages/rust/src/main/jniLibs"

    # Generated UniFFI Kotlin files
    rm_file "$nat/android/apps/ensu/crypto-auth-core/src/main/java/io/ente/ensu/crypto/core_uniffi.kt"
    rm_file "$nat/android/apps/ensu/crypto-auth-core/src/main/java/io/ente/ensu/crypto/core.kt"
    rm_file "$nat/android/packages/rust/src/main/kotlin/io/ente/labs/inference_rs/inference_rs_uniffi.kt"
    rm_file "$nat/android/packages/rust/src/main/kotlin/io/ente/labs/inference_rs/inference.kt"
    rm_file "$nat/android/packages/rust/src/main/kotlin/io/ente/labs/llmchat_db/llmchat_db_uniffi.kt"
    rm_file "$nat/android/packages/rust/src/main/kotlin/io/ente/labs/ensu_db/db.kt"
    rm_file "$nat/android/packages/rust/src/main/kotlin/io/ente/labs/llmchat_sync/llmchat_sync_uniffi.kt"
    rm_file "$nat/android/packages/rust/src/main/kotlin/io/ente/labs/ensu_sync/sync.kt"

    # Generated Swift files
    local gen_dir="$nat/darwin/Apps/ensu/ensu/Generated"
    if [[ -d "$gen_dir" ]]; then
        find_rm_files "$gen_dir" "*_uniffi*"
        find_rm_files "$gen_dir" "core*"
        find_rm_files "$gen_dir" "db*"
        find_rm_files "$gen_dir" "sync*"
        rm_file "$gen_dir/EndpointConfig.swift"
    fi

    # InferenceRS XCFramework and bindings
    rm_dir "$nat/darwin/Packages/Rust/InferenceRSFFI.xcframework"
    if [[ -d "$nat/darwin/Packages/Rust/Sources/InferenceRS" ]]; then
        find_rm_files "$nat/darwin/Packages/Rust/Sources/InferenceRS" "inference_rs_uniffi*"
    fi

    # .swiftpm directories
    find_rm_dirs "$nat" ".swiftpm"
}

clean_server() {
    info "Server (server/)"
    local srv="$REPO_ROOT/server"
    [[ -d "$srv" ]] || return 0

    rm_dir "$srv/bin" "$srv/data" "$srv/logs" "$srv/tmp" "$srv/my-ente"
    rm_file "$srv/museum" "$srv/main"
    find_rm_files "$srv" "__debug_bin*"
    rm_file "$srv/config/.env" "$srv/config/museum.yaml" "$srv/museum.yaml" "$srv/credentials"
}

clean_cli() {
    info "CLI (cli/)"
    local cli="$REPO_ROOT/cli"
    [[ -d "$cli" ]] || return 0

    rm_dir "$cli/bin" "$cli/dist" "$cli/data" "$cli/logs" "$cli/tmp" "$cli/scratch"
    rm_file "$cli/config.yaml" "$cli/ente-cli.db"
}

clean_rust() {
    info "Rust (rust/)"
    local rs="$REPO_ROOT/rust"
    [[ -d "$rs" ]] || return 0

    # target/ already handled globally
    rm_dir "$rs/apps/ensu/src-tauri/gen"
    rm_file "$rs/apps/ensu/src-tauri/tauri.conf.dev.json"
    rm_dir "$rs/cli/exports"
}

clean_docs() {
    info "Docs (docs/)"
    local docs="$REPO_ROOT/docs"
    [[ -d "$docs" ]] || return 0

    rm_dir "$docs/docs/.vitepress/cache" "$docs/docs/.vitepress/dist"
}

clean_infra() {
    info "Infra (infra/)"
    local infra="$REPO_ROOT/infra"
    [[ -d "$infra" ]] || return 0

    # Workers
    if [[ -d "$infra/workers" ]]; then
        find_rm_dirs "$infra/workers" ".wrangler"
        find_rm_files "$infra/workers" "yarn.lock"
    fi

    # Staff
    if [[ -d "$infra/staff" ]]; then
        rm_dir "$infra/staff/dist"
        find_rm_files "$infra/staff" ".env*.local"
    fi

    # ML (Python)
    local ml="$infra/ml"
    if [[ -d "$ml" ]]; then
        find_rm_files "$ml" "*.pyc"
        find_rm_files "$ml" "*.pyo"
        rm_dir "$ml/build" "$ml/dist" "$ml/wheels"
        find_rm_dirs "$ml" "*.egg-info"
        rm_dir "$ml/.venv"
        rm_dir "$ml/.cache" "$ml/test/.cache"
        rm_dir "$ml/test_data" "$ml/test/test_data"
        rm_dir "$ml/out" "$ml/test/out"

        # Golden JSON files (preserve .gitkeep)
        if [[ -d "$ml/ground_truth/goldens" ]]; then
            find "$ml/ground_truth/goldens" -name "*.json" -type f -delete 2>/dev/null || true
        fi
        if [[ -d "$ml/test/ground_truth/goldens" ]]; then
            find "$ml/test/ground_truth/goldens" -name "*.json" -type f -delete 2>/dev/null || true
        fi

        find_rm_dirs "$ml" "onnx_models"
        find_rm_files "$ml" "*.pt"
        find_rm_files "$ml" "*.onnx"
        find_rm_files "$ml" "*.tflite"
        rm_dir "$ml/playground/CLIP/mobileclip_repo"
    fi

    # Copycat-db
    rm_file "$infra/copycat-db/copycat-db.env"
}

clean_git_clean() {
    info "git clean -fdx (final pass)"
    if [[ "$DRY_RUN" == true ]]; then
        git -C "$REPO_ROOT" clean -fdnx
    else
        git -C "$REPO_ROOT" clean -fdx
    fi
}

# --- Main ---

echo ""
echo -e "${BOLD}Ente Monorepo Clean${NC}"
echo "===================="
echo "Repository: $REPO_ROOT"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "Mode: ${YELLOW}DRY RUN${NC} (no files will be deleted)"
fi

if [[ "$SKIP_CONFIRM" == false && "$DRY_RUN" == false ]]; then
    echo ""
    echo "This will remove ALL build artifacts, caches, and generated files."
    echo "Lock files (yarn.lock, Cargo.lock, pubspec.lock, go.sum) will be preserved."
    echo ""
    read -rp "Continue? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

clean_global
clean_web
clean_desktop
clean_mobile
clean_mobile_native
clean_server
clean_cli
clean_rust
clean_docs
clean_infra

if [[ "$GIT_CLEAN" == true ]]; then
    clean_git_clean
fi

echo ""
echo -e "${BOLD}${GREEN}Done.${NC}"
