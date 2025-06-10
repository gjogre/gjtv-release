#!/bin/bash

# GJTV Installation Script
# Downloads pre-built binaries and configures Hyprland integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RELEASE_REPO_URL="https://github.com/gjogre/gjtv-release"
RELEASE_API_URL="https://api.github.com/repos/gjogre/gjtv-release"
RAW_CONTENT_URL="https://raw.githubusercontent.com/gjogre/gjtv-release/main"
HYPRLAND_CONFIG_DIR="$HOME/.config/hypr"
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create backup
create_backup() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        print_success "Created backup: $backup"
    fi
}

# Check dependencies
check_dependencies() {
    print_status "Checking dependencies..."

    local missing_deps=()

    if ! command_exists "curl"; then
        missing_deps+=("curl")
    fi

    if ! command_exists "hyprctl"; then
        missing_deps+=("hyprland")
    fi

    if ! command_exists "unzip"; then
        missing_deps+=("unzip")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Please install missing dependencies and run this script again."
        echo ""
        echo "For Arch Linux:"
        echo "  sudo pacman -S curl hyprland unzip"
        echo ""
        echo "For Ubuntu/Debian:"
        echo "  sudo apt update && sudo apt install curl unzip"
        echo "  # Follow Hyprland installation instructions for your distro"
        exit 1
    fi

    print_success "All dependencies found"
}

# Download GJTV binary
download_gjtv() {
    local version="${1:-latest}"
    print_status "Downloading GJTV binary (${version})..."

    local download_url
    if [ "$version" = "latest" ]; then
        download_url="${RAW_CONTENT_URL}/releases/latest/${BINARY_NAME}"
    else
        download_url="${RAW_CONTENT_URL}/releases/${version}/${BINARY_NAME}"
    fi

    local temp_binary="/tmp/gjtv-download"

    if ! curl -fsSL "$download_url" -o "$temp_binary"; then
        print_error "Failed to download GJTV binary from $download_url"
        print_error "Please check if the version exists or try 'latest'"
        exit 1
    fi

    # Verify it's actually a binary (not HTML error page)
    if file "$temp_binary" | grep -q "HTML document"; then
        print_error "Downloaded file appears to be HTML (likely 404 error)"
        print_error "Version '$version' may not exist for platform '$PLATFORM-$ARCH'"
        rm -f "$temp_binary"
        exit 1
    fi

    # Move to final location
    mkdir -p "$GJTV_BINARY_DIR"
    mv "$temp_binary" "$GJTV_BINARY_DIR/gjtv"
    chmod +x "$GJTV_BINARY_DIR/gjtv"

    print_success "GJTV binary downloaded and installed"
}

# Download configuration files
download_configs() {
    print_status "Downloading configuration files..."

    mkdir -p "$GJTV_CONFIG_DIR"

    # Download main config
    if ! curl -fsSL "${RAW_CONTENT_URL}/config/config.toml" -o "$GJTV_CONFIG_DIR/config.toml"; then
        print_warning "Failed to download config.toml, will be generated on first run"
    fi

    # Download settings config
    if ! curl -fsSL "${RAW_CONTENT_URL}/config/settings.toml" -o "$GJTV_CONFIG_DIR/settings.toml"; then
        print_warning "Failed to download settings.toml, will be generated on first run"
    fi

    # Download keymap config
    if ! curl -fsSL "${RAW_CONTENT_URL}/config/keymap.toml" -o "$GJTV_CONFIG_DIR/keymap.toml"; then
        print_warning "Failed to download keymap.toml, will be generated on first run"
    fi

    # Download theme config
    if ! curl -fsSL "${RAW_CONTENT_URL}/config/theme.toml" -o "$GJTV_CONFIG_DIR/theme.toml"; then
        print_warning "Failed to download theme.toml, will be generated on first run"
    fi

    print_success "Configuration files downloaded"
}

