#!/bin/bash
#
# NiteLite build script
#
#   ./build.sh            Debug build, then launch it (for development)
#   ./build.sh release    Release build → dist/NiteLite.app
#   ./build.sh install    Release build, then install to /Applications and launch
#   ./build.sh package    Release build → dist/NiteLite.zip, copied into site/ for download
#   ./build.sh clean      Remove build/ and dist/
#
# Signing: builds are ad-hoc signed by default, which means macOS asks for
# Automation permission again after every reinstall. To keep the permission
# across rebuilds, sign with a stable identity from your keychain:
#
#   NITELITE_SIGN_IDENTITY="My Cert Name" ./build.sh install
#
# List available identities with: security find-identity -v -p codesigning

set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="NiteLite"
PROJECT="$APP_NAME.xcodeproj"
SCHEME="$APP_NAME"
DERIVED_DATA="build"
DIST_DIR="dist"
INSTALL_DIR="/Applications"

build() {
    local configuration="$1"
    local sign_args=()

    if [[ -n "${NITELITE_SIGN_IDENTITY:-}" ]]; then
        echo "Signing with: $NITELITE_SIGN_IDENTITY"
        sign_args=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$NITELITE_SIGN_IDENTITY" DEVELOPMENT_TEAM="")
    fi

    echo "Building $APP_NAME ($configuration)..."
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$configuration" \
        -destination "generic/platform=macOS" \
        -derivedDataPath "$DERIVED_DATA" \
        -quiet \
        build ${sign_args[@]+"${sign_args[@]}"}
}

product_path() {
    echo "$DERIVED_DATA/Build/Products/$1/$APP_NAME.app"
}

quit_running_app() {
    # Exact process-name match only — never a broad pattern.
    local pids
    pids=$(pgrep -x "$APP_NAME" || true)
    if [[ -n "$pids" ]]; then
        echo "Quitting running $APP_NAME (pid $pids)..."
        kill $pids
        sleep 0.5
    fi
}

release() {
    build Release
    rm -rf "$DIST_DIR"
    mkdir -p "$DIST_DIR"
    ditto "$(product_path Release)" "$DIST_DIR/$APP_NAME.app"
    echo "Built: $DIST_DIR/$APP_NAME.app"
}

case "${1:-run}" in
    run)
        build Debug
        quit_running_app
        open "$(product_path Debug)"
        ;;
    release)
        release
        ;;
    package)
        release
        ditto -c -k --keepParent "$DIST_DIR/$APP_NAME.app" "$DIST_DIR/$APP_NAME.zip"
        cp "$DIST_DIR/$APP_NAME.zip" "site/$APP_NAME.zip"
        echo "Packaged: $DIST_DIR/$APP_NAME.zip (copied to site/)"
        echo "Publish the site with: sf publish site"
        ;;
    install)
        release
        quit_running_app
        rm -rf "$INSTALL_DIR/$APP_NAME.app"
        ditto "$DIST_DIR/$APP_NAME.app" "$INSTALL_DIR/$APP_NAME.app"
        echo "Installed: $INSTALL_DIR/$APP_NAME.app"
        open "$INSTALL_DIR/$APP_NAME.app"
        ;;
    clean)
        rm -rf "$DERIVED_DATA" "$DIST_DIR"
        echo "Cleaned."
        ;;
    *)
        echo "Usage: ./build.sh [run|release|install|package|clean]"
        exit 1
        ;;
esac
