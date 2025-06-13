#!/bin/bash

# GJTV Installation Script
# Downloads pre-built binaries and configures Hyprland integration
## Preserve existing configurations (recommended for updates)
#./install.sh --preserve-config

## Use fresh configurations (recommended for new installs)
#./install.sh --overwrite-config

## Install specific version with config preservation
#./install.sh install --preserve-config v1.2.0
#set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RELEASE_REPO_URL="https://github.com/gjogre/gjtv-release"
RELEASE_API_URL="https://api.github.com/repos/gjogre/gjtv-release"
RAW_CONTENT_URL="https://raw.githubusercontent.com/gjogre/gjtv-release/main/gjtv-release"
HYPRLAND_CONFIG_DIR="$HOME/.config/hypr"
GJTV_BINARY_DIR="$HOME/.local/bin"
GJTV_CONFIG_DIR="$HOME/.config/gjtv"

# Migration settings
PRESERVE_CONFIG=false
SKIP_HYPRPAPER=false

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

# Function to check if hyprpaper is installed
check_hyprpaper() {
    if command_exists "hyprpaper"; then
        return 0  # hyprpaper is installed
    else
        return 1  # hyprpaper is not installed
    fi
}

# Function to install hyprpaper
install_hyprpaper() {
    print_status "Installing hyprpaper..."

    # Detect package manager and install hyprpaper
    if command_exists "pacman"; then
        # Arch Linux
        print_status "Detected Arch Linux, installing hyprpaper with pacman..."
        if sudo pacman -S --noconfirm hyprpaper; then
            print_success "hyprpaper installed successfully"
            return 0
        else
            print_warning "Failed to install hyprpaper with pacman"
            return 1
        fi
    elif command_exists "apt"; then
        # Ubuntu/Debian - hyprpaper might not be in standard repos
        print_status "Detected Debian/Ubuntu, checking for hyprpaper..."
        if sudo apt update && sudo apt install -y hyprpaper 2>/dev/null; then
            print_success "hyprpaper installed successfully"
            return 0
        else
            print_warning "hyprpaper not available in apt repositories"
            print_status "Attempting to build from source..."
            install_hyprpaper_from_source
            return $?
        fi
    elif command_exists "dnf"; then
        # Fedora
        print_status "Detected Fedora, installing hyprpaper with dnf..."
        if sudo dnf install -y hyprpaper; then
            print_success "hyprpaper installed successfully"
            return 0
        else
            print_warning "Failed to install hyprpaper with dnf"
            return 1
        fi
    elif command_exists "zypper"; then
        # openSUSE
        print_status "Detected openSUSE, installing hyprpaper with zypper..."
        if sudo zypper install -y hyprpaper; then
            print_success "hyprpaper installed successfully"
            return 0
        else
            print_warning "Failed to install hyprpaper with zypper"
            return 1
        fi
    else
        print_warning "Unknown package manager, attempting to build hyprpaper from source..."
        install_hyprpaper_from_source
        return $?
    fi
}

