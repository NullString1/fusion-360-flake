#!/usr/bin/env bash
# Fusion 360 CLI - Unified command interface
# Usage: fusion [install|update|uninstall|run]

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[fusion]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[fusion]${NC} $1"
}

error() {
    echo -e "${RED}[fusion]${NC} $1" >&2
}

info() {
    echo -e "${CYAN}[fusion]${NC} $1"
}

# Show help
show_help() {
    cat <<EOF
Fusion 360 for Linux - Unified CLI

Usage: fusion [COMMAND] [OPTIONS]

Commands:
  (none)      Check if installed and run Fusion 360 (default)
  run         Explicitly run Fusion 360 (same as no command)
  install     Install Fusion 360 (headless, automatic)
  update      Update/reinstall Fusion 360
  uninstall   Remove Fusion 360 installation
  login <url> Authenticate with Autodesk using signin URL
  
Options:
  --help, -h  Show this help message
  --force     Force reinstall (with install/update)
  
Examples:
  fusion                  # Check if installed, run if available
  fusion install          # Install Fusion 360 headlessly
  fusion update           # Update to latest version
  fusion uninstall        # Remove installation
  fusion login <url>      # Sign in with Autodesk authentication URL
  
Installation Directory:
  Default: ~/.autodesk_fusion
  Override with: FUSION360_INSTALL_DIR=<path>

For more information, visit:
  https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux
EOF
}

# Configuration
INSTALL_DIR="${FUSION360_INSTALL_DIR:-$HOME/.autodesk_fusion}"
STATE_FILE="$INSTALL_DIR/.install-state"

# Check if installed
is_installed() {
    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi
    
    # Also verify Fusion360.exe exists (path has hash directory)
    local fusion_exe=$(find "$INSTALL_DIR/wineprefixes/default/drive_c/Program Files/Autodesk/webdeploy/production" \
        -name "Fusion360.exe" 2>/dev/null | head -n 1)
    
    [[ -n "$fusion_exe" ]] && [[ -f "$fusion_exe" ]]
}

# Get version info
get_installed_version() {
    if [[ -f "$STATE_FILE" ]]; then
        grep "^VERSION=" "$STATE_FILE" | cut -d= -f2
    else
        echo "not installed"
    fi
}

# Parse command
COMMAND="${1:-}"
shift || true

# Handle help
if [[ "$COMMAND" == "--help" ]] || [[ "$COMMAND" == "-h" ]]; then
    show_help
    exit 0
fi

# Execute command
case "$COMMAND" in
    ""|run)
        # Default: check and run
        if is_installed; then
            info "Fusion 360 $(get_installed_version) is installed"
            log "Launching Fusion 360..."
            exec "@out@/bin/fusion360-run" "$@"
        else
            warn "Fusion 360 is not installed"
            echo ""
            echo "To install, run:"
            info "  fusion install"
            echo ""
            exit 1
        fi
        ;;
    
    install)
        if is_installed && [[ "$*" != *"--force"* ]]; then
            warn "Fusion 360 $(get_installed_version) is already installed"
            echo ""
            echo "To reinstall, run:"
            info "  fusion install --force"
            echo ""
            echo "To update, run:"
            info "  fusion update"
            exit 0
        fi
        
        log "Installing Fusion 360..."
        exec "@out@/bin/fusion360-install" "$@"
        ;;
    
    update)
        log "Updating Fusion 360..."
        exec "@out@/bin/fusion360-install" --force "$@"
        ;;
    
    login)
        # Handle Autodesk signin URL
        if [[ -z "${1:-}" ]]; then
            error "Login URL required"
            echo ""
            echo -e "Usage: ${CYAN}fusion login <url>${NC}"
            echo ""
            echo "Example:"
            info "  fusion login \"adskidmgr:/login?code=...\""
            exit 1
        fi
        
        if ! is_installed; then
            error "Fusion 360 is not installed"
            echo ""
            echo "Install Fusion 360 first:"
            info "  fusion install"
            exit 1
        fi
        
        # Find AdskIdentityManager.exe (path contains a hash directory)
        log "Locating AdskIdentityManager.exe..."
        ADSK_ID_MGR=$(find "$INSTALL_DIR/wineprefixes/default/drive_c/Program Files/Autodesk/webdeploy/production" \
            -name "AdskIdentityManager.exe" 2>/dev/null | head -n 1)
        
        if [[ -z "$ADSK_ID_MGR" ]] || [[ ! -f "$ADSK_ID_MGR" ]]; then
            error "AdskIdentityManager.exe not found"
            warn "Searched in: $INSTALL_DIR/wineprefixes/default/drive_c/Program Files/Autodesk/webdeploy/production"
            exit 1
        fi
        
        log "Found: $ADSK_ID_MGR"
        log "Authenticating with Autodesk..."
        
        # Set up Wine environment
        export WINEPREFIX="$INSTALL_DIR/wineprefixes/default"
        export WINEDEBUG="-all"
        export PATH="@bin_path@:$PATH"
        
        # Run the identity manager with the signin URL
        wine "$ADSK_ID_MGR" "$1"
        ;;
    
    uninstall)
        if ! is_installed; then
            warn "Fusion 360 is not installed"
            exit 0
        fi
        
        echo -e "${YELLOW}This will remove Fusion 360 from: $INSTALL_DIR${NC}"
        read -p "Are you sure? [y/N] " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Uninstalling Fusion 360..."
            rm -rf "$INSTALL_DIR"
            log "Fusion 360 has been uninstalled"
        else
            info "Uninstall cancelled"
        fi
        ;;
    
    --help|-h)
        show_help
        ;;
    
    *)
        error "Unknown command: $COMMAND"
        echo ""
        echo -e "Run '${CYAN}fusion --help${NC}' for usage information"
        exit 1
        ;;
esac
