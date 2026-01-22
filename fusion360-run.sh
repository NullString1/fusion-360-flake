#!/usr/bin/env bash
# Fusion 360 Runner - Just launches Fusion 360
# Used by the CLI when installation is confirmed

set -euo pipefail

# Configuration
INSTALL_DIR="${FUSION360_INSTALL_DIR:-$HOME/.autodesk_fusion}"
WINEPREFIX="$INSTALL_DIR/wineprefixes/default"

# Find Fusion360.exe (path contains a hash directory)
FUSION_EXE=$(find "$INSTALL_DIR/wineprefixes/default/drive_c/Program Files/Autodesk/webdeploy/production" \
    -name "Fusion360.exe" 2>/dev/null | head -n 1)

if [[ -z "$FUSION_EXE" ]] || [[ ! -f "$FUSION_EXE" ]]; then
    echo "Error: Fusion360.exe not found" >&2
    exit 1
fi

# Environment setup
export WINEPREFIX="$WINEPREFIX"
export WINEDEBUG="-all"
export PATH="@bin_path@:$PATH"

# Launch Fusion 360
exec wine "$FUSION_EXE" "$@"