# Download assets
download_assets() {
    print_status "Downloading assets..."

    mkdir -p "$GJTV_CONFIG_DIR/assets/fonts"
    mkdir -p "$GJTV_CONFIG_DIR/assets/icons"
    mkdir -p "$GJTV_CONFIG_DIR/assets/icons/cached"

    # Download fonts
    if curl -fsSL "${RAW_CONTENT_URL}/assets/fonts/DepartureMono-Regular.ttf" -o "$GJTV_CONFIG_DIR/assets/fonts/DepartureMono-Regular.ttf" 2>/dev/null; then
        print_success "Downloaded DepartureMono font"
    else
        print_warning "Failed to download font, will use system fallback"
    fi

    # Download default icons
    if curl -fsSL "${RAW_CONTENT_URL}/assets/icons/default.png" -o "$GJTV_CONFIG_DIR/assets/icons/default.png" 2>/dev/null; then
        print_success "Downloaded default icons"
    else
        print_warning "Failed to download default icon, will use system icons"
    fi

    # Download additional fallback icons
    for fallback in "app" "unknown" "fallback"; do
        curl -fsSL "${RAW_CONTENT_URL}/assets/icons/${fallback}.png" -o "$GJTV_CONFIG_DIR/assets/icons/${fallback}.png" 2>/dev/null || true
    done

    # Download app category icons
    for icon in "games" "media" "internet" "graphics" "development" "communication"; do
        curl -fsSL "${RAW_CONTENT_URL}/assets/icons/${icon}.png" -o "$GJTV_CONFIG_DIR/assets/icons/${icon}.png" 2>/dev/null || true
    done

    print_success "Assets downloaded"
}

# Install binary (binary is already downloaded and in place)
install_binary() {
    print_status "Setting up GJTV binary..."

    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$GJTV_BINARY_DIR"; then
        echo "" >> "$HOME/.bashrc"
        echo "# GJTV binary path" >> "$HOME/.bashrc"
        echo "export PATH=\"\$PATH:$GJTV_BINARY_DIR\"" >> "$HOME/.bashrc"

        if [ -f "$HOME/.zshrc" ]; then
            echo "" >> "$HOME/.zshrc"
            echo "# GJTV binary path" >> "$HOME/.zshrc"
            echo "export PATH=\"\$PATH:$GJTV_BINARY_DIR\"" >> "$HOME/.zshrc"
        fi

        print_warning "Added $GJTV_BINARY_DIR to PATH in shell config"
        print_warning "You may need to restart your shell or run: source ~/.bashrc"
    fi

    print_success "GJTV binary installed to $GJTV_BINARY_DIR/gjtv"
}

# Install configuration (configs are already downloaded)
install_config() {
    print_status "Verifying GJTV configuration..."

    # Verify config directory exists
    if [ ! -d "$GJTV_CONFIG_DIR" ]; then
        mkdir -p "$GJTV_CONFIG_DIR"
    fi

    # Check if configs exist, if not create minimal ones
    if [ ! -f "$GJTV_CONFIG_DIR/config.toml" ]; then
        print_warning "config.toml not found, GJTV will create default on first run"
    fi

    if [ ! -f "$GJTV_CONFIG_DIR/settings.toml" ]; then
        print_warning "settings.toml not found, GJTV will create default on first run"
    fi

    if [ ! -f "$GJTV_CONFIG_DIR/keymap.toml" ]; then
        print_warning "keymap.toml not found, GJTV will create default on first run"
    fi

    if [ ! -f "$GJTV_CONFIG_DIR/theme.toml" ]; then
        print_warning "theme.toml not found, GJTV will create default on first run"
    fi

    print_success "Configuration verified at $GJTV_CONFIG_DIR"
}