# Function to build hyprpaper from source (fallback)
install_hyprpaper_from_source() {
    print_status "Building hyprpaper from source..."

    # Check for required build dependencies
    local missing_deps=()

    if ! command_exists "git"; then
        missing_deps+=("git")
    fi
    if ! command_exists "make"; then
        missing_deps+=("make")
    fi
    if ! command_exists "cmake"; then
        missing_deps+=("cmake")
    fi
    if ! command_exists "pkg-config"; then
        missing_deps+=("pkg-config")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing build dependencies for hyprpaper:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        print_error "Please install these dependencies and try again"
        return 1
    fi

    # Create temporary build directory
    local build_dir="/tmp/hyprpaper-build"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"

    # Clone and build hyprpaper
    if cd "$build_dir" && \
       git clone https://github.com/hyprwm/hyprpaper.git && \
       cd hyprpaper && \
       make all && \
       sudo make install; then
        print_success "hyprpaper built and installed from source"
        rm -rf "$build_dir"
        return 0
    else
        print_error "Failed to build hyprpaper from source"
        rm -rf "$build_dir"
        return 1
    fi
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

# Function to migrate configuration files
migrate_config() {
    local config_file="$1"
    local new_config_file="$2"
    local config_name="$3"

    if [ ! -f "$config_file" ]; then
        print_status "No existing $config_name found, using new defaults"
        return 0
    fi

    if [ ! -f "$new_config_file" ]; then
        print_warning "New $config_name template not found, keeping existing"
        return 0
    fi

    print_status "Migrating $config_name..."

    # Create temporary file for migration
    local temp_file="/tmp/gjtv_migration_$(basename "$config_file")"
    local migrated_file="${config_file}.migrated"

    # Start with existing config
    cp "$config_file" "$temp_file"

    # Process TOML migration
    if command -v python3 >/dev/null 2>&1; then
        python3 << EOF
import sys
import re
import os

def parse_toml_simple(content):
    """Simple TOML parser for basic key=value and [section] parsing"""
    data = {}
    current_section = None

    for line in content.split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue

        # Section header
        if line.startswith('[') and line.endswith(']'):
            current_section = line[1:-1].strip()
            if current_section not in data:
                data[current_section] = {}
            continue

        # Key-value pair
        if '=' in line:
            key, value = line.split('=', 1)
            key = key.strip().strip('"')
            value = value.strip().strip('"')

            if current_section:
                data[current_section][key] = value
            else:
                data[key] = value

    return data

def write_toml_simple(data, file_path):
    """Simple TOML writer"""
    with open(file_path, 'w') as f:
        # Write top-level keys first
        for key, value in data.items():
            if not isinstance(value, dict):
                if isinstance(value, str):
                    f.write(f'"{key}" = "{value}"\n')
                else:
                    f.write(f'"{key}" = {value}\n')

        # Write sections
        for section, values in data.items():
            if isinstance(values, dict):
                f.write(f'\n[{section}]\n')
                for key, value in values.items():
                    if isinstance(value, str):
                        f.write(f'"{key}" = "{value}"\n')
                    else:
                        f.write(f'"{key}" = {value}\n')

try:
    # Read existing config
    with open('$temp_file', 'r') as f:
        existing_content = f.read()

    # Read new config template
    with open('$new_config_file', 'r') as f:
        new_content = f.read()

    existing_data = parse_toml_simple(existing_content)
    new_data = parse_toml_simple(new_content)

    # Merge: keep existing values, add new fields, remove obsolete fields
    merged_data = {}

    # Copy structure from new config but preserve existing values
    for section, values in new_data.items():
        if isinstance(values, dict):
            merged_data[section] = {}
            for key, default_value in values.items():
                # Use existing value if available, otherwise use new default
                if section in existing_data and key in existing_data[section]:
                    merged_data[section][key] = existing_data[section][key]
                else:
                    merged_data[section][key] = default_value
        else:
            # Top-level key
            if section in existing_data:
                merged_data[section] = existing_data[section]
            else:
                merged_data[section] = values

    # Write migrated config
    write_toml_simple(merged_data, '$migrated_file')
    print("Migration completed successfully")

except Exception as e:
    print(f"Migration failed: {e}")
    sys.exit(1)
EOF

        if [ $? -eq 0 ] && [ -f "$migrated_file" ]; then
            # Migration successful
            create_backup "$config_file"
            mv "$migrated_file" "$config_file"
            print_success "Successfully migrated $config_name"
        else
            print_warning "Migration failed for $config_name, keeping existing"
        fi
    else
        # No Python3, do simple merge manually
        print_warning "Python3 not found, doing simple config merge for $config_name"

        # Extract new sections/keys that don't exist in old config
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[.*\]$ ]] || [[ "$line" =~ ^\".*\".*= ]]; then
                if ! grep -Fq "$line" "$config_file" 2>/dev/null; then
                    echo "$line" >> "$temp_file"
                fi
            fi
        done < "$new_config_file"

        create_backup "$config_file"
        mv "$temp_file" "$config_file"
        print_success "Basic merge completed for $config_name"
    fi

    # Cleanup
    rm -f "$temp_file" "$migrated_file"
}

# Function to check if config migration is needed
needs_migration() {
    local config_file="$1"
    local new_config_file="$2"

    if [ ! -f "$config_file" ]; then
        return 1  # No existing config, no migration needed
    fi

    if [ ! -f "$new_config_file" ]; then
        return 1  # No new config template
    fi

    # Check if new config has fields that existing doesn't have
    # Simple heuristic: compare line counts and look for new sections
    local existing_sections=$(grep -c '^\[' "$config_file" 2>/dev/null || echo 0)
    local new_sections=$(grep -c '^\[' "$new_config_file" 2>/dev/null || echo 0)

    if [ "$new_sections" -gt "$existing_sections" ]; then
        return 0  # Migration needed
    fi

    # Check for specific new fields we've added
    if ! grep -q "Cell Background Color\|Tab Active Color" "$config_file" 2>/dev/null; then
        return 0  # Migration needed for new color settings
    fi

    return 1  # No migration needed
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

    # Download to temporary files first for migration
    local temp_dir="/tmp/gjtv_new_configs"
    mkdir -p "$temp_dir"

    # Download main config
    if curl -fsSL "${RAW_CONTENT_URL}/config/config.toml" -o "$temp_dir/config.toml" 2>/dev/null; then
        if [ "$PRESERVE_CONFIG" = true ] && needs_migration "$GJTV_CONFIG_DIR/config.toml" "$temp_dir/config.toml"; then
            migrate_config "$GJTV_CONFIG_DIR/config.toml" "$temp_dir/config.toml" "config.toml"
        elif [ "$PRESERVE_CONFIG" = false ] || [ ! -f "$GJTV_CONFIG_DIR/config.toml" ]; then
            if [ -f "$GJTV_CONFIG_DIR/config.toml" ]; then
                create_backup "$GJTV_CONFIG_DIR/config.toml"
            fi
            mv "$temp_dir/config.toml" "$GJTV_CONFIG_DIR/config.toml"
        fi
    else
        print_warning "Failed to download config.toml, will be generated on first run"
    fi

    # Download settings config
    if curl -fsSL "${RAW_CONTENT_URL}/config/settings.toml" -o "$temp_dir/settings.toml" 2>/dev/null; then
        if [ "$PRESERVE_CONFIG" = true ] && needs_migration "$GJTV_CONFIG_DIR/settings.toml" "$temp_dir/settings.toml"; then
            migrate_config "$GJTV_CONFIG_DIR/settings.toml" "$temp_dir/settings.toml" "settings.toml"
        elif [ "$PRESERVE_CONFIG" = false ] || [ ! -f "$GJTV_CONFIG_DIR/settings.toml" ]; then
            if [ -f "$GJTV_CONFIG_DIR/settings.toml" ]; then
                create_backup "$GJTV_CONFIG_DIR/settings.toml"
            fi
            mv "$temp_dir/settings.toml" "$GJTV_CONFIG_DIR/settings.toml"
        fi
    else
        print_warning "Failed to download settings.toml, will be generated on first run"
    fi

    # Download keymap config
    if curl -fsSL "${RAW_CONTENT_URL}/config/keymap.toml" -o "$temp_dir/keymap.toml" 2>/dev/null; then
        if [ "$PRESERVE_CONFIG" = true ] && needs_migration "$GJTV_CONFIG_DIR/keymap.toml" "$temp_dir/keymap.toml"; then
            migrate_config "$GJTV_CONFIG_DIR/keymap.toml" "$temp_dir/keymap.toml" "keymap.toml"
        elif [ "$PRESERVE_CONFIG" = false ] || [ ! -f "$GJTV_CONFIG_DIR/keymap.toml" ]; then
            if [ -f "$GJTV_CONFIG_DIR/keymap.toml" ]; then
                create_backup "$GJTV_CONFIG_DIR/keymap.toml"
            fi
            mv "$temp_dir/keymap.toml" "$GJTV_CONFIG_DIR/keymap.toml"
        fi
    else
        print_warning "Failed to download keymap.toml, will be generated on first run"
    fi

    # Download theme config
    if curl -fsSL "${RAW_CONTENT_URL}/config/theme.toml" -o "$temp_dir/theme.toml" 2>/dev/null; then
        if [ "$PRESERVE_CONFIG" = true ] && needs_migration "$GJTV_CONFIG_DIR/theme.toml" "$temp_dir/theme.toml"; then
            migrate_config "$GJTV_CONFIG_DIR/theme.toml" "$temp_dir/theme.toml" "theme.toml"
        elif [ "$PRESERVE_CONFIG" = false ] || [ ! -f "$GJTV_CONFIG_DIR/theme.toml" ]; then
            if [ -f "$GJTV_CONFIG_DIR/theme.toml" ]; then
                create_backup "$GJTV_CONFIG_DIR/theme.toml"
            fi
            mv "$temp_dir/theme.toml" "$GJTV_CONFIG_DIR/theme.toml"
        fi
    else
        print_warning "Failed to download theme.toml, will be generated on first run"
    fi

    # Cleanup temp directory
    rm -rf "$temp_dir"

    print_success "Configuration files processed"
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

    # Download GJTV wallpaper
    if curl -fsSL "${RAW_CONTENT_URL}/assets/GJTV.png" -o "$GJTV_CONFIG_DIR/assets/GJTV.png" 2>/dev/null; then
        print_success "Downloaded GJTV wallpaper"
    else
        print_warning "Failed to download GJTV wallpaper"
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

# Configure hyprpaper wallpaper
configure_hyprpaper() {
    print_status "Configuring hyprpaper wallpaper..."

    local wallpaper_path="$GJTV_CONFIG_DIR/assets/GJTV.png"
    local hyprpaper_conf="$HYPRLAND_CONFIG_DIR/hyprpaper.conf"

    # Check if GJTV wallpaper exists
    if [ ! -f "$wallpaper_path" ]; then
        print_warning "GJTV wallpaper not found at $wallpaper_path"
        return 1
    fi

    # Check if hyprpaper config already exists
    if [ -f "$hyprpaper_conf" ]; then
        # Check if GJTV wallpaper is already configured
        if grep -q "GJTV.png" "$hyprpaper_conf"; then
            print_success "GJTV wallpaper already configured in hyprpaper"
            return 0
        fi

        # Backup existing config
        create_backup "$hyprpaper_conf"

        # Add GJTV wallpaper to existing config
        echo "" >> "$hyprpaper_conf"
        echo "# GJTV Wallpaper" >> "$hyprpaper_conf"
        echo "preload = $wallpaper_path" >> "$hyprpaper_conf"

        # Get monitor names and set wallpaper for all monitors
        if command_exists "hyprctl"; then
            # Use hyprctl to get monitor names
            local monitors=$(hyprctl monitors -j 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
            if [ -n "$monitors" ]; then
                for monitor in $monitors; do
                    echo "wallpaper = $monitor,$wallpaper_path" >> "$hyprpaper_conf"
                done
            else
                # Fallback to common monitor names
                echo "wallpaper = ,$wallpaper_path" >> "$hyprpaper_conf"
            fi
        else
            # Fallback if hyprctl is not available
            echo "wallpaper = ,$wallpaper_path" >> "$hyprpaper_conf"
        fi

        print_success "Added GJTV wallpaper to existing hyprpaper configuration"
    else
        # Create new hyprpaper config
        cat > "$hyprpaper_conf" << EOF
# Hyprpaper Configuration with GJTV Wallpaper
# Generated by GJTV installer

# Preload wallpaper
preload = $wallpaper_path

# Set wallpaper for all monitors
wallpaper = ,$wallpaper_path

# Enable IPC for runtime changes
ipc = on
EOF
        print_success "Created hyprpaper configuration with GJTV wallpaper"
    fi

    return 0
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

        # Add hyprpaper source if not already present
        if ! grep -q "source.*hyprpaper.conf" "$hyprland_conf" && [ -f "$HYPRLAND_CONFIG_DIR/hyprpaper.conf" ]; then
            echo "source = ~/.config/hypr/hyprpaper.conf" >> "$hyprland_conf"
            print_success "Added hyprpaper configuration to Hyprland config"
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

    # Setup hyprpaper if available
    if check_hyprpaper; then
        print_success "hyprpaper is already installed"
        configure_hyprpaper
    else
        print_status "hyprpaper not found, attempting to install..."
        if install_hyprpaper; then
            configure_hyprpaper
        else
            print_warning "Could not install hyprpaper, wallpaper setup skipped"
            print_status "You can manually install hyprpaper later and run the installer again"
        fi
    fi

    print_success "Hyprland integration configured"
}

# Configure Hyprland without hyprpaper
configure_hyprland_without_hyprpaper() {
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

    print_success "Hyprland integration configured (hyprpaper skipped)"
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

    # For updates, always preserve existing configurations by default
    PRESERVE_CONFIG=true

    download_configs
    install_config
    configure_hyprland

    print_success "GJTV updated successfully with configuration migration"
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
    echo "Usage: $0 [command] [options] [version]"
    echo ""
    echo "Commands:"
    echo "  install [version]   Install GJTV and configure Hyprland (default)"
    echo "  update [version]    Update existing GJTV installation"
    echo "  uninstall           Remove GJTV and its configuration"
    echo "  status              Show installation status"
    echo "  help                Show this help message"
    echo ""
    echo "Options:"
    echo "  --preserve-config   Preserve existing config files and migrate them"
    echo "  --overwrite-config  Overwrite config files with new defaults"
    echo "  --skip-hyprpaper    Skip hyprpaper installation and wallpaper setup"
    echo ""
    echo "Versions:"
    echo "  latest              Install latest stable release (default)"
    echo "  v1.0.0              Install specific version"
    echo "  beta                Install latest beta release"
    echo ""
    echo "Examples:"
    echo "  $0                           Install latest version"
    echo "  $0 install v1.0.0            Install specific version"
    echo "  $0 update                    Update to latest version with config migration"
    echo "  $0 update beta               Update to latest beta"
    echo "  $0 install --preserve-config Preserve existing configurations"
    echo "  $0 install --overwrite-config Use new default configurations"
    echo ""
    echo "Configuration Migration:"
    echo "  - By default, updates preserve existing configurations"
    echo "  - New installs use fresh configurations unless --preserve-config is used"
    echo "  - Migration adds new settings while keeping your customizations"
    echo "  - Obsolete settings are automatically removed"
    echo "  - Backups are always created before changes"
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
    echo "Config preservation: $([ "$PRESERVE_CONFIG" = true ] && echo "enabled" || echo "disabled")"
    echo "Hyprpaper setup: $([ "$SKIP_HYPRPAPER" = true ] && echo "skipped" || echo "enabled")"
    echo ""

    check_dependencies
    download_gjtv "$version"
    download_configs
    download_assets
    install_binary
    install_config
    if [ "$SKIP_HYPRPAPER" = false ]; then
        configure_hyprland
    else
        # Configure Hyprland without hyprpaper setup
        print_status "Configuring Hyprland integration (skipping hyprpaper)..."
        configure_hyprland_without_hyprpaper
    fi
    create_desktop_entry

    echo ""
    print_success "🎉 GJTV installation completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Restart Hyprland or reload configuration: hyprctl reload"
    echo "2. Press Home key to open GJTV"
    echo "3. Press M key to access Settings tab"
    echo "4. Navigate to Settings tab (press M key) to customize:"
    echo "   - Theme: New cell colors, tab colors, and fixed icon tinting"
    echo "   - Cell Appearance: Customize app cell size, corners, shadows"
    echo "   - Tab Appearance: Adjust tab styling and positioning"
    echo "   - Animations: Enable dice roll and breathing animations"
    echo "   - Text Styling: Configure fonts and text effects"
    echo "5. Edit configuration files in: $GJTV_CONFIG_DIR/"
    echo "   - config.toml: Application definitions"
    echo "   - settings.toml: Visual and behavior settings (with new color options)"
    echo "   - keymap.toml: Key binding configuration"
    echo "   - theme.toml: Color themes and styling"
    echo "6. Wallpaper: GJTV wallpaper has been set up with hyprpaper"
    echo "   - Location: $GJTV_CONFIG_DIR/assets/GJTV.png"
    echo "   - Config: ~/.config/hypr/hyprpaper.conf"
    echo ""
    if [ "$PRESERVE_CONFIG" = true ]; then
        echo "Configuration files were migrated to preserve your settings."
        echo "Check .backup files if you need to restore previous configurations."
        echo ""
    fi
    echo "For help: $0 help"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --preserve-config)
                PRESERVE_CONFIG=true
                shift
                ;;
            --overwrite-config)
                PRESERVE_CONFIG=false
                shift
                ;;
            --skip-hyprpaper)
                SKIP_HYPRPAPER=true
                shift
                ;;
            install|update|uninstall|status|help|--help|-h)
                COMMAND="$1"
                shift
                ;;
            latest|beta|v*.*)
                VERSION="$1"
                shift
                ;;
            *)
                if [ -z "$COMMAND" ]; then
                    COMMAND="$1"
                elif [ -z "$VERSION" ]; then
                    VERSION="$1"
                else
                    print_error "Unknown argument: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Set defaults
    COMMAND="${COMMAND:-install}"
    VERSION="${VERSION:-latest}"
}

# Parse arguments
parse_args "$@"

# Main script logic
case "$COMMAND" in
    "install")
        install_gjtv "$VERSION"
        ;;
    "update")
        update_installation "$VERSION"
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
        print_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac
