#!/usr/bin/env bash
# Headless Fusion 360 Installer
# Runs the upstream installer automatically without user interaction

set -euo pipefail

# Configuration
INSTALL_DIR="${FUSION360_INSTALL_DIR:-$HOME/.autodesk_fusion}"
STATE_FILE="$INSTALL_DIR/.install-state"
LOG_DIR="$INSTALL_DIR/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
INSTALL_LOG="$LOG_DIR/install-$TIMESTAMP.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[fusion360-install]${NC} $1" | tee -a "$INSTALL_LOG"
}

warn() {
    echo -e "${YELLOW}[fusion360-install]${NC} $1" | tee -a "$INSTALL_LOG"
}

error() {
    echo -e "${RED}[fusion360-install]${NC} $1" | tee -a "$INSTALL_LOG" >&2
}

info() {
    echo -e "${CYAN}[fusion360-install]${NC} $1" | tee -a "$INSTALL_LOG"
}

# Parse arguments
FORCE_INSTALL=false
USE_BACKUP=false
CREATE_BACKUP=false
for arg in "$@"; do
    case $arg in
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        --use-backup)
            USE_BACKUP=true
            shift
            ;;
        --create-backup)
            CREATE_BACKUP=true
            shift
            ;;
    esac
done

# Function to configure graphics settings for optimal Linux performance
configure_graphics_settings() {
    local OPTIONS_DIR="$INSTALL_DIR/wineprefixes/default/drive_c/users/$USER/AppData/Roaming/Autodesk/Neutron Platform/Options"
    local OPTIONS_FILE="$OPTIONS_DIR/NMachineSpecificOptions.xml"
    
    # Wait a moment for Wine to finish writing files
    sleep 2
    
    # Check if options directory exists, if not create it
    if [[ ! -d "$OPTIONS_DIR" ]]; then
        warn "Options directory not found, creating: $OPTIONS_DIR"
        mkdir -p "$OPTIONS_DIR"
    fi
    
    # If options file exists, update it; otherwise create it
    if [[ -f "$OPTIONS_FILE" ]]; then
        log "Updating existing graphics settings..."
        
        # Convert from UTF-16LE to UTF-8, modify, then convert back
        local TEMP_FILE=$(mktemp)
        
        if iconv -f UTF-16LE -t UTF-8 "$OPTIONS_FILE" > "$TEMP_FILE" 2>/dev/null; then
            # Update the three graphics settings using sed
            sed -i 's/<driverOptionId [^>]*Value="[^"]*"/<driverOptionId ToolTip="The driver used to display the graphics" UserName="Graphics driver" Value="VirtualDeviceGLCore"/g' "$TEMP_FILE"
            sed -i 's/<ChromiumGraphicsBackend [^>]*Value="[^"]*"/<ChromiumGraphicsBackend ToolTip="Override the ANGLE backend used by embedded browser frames" UserName="Chromium Graphics Backend" Value="vulkan"/g' "$TEMP_FILE"
            sed -i 's/<graphicsApiOptionId [^>]*Value="[^"]*"/<graphicsApiOptionId ToolTip="Controls the graphics API used to render the User Interface. This has no effect on the 3D modeling canvas." UserName="Qt Rendering Hardware Interface API" Value="OpenGL"/g' "$TEMP_FILE"
            
            # If settings don't exist, add them to BootstrapOptionsGroup
            if ! grep -q "driverOptionId" "$TEMP_FILE"; then
                sed -i 's|<BootstrapOptionsGroup|<BootstrapOptionsGroup SchemaVersion="2" ToolTip="Special preferences that require the application to be restarted after a change." UserName="Bootstrap">\n    <driverOptionId ToolTip="The driver used to display the graphics" UserName="Graphics driver" Value="VirtualDeviceGLCore"/>|' "$TEMP_FILE"
            fi
            
            if ! grep -q "ChromiumGraphicsBackend" "$TEMP_FILE"; then
                sed -i 's|<CompatibilityGroup|<CompatibilityGroup SchemaVersion="2" ToolTip="Miscellaneous options..." UserName="Compatibility \&amp; Troubleshooting">\n    <ChromiumGraphicsBackend ToolTip="Override the ANGLE backend used by embedded browser frames" UserName="Chromium Graphics Backend" Value="vulkan"/>|' "$TEMP_FILE"
            fi
            
            if ! grep -q "graphicsApiOptionId" "$TEMP_FILE"; then
                sed -i 's|</CompatibilityGroup>|    <graphicsApiOptionId ToolTip="Controls the graphics API used to render the User Interface. This has no effect on the 3D modeling canvas." UserName="Qt Rendering Hardware Interface API" Value="OpenGL"/>\n  </CompatibilityGroup>|' "$TEMP_FILE"
            fi
            
            # Convert back to UTF-16LE
            iconv -f UTF-8 -t UTF-16LE "$TEMP_FILE" > "$OPTIONS_FILE"
            rm -f "$TEMP_FILE"
            
            log "Graphics settings configured: Vulkan + OpenGL + VirtualDeviceGLCore"
        else
            warn "Could not read options file, will create new one"
            create_default_options_file "$OPTIONS_FILE"
        fi
    else
        log "Creating graphics settings file..."
        create_default_options_file "$OPTIONS_FILE"
    fi
}

# Function to create default options file with optimal graphics settings
create_default_options_file() {
    local file="$1"
    
    cat > "$file.utf8" <<'XMLEOF'
<?xml version="1.0" encoding="UTF-16" standalone="no" ?>
<OptionGroups>
  <BootstrapOptionsGroup SchemaVersion="2" ToolTip="Special preferences that require the application to be restarted after a change." UserName="Bootstrap">
    <driverOptionId ToolTip="The driver used to display the graphics" UserName="Graphics driver" Value="VirtualDeviceGLCore"/>
  </BootstrapOptionsGroup>
  <CompatibilityGroup SchemaVersion="2" ToolTip="Miscellaneous options which may enable Fusion to perform better on certain hardware or network configurations, and to help diagnose undesirable application behavior." UserName="Compatibility &amp; Troubleshooting">
    <ChromiumGraphicsBackend ToolTip="Override the ANGLE backend used by embedded browser frames" UserName="Chromium Graphics Backend" Value="vulkan"/>
    <graphicsApiOptionId ToolTip="Controls the graphics API used to render the User Interface. This has no effect on the 3D modeling canvas." UserName="Qt Rendering Hardware Interface API" Value="OpenGL"/>
  </CompatibilityGroup>
</OptionGroups>
XMLEOF
    
    # Convert to UTF-16LE
    iconv -f UTF-8 -t UTF-16LE "$file.utf8" > "$file"
    rm -f "$file.utf8"
    
    log "Created default graphics settings: Vulkan + OpenGL + VirtualDeviceGLCore"
}

# Check if already installed
if [[ -f "$STATE_FILE" ]] && [[ "$FORCE_INSTALL" == "false" ]]; then
    warn "Fusion 360 is already installed"
    warn "Use --force to reinstall"
    exit 0
fi

# Create directories
mkdir -p "$LOG_DIR"

# Check for Wine prefix backup (development aid)
WINEPREFIX_BACKUP="$INSTALL_DIR/wineprefixes/default.backup"
if [[ -d "$WINEPREFIX_BACKUP" ]] && [[ "$USE_BACKUP" == "true" ]]; then
    log "Found Wine prefix backup, restoring..."
    rm -rf "$INSTALL_DIR/wineprefixes/default"
    cp -a "$WINEPREFIX_BACKUP" "$INSTALL_DIR/wineprefixes/default"
    log "Wine prefix restored from backup"
    log "Skipping Wine setup, jumping to Fusion installation..."
    SKIP_WINE_SETUP=true
elif [[ -d "$WINEPREFIX_BACKUP" ]] && [[ "$USE_BACKUP" == "false" ]]; then
    info "Wine prefix backup available at: $WINEPREFIX_BACKUP"
    info "Use --use-backup to skip Wine setup (faster for development)"
    SKIP_WINE_SETUP=false
else
    SKIP_WINE_SETUP=false
fi

log "Starting headless Fusion 360 installation..."
log "Installation directory: $INSTALL_DIR"
log "Log file: $INSTALL_LOG"

# Environment variables to bypass interactive prompts
export DEBIAN_FRONTEND=noninteractive
export WINEPREFIX="$INSTALL_DIR/wineprefixes/default"
export WINEDEBUG="-all"

# Add PATH with all dependencies
export PATH="@bin_path@:$PATH"

# Create a patched version of the installer that auto-answers prompts
PATCHED_INSTALLER="$INSTALL_DIR/installer-patched.sh"
rm -f "$PATCHED_INSTALLER"
cp "@installer@" "$PATCHED_INSTALLER"
chmod +x "$PATCHED_INSTALLER"

# Patch the installer to skip interactive prompts
log "Patching installer for headless operation..."

# Replace read -p prompts with automatic yes
sed -i 's/read -p [^;]*yn$/yn=y/' "$PATCHED_INSTALLER"
sed -i 's/read -p [^;]*gpu_choice$/gpu_choice=1/' "$PATCHED_INSTALLER"
sed -i 's/read -p [^;]*wine_repo_choice$/wine_repo_choice=1/' "$PATCHED_INSTALLER"
sed -i 's/read -p [^;]*choice$/choice=n/' "$PATCHED_INSTALLER"  # Skip Firefox snap prompt
sed -i 's/read -p [^;]*uninstall_option$/uninstall_option=1/' "$PATCHED_INSTALLER"

# Fix Qt6WebEngineCore.dll.7z path - copy from downloads to Wine prefix Downloads before extraction
# The installer downloads it to $SELECTED_DIRECTORY/downloads/ but tries to extract from Wine C:\users\$USER\Downloads
# We need to add a copy step before the 7z extraction command
sed -i '/wine.*7z\.exe.*x.*Qt6WebEngineCore\.dll\.7z/i \    cp "$SELECTED_DIRECTORY/downloads/Qt6WebEngineCore.dll.7z" "$SELECTED_DIRECTORY/wineprefixes/default/drive_c/users/$USER/Downloads/Qt6WebEngineCore.dll.7z"' "$PATCHED_INSTALLER"

# Fix Qt6WebEngineCore.dll patching function - after extraction, the DLL is in Wine Downloads, not host downloads
# Change: cp -f "$SELECTED_DIRECTORY/downloads/Qt6WebEngineCore.dll" ...
# To:     cp -f "$SELECTED_DIRECTORY/wineprefixes/default/drive_c/users/$USER/Downloads/Qt6WebEngineCore.dll" ...
sed -i 's|cp -f "\$SELECTED_DIRECTORY/downloads/Qt6WebEngineCore\.dll" "\$QT6_WEBENGINECORE_DIR/Qt6WebEngineCore\.dll"|cp -f "$SELECTED_DIRECTORY/wineprefixes/default/drive_c/users/$USER/Downloads/Qt6WebEngineCore.dll" "$QT6_WEBENGINECORE_DIR/Qt6WebEngineCore.dll"|' "$PATCHED_INSTALLER"

# # Disable the second run of FusionClientInstaller.exe which auto-launches Fusion360
# # This is the line that runs the installer a second time and causes interactive launch
# sed -i '/timeout -k 5m 1m wine.*FusionClientInstaller\.exe.*--quiet/s/^/    # /' "$PATCHED_INSTALLER"

# Disable the run_wine_autodesk_fusion call that launches Fusion after installation
# Only comment out the function call, not the function definition
sed -i '/run_wine_autodesk_fusion/{/function/!s/^/    # /}' "$PATCHED_INSTALLER"

# Disable the xdg-open sponsors link
sed -i '/xdg-open.*cryinkfly\.com\/sponsors/s/^/    # /' "$PATCHED_INSTALLER"

# Inject backup creation right before autodesk_fusion_run_install_client
if [[ "$CREATE_BACKUP" == "true" ]] || [[ "$SKIP_WINE_SETUP" == "false" && ! -d "$WINEPREFIX_BACKUP" ]]; then
    log "Injecting Wine prefix backup into installer (before FusionClientInstaller runs)..."
    
    # Create temporary file with backup code
    cat > /tmp/backup_inject.txt << 'EOF'
    # Create Wine prefix backup before running FusionClientInstaller
    if [ ! -d "$SELECTED_DIRECTORY/wineprefixes/default.backup" ]; then
        echo -e "${GREEN}Creating Wine prefix backup...${NOCOLOR}"
        rm -rf "$SELECTED_DIRECTORY/wineprefixes/default.backup"
        cp -a "$SELECTED_DIRECTORY/wineprefixes/default" "$SELECTED_DIRECTORY/wineprefixes/default.backup"
        echo -e "${GREEN}Wine prefix backup created at: $SELECTED_DIRECTORY/wineprefixes/default.backup${NOCOLOR}"
        echo -e "${YELLOW}Next time use --use-backup to skip Wine setup${NOCOLOR}"
    fi

EOF
    
    # Insert the backup code before autodesk_fusion_run_install_client
    sed -i '/function autodesk_fusion_run_install_client/r /tmp/backup_inject.txt' "$PATCHED_INSTALLER"
    rm -f /tmp/backup_inject.txt
fi

log "Running installer..."

# Run the patched installer (may exit with error code even on success)
yes | "$PATCHED_INSTALLER" --install --default 2>&1 | tee -a "$INSTALL_LOG" || true

log "Installer script completed"

# Check if installation was successful by verifying Fusion360.exe exists
# The installer script may return non-zero even when installation succeeds
log "Verifying installation..."
FUSION_EXE=$(find "$INSTALL_DIR/wineprefixes/default/drive_c/Program Files/Autodesk/webdeploy/production" \
    -name "Fusion360.exe" 2>/dev/null | head -n 1)

if [[ -n "$FUSION_EXE" ]] && [[ -f "$FUSION_EXE" ]]; then
    log "Installation completed successfully!"
    log "Fusion360.exe found at: $FUSION_EXE"
    
    # Configure graphics settings
    log "Configuring graphics settings for optimal Linux performance..."
    configure_graphics_settings
    
    # Create installation state marker
    log "Creating installation state marker..."
    cat > "$STATE_FILE" <<EOF
INSTALLED_AT=$(date -Iseconds)
VERSION=@version@
INSTALLER_HASH=@installer_hash@
WINE_VERSION=$(wine --version 2>/dev/null || echo "unknown")
LOG_FILE=$INSTALL_LOG
EOF

    log "State file created: $STATE_FILE"
    
    # Cleanup
    rm -f "$PATCHED_INSTALLER"

    info "Fusion 360 installation completed successfully!"
    info "You should now launch Fusion 360 and login using the `fusion login` command."
    
    exit 0
else
    error "Installation failed!"
    error "Fusion360.exe not found after installation"
    error "Check the log file: $INSTALL_LOG"
    
    # Cleanup
    rm -f "$PATCHED_INSTALLER"
    
    exit 1
fi