# Configure Hyprland
configure_hyprland() {
    print_status "Configuring Hyprland integration..."

    # Check if Hyprland config directory exists
    if [ ! -d "$HYPRLAND_CONFIG_DIR" ]; then
        print_error "Hyprland config directory not found: $HYPRLAND_CONFIG_DIR"
        print_error "Please ensure Hyprland is installed and configured"
        exit 1
    fi

    local hyprland_conf="$HYPRLAND_CONFIG_DIR/hyprland.conf"
    local gjtv_conf="$HYPRLAND_CONFIG_DIR/gjtv.conf"

    # Use local GJTV Hyprland configuration if available, otherwise download
    local local_gjtv_conf="$(dirname "$0")/hyprland/gjtv.conf"
    
    if [ -f "$local_gjtv_conf" ]; then
        # Copy local configuration
        cp "$local_gjtv_conf" "$gjtv_conf"
        # Update the exec-once line to use the full path
        sed -i "s|exec-once = gjtv|exec-once = $GJTV_BINARY_DIR/gjtv|g" "$gjtv_conf"
        print_success "Copied local Hyprland configuration"
    elif curl -fsSL "${RAW_CONTENT_URL}/hyprland/gjtv.conf" -o "$gjtv_conf" 2>/dev/null; then
        # Update the exec-once line to use the full path
        sed -i "s|exec-once = gjtv|exec-once = $GJTV_BINARY_DIR/gjtv|g" "$gjtv_conf"
        print_success "Downloaded Hyprland configuration"
    else
        print_warning "Failed to find or download Hyprland config, creating basic one"
        cat > "$gjtv_conf" << EOF
# GJTV Hyprland Configuration
workspace = special:gjtv, gapsout:0, gapsin:0
windowrulev2 = workspace special:gjtv, class:^(gjtv)$
windowrulev2 = fullscreen, class:^(gjtv)$
windowrulev2 = noborder, class:^(gjtv)$
windowrulev2 = suppressevent maximize, class:^(gjtv)$
exec-once = $GJTV_BINARY_DIR/gjtv
bind = , Home, togglespecialworkspace, gjtv
EOF
    fi

    # Check if main config already includes GJTV config
    if [ -f "$hyprland_conf" ]; then
        if ! grep -q "source.*gjtv.conf" "$hyprland_conf"; then
            create_backup "$hyprland_conf"

            echo "" >> "$hyprland_conf"
            echo "# GJTV Configuration" >> "$hyprland_conf"
            echo "source = ~/.config/hypr/gjtv.conf" >> "$hyprland_conf"

            print_success "Added GJTV configuration to Hyprland config"
        else
            print_success "GJTV configuration already included in Hyprland config"
        fi
    else
        print_warning "Hyprland config file not found, creating basic config with GJTV"
        cat > "$hyprland_conf" << EOF
# Basic Hyprland configuration with GJTV
source = ~/.config/hypr/gjtv.conf

# Add your other Hyprland configuration here
EOF
        print_success "Created basic Hyprland configuration"
    fi

    print_success "Hyprland integration configured"
}

# Create desktop entry
create_desktop_entry() {
    print_status "Creating desktop entry..."

    local desktop_dir="$HOME/.local/share/applications"
    local desktop_file="$desktop_dir/gjtv.desktop"

    mkdir -p "$desktop_dir"

    cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=GJTV
Comment=Game/TV Launcher for Hyprland
Exec=$GJTV_BINARY_DIR/gjtv
Icon=applications-games
Terminal=false
NoDisplay=true
Categories=Game;AudioVideo;
Keywords=launcher;tv;games;media;
StartupNotify=false
EOF

    print_success "Desktop entry created"
}

# Update existing installation
update_installation() {
    local version="${1:-latest}"
    print_status "Updating existing GJTV installation to $version..."

    # Stop any running GJTV instances
    if pgrep -x "gjtv" > /dev/null; then
        print_status "Stopping running GJTV instances..."
        pkill -x "gjtv" || true
        sleep 1
    fi

    # Update binary
    download_gjtv "$version"
    install_binary

    # Update configurations (backup existing)
    if [ -f "$GJTV_CONFIG_DIR/config.toml" ]; then
        create_backup "$GJTV_CONFIG_DIR/config.toml"
    fi
    if [ -f "$GJTV_CONFIG_DIR/settings.toml" ]; then
        create_backup "$GJTV_CONFIG_DIR/settings.toml"
    fi
    if [ -f "$GJTV_CONFIG_DIR/keymap.toml" ]; then
        create_backup "$GJTV_CONFIG_DIR/keymap.toml"
    fi
    if [ -f "$GJTV_CONFIG_DIR/theme.toml" ]; then
        create_backup "$GJTV_CONFIG_DIR/theme.toml"
    fi

    download_configs
    install_config
    configure_hyprland

    print_success "GJTV updated successfully"
}

# Uninstall GJTV
uninstall_gjtv() {
    print_status "Uninstalling GJTV..."

    # Stop any running instances
    if pgrep -x "gjtv" > /dev/null; then
        print_status "Stopping GJTV..."
        pkill -x "gjtv" || true
    fi

    # Remove binary
    if [ -f "$GJTV_BINARY_DIR/gjtv" ]; then
        rm "$GJTV_BINARY_DIR/gjtv"
        print_success "Removed binary"
    fi

    # Remove configuration (ask user)
    if [ -d "$GJTV_CONFIG_DIR" ]; then
        read -p "Remove configuration directory $GJTV_CONFIG_DIR? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$GJTV_CONFIG_DIR"
            print_success "Removed configuration directory"
        fi
    fi

    # Remove Hyprland configuration
    local gjtv_conf="$HYPRLAND_CONFIG_DIR/gjtv.conf"
    if [ -f "$gjtv_conf" ]; then
        rm "$gjtv_conf"
        print_success "Removed Hyprland configuration"
    fi

    # Remove from Hyprland main config
    local hyprland_conf="$HYPRLAND_CONFIG_DIR/hyprland.conf"
    if [ -f "$hyprland_conf" ] && grep -q "gjtv.conf" "$hyprland_conf"; then
        create_backup "$hyprland_conf"
        sed -i '/gjtv.conf/d' "$hyprland_conf"
        sed -i '/# GJTV Configuration/d' "$hyprland_conf"
        print_success "Removed GJTV from Hyprland configuration"
    fi

    # Remove desktop entry
    local desktop_file="$HOME/.local/share/applications/gjtv.desktop"
    if [ -f "$desktop_file" ]; then
        rm "$desktop_file"
        print_success "Removed desktop entry"
    fi

    print_success "GJTV uninstalled"
}

# Show status
show_status() {
    print_status "GJTV Installation Status:"
    echo ""

    # Check binary
    if [ -f "$GJTV_BINARY_DIR/gjtv" ]; then
        print_success "Binary: Installed ($GJTV_BINARY_DIR/gjtv)"
    else
        print_error "Binary: Not installed"
    fi

    # Check configuration
    if [ -d "$GJTV_CONFIG_DIR" ]; then
        print_success "Configuration: Installed ($GJTV_CONFIG_DIR)"
    else
        print_error "Configuration: Not installed"
    fi

    # Check Hyprland integration
    local gjtv_conf="$HYPRLAND_CONFIG_DIR/gjtv.conf"
    if [ -f "$gjtv_conf" ]; then
        print_success "Hyprland config: Installed ($gjtv_conf)"
    else
        print_error "Hyprland config: Not installed"
    fi

    # Check if running
    if pgrep -x "gjtv" > /dev/null; then
        print_success "Status: Running"
    else
        print_warning "Status: Not running"
    fi

    echo ""
}

# Show help
show_help() {
    echo "GJTV Installation Script"
    echo ""
    echo "Usage: $0 [command] [version]"
    echo ""
    echo "Commands:"
    echo "  install [version]   Install GJTV and configure Hyprland (default)"
    echo "  update [version]    Update existing GJTV installation"
    echo "  uninstall           Remove GJTV and its configuration"
    echo "  status              Show installation status"
    echo "  help                Show this help message"
    echo ""
    echo "Versions:"
    echo "  latest              Install latest stable release (default)"
    echo "  v1.0.0              Install specific version"
    echo "  beta                Install latest beta release"
    echo ""
    echo "Examples:"
    echo "  $0                  Install latest version"
    echo "  $0 install v1.0.0   Install specific version"
    echo "  $0 update           Update to latest version"
    echo "  $0 update beta      Update to latest beta"
    echo ""
    echo "After installation:"
    echo "  - Press Home key to toggle GJTV"
    echo "  - Use arrow keys or gamepad to navigate"
    echo "  - Press M key to open Settings tab"
    echo "  - Configuration: $GJTV_CONFIG_DIR"
    echo "  - Release repo: $RELEASE_REPO_URL"
    echo ""
}

# Main installation function
install_gjtv() {
    local version="${1:-latest}"
    echo "🎮 GJTV Installation Script 🎮"
    echo ""
    echo "Installing GJTV version: $version"
    echo "Platform: $PLATFORM-$ARCH"
    echo ""

    check_dependencies
    download_gjtv "$version"
    download_configs
    download_assets
    install_binary
    install_config
    configure_hyprland
    create_desktop_entry

    echo ""
    print_success "🎉 GJTV installation completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Restart Hyprland or reload configuration: hyprctl reload"
    echo "2. Press Home key to open GJTV"
    echo "3. Press M key to access Settings tab"
    echo "4. Navigate to Settings tab (press M key) to customize:"
    echo "   - Cell Appearance: Customize app cell size, corners, shadows"
    echo "   - Tab Appearance: Adjust tab styling and positioning"
    echo "   - Animations: Enable dice roll and breathing animations"
    echo "   - Text Styling: Configure fonts and text effects"
    echo "5. Edit configuration files in: $GJTV_CONFIG_DIR/"
    echo "   - config.toml: Application definitions"
    echo "   - settings.toml: Visual and behavior settings"
    echo "   - keymap.toml: Key binding configuration"
    echo "   - theme.toml: Color themes and styling"
    echo ""
    echo "For help: $0 help"
}

# Main script logic
case "${1:-install}" in
    "install")
        install_gjtv "${2:-latest}"
        ;;
    "update")
        update_installation "${2:-latest}"
        ;;
    "uninstall")
        uninstall_gjtv
        ;;
    "status")
        show_status
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
