#!/usr/bin/env bash

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$PLUGIN_DIR/bin"
BINARY="$BIN_DIR/tmux-agent-sidebar"
REPO="hiroppy/tmux-agent-sidebar"
action="${1:-}"

function finish {
    local exit_code=$?
    # When run without arguments (interactive menu), the menu spawns a
    # new-window with the action — that child process handles the reload.
    if [[ -z "$action" ]]; then
        exit $exit_code
    fi
    if [[ $exit_code -eq 0 ]]; then
        echo "Reloading tmux.conf"
        tmux source ~/.tmux.conf
        exit 0
    else
        echo "Something went wrong. Press any key to close this window."
        read -n 1
        exit 1
    fi
}
trap finish EXIT

function detect_platform() {
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"

    case "$os" in
        darwin|linux) ;;
        *)
            echo "Unsupported OS: $os"
            exit 1
            ;;
    esac

    case "$arch" in
        x86_64|amd64)  arch="x86_64" ;;
        arm64|aarch64) arch="aarch64" ;;
        *)
            echo "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    echo "${os}-${arch}"
}

function stop_running_instances() {
    # Kill any running instances so the next launch picks up the new binary.
    # Match the full binary path to avoid touching unrelated processes.
    pkill -f "$BINARY" 2>/dev/null || true
}

function post_install_fixups() {
    # macOS: strip provenance/quarantine xattrs and re-sign the binary so
    # Gatekeeper on Sequoia+ doesn't SIGKILL downloaded adhoc-signed binaries.
    if [[ "$(uname -s)" == "Darwin" ]]; then
        xattr -d com.apple.provenance "$BINARY" 2>/dev/null || true
        xattr -d com.apple.quarantine "$BINARY" 2>/dev/null || true
        codesign --force --sign - "$BINARY" >/dev/null 2>&1 || true
    fi

    stop_running_instances
}

function download_binary() {
    mkdir -p "$BIN_DIR"
    local platform
    platform="$(detect_platform)"
    local asset_name="tmux-agent-sidebar-${platform}"
    local url="https://github.com/$REPO/releases/latest/download/$asset_name"

    echo "Downloading binary from $url"
    if ! curl -fSL "$url" -o "$BINARY"; then
        echo ""
        echo "Download failed. No release found or network error."
        echo "Try 'Build from source' instead."
        return 1
    fi
    chmod +x "$BINARY"

    post_install_fixups

    echo "Download complete!"
}

function build_from_source() {
    echo "Building from source..."

    if ! command -v cargo &>/dev/null; then
        echo "Rust is not installed. Please install it first."
        echo ""
        echo "  https://rustup.rs/"
        echo ""
        return 1
    fi

    cargo build --release --manifest-path "$PLUGIN_DIR/Cargo.toml"

    mkdir -p "$BIN_DIR"
    cp "$PLUGIN_DIR/target/release/tmux-agent-sidebar" "$BINARY"

    post_install_fixups

    echo "Build complete!"
}

# Direct action dispatch
case "$action" in
    download-binary)
        download_binary
        exit $?
        ;;
    build-from-source)
        build_from_source
        exit $?
        ;;
esac

# Interactive menu
function get_message() {
    if [[ "${SIDEBAR_UPDATE:-}" == "1" ]]; then
        echo "tmux-agent-sidebar has been updated. We need to get the new binary."
    else
        echo "First time setup. We need to get the tmux-agent-sidebar binary."
    fi
}

tmux display-menu -T "tmux-agent-sidebar" \
    "" \
    "- " "" "" \
    "-  #[nodim,bold]tmux-agent-sidebar" "" "" \
    "- " "" "" \
    "-  $(get_message) " "" "" \
    "- " "" "" \
    "" \
    "Download binary" d "new-window \"$PLUGIN_DIR/install-wizard.sh download-binary\"" \
    "Build from source (Rust required)" s "new-window \"$PLUGIN_DIR/install-wizard.sh build-from-source\"" \
    "" \
    "Exit" q ""
