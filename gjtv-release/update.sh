#!/bin/bash

# GJTV Update Script
# Quick update for GJTV using pre-built binaries

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RELEASE_REPO_URL="https://github.com/gjogre/gjtv-release"
RAW_CONTENT_URL="https://raw.githubusercontent.com/gjogre/gjtv-release/main"
GJTV_BINARY_DIR="$HOME/.local/bin"
GJTV_CONFIG_DIR="$HOME/.config/gjtv"

# Detect platform
PLATFORM="linux"
ARCH="x86_64"
case "$(uname -m)" in
    "x86_64") ARCH="x86_64" ;;
    "aarch64"|"arm64") ARCH="arm64" ;;
    *) print_error "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac
BINARY_NAME="gjtv-${PLATFORM}-${ARCH}"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if GJTV is installed
check_installation() {
    if [ ! -f "$GJTV_BINARY_DIR/gjtv" ]; then
        print_error "GJTV is not installed. Please run ./install.sh first"
        exit 1
    fi
}

# Stop running instances
stop_gjtv() {
    if pgrep -x "gjtv" > /dev/null; then
        print_status "Stopping running GJTV instances..."
        pkill -x "gjtv" || true
        sleep 1
        print_success "GJTV stopped"
    fi
}

# Download and update binary
update_binary() {
    local version="${1:-latest}"
    print_status "Downloading GJTV binary ($version)..."
    
    local download_url
    if [ "$version" = "latest" ]; then
        download_url="${RAW_CONTENT_URL}/releases/latest/${BINARY_NAME}"
    else
        download_url="${RAW_CONTENT_URL}/releases/${version}/${BINARY_NAME}"
    fi
    
    local temp_binary="/tmp/gjtv-update"
    
    if ! curl -fsSL "$download_url" -o "$temp_binary"; then
        print_error "Failed to download GJTV binary from $download_url"
        print_error "Please check if version '$version' exists for platform '$PLATFORM-$ARCH'"
        exit 1
    fi
    
    # Verify it's actually a binary (not HTML error page)
    if file "$temp_binary" | grep -q "HTML document"; then
        print_error "Downloaded file appears to be HTML (likely 404 error)"
        print_error "Version '$version' may not exist for platform '$PLATFORM-$ARCH'"
        rm -f "$temp_binary"
        exit 1
    fi
    
    print_status "Installing updated binary..."
    mv "$temp_binary" "$GJTV_BINARY_DIR/gjtv"
    chmod +x "$GJTV_BINARY_DIR/gjtv"
    
    print_success "Binary updated to $version"
}

# Update configuration files (optional)
update_configs() {
    if [ "$1" = "--update-configs" ]; then
        print_status "Updating configuration files..."
        
        # Backup existing configs
        if [ -f "$GJTV_CONFIG_DIR/config.toml" ]; then
            cp "$GJTV_CONFIG_DIR/config.toml" "$GJTV_CONFIG_DIR/config.toml.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        if [ -f "$GJTV_CONFIG_DIR/keymap.toml" ]; then
            cp "$GJTV_CONFIG_DIR/keymap.toml" "$GJTV_CONFIG_DIR/keymap.toml.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # Download new configs
        if curl -fsSL "${RAW_CONTENT_URL}/config/config.toml" -o "$GJTV_CONFIG_DIR/config.toml"; then
            print_success "Updated config.toml"
        else
            print_warning "Failed to download config.toml"
        fi
        
        if curl -fsSL "${RAW_CONTENT_URL}/config/keymap.toml" -o "$GJTV_CONFIG_DIR/keymap.toml"; then
            print_success "Updated keymap.toml"
        else
            print_warning "Failed to download keymap.toml"
        fi
        
        print_success "Configuration files updated (originals backed up)"
    else
        print_warning "Configuration files not updated. Use --update-configs to force update."
    fi
}

# Check for curl dependency
check_dependencies() {
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl is required but not installed"
        print_error "Please install curl and try again"
        exit 1
    fi
}

# Main update function
main() {
    local version="${1:-latest}"
    local update_configs_flag="$2"
    
    echo "🔄 GJTV Update Script 🔄"
    echo ""
    echo "Updating to version: $version"
    echo "Platform: $PLATFORM-$ARCH"
    echo ""
    
    check_dependencies
    check_installation
    stop_gjtv
    update_binary "$version"
    update_configs "$update_configs_flag"
    
    echo ""
    print_success "🎉 GJTV updated successfully!"
    echo ""
    echo "GJTV will start automatically with Hyprland or you can launch it manually."
    echo "Press Home key to toggle GJTV when Hyprland is running."
}

# Show help
show_help() {
    echo "GJTV Update Script"
    echo ""
    echo "Usage: $0 [version] [options]"
    echo ""
    echo "Versions:"
    echo "  latest              Update to latest stable release (default)"
    echo "  v1.0.0              Update to specific version"
    echo "  beta                Update to latest beta release"
    echo ""
    echo "Options:"
    echo "  --update-configs    Also update configuration files (backs up existing)"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                     Update to latest version"
    echo "  $0 v1.0.0              Update to specific version"
    echo "  $0 latest --update-configs  Update binary and config files"
    echo "  $0 beta                Update to latest beta version"
    echo ""
    echo "Release repository: $RELEASE_REPO_URL"
}

# Parse arguments
case "${1:-}" in
    "--help"|"-h")
        show_help
        ;;
    *)
        # Determine if first arg is version or option
        if [[ "${1:-}" =~ ^(latest|beta|v[0-9]+\.[0-9]+\.[0-9]+.*)$ ]]; then
            # First arg is version
            main "$1" "$2"
        elif [[ "${1:-}" == "--update-configs" ]]; then
            # First arg is option, use latest version
            main "latest" "$1"
        else
            # Default: latest version, pass all args as options
            main "latest" "$1"
        fi
        ;;
esac