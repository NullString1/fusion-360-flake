# Fusion 360 for NixOS

A NixOS flake for running Autodesk Fusion 360 on Linux using Wine, with a streamlined command-line interface and headless installation support.

## Overview

This project provides a Nix-based wrapper around the excellent [Autodesk Fusion 360 for Linux](https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux) installer by [cryinkfly](https://cryinkfly.com/sponsors/). It packages the installation and runtime components into a NixOS flake for easier integration into NixOS systems and declarative workflows.

### Key Features

- **Headless Installation**: Automatic, non-interactive installation process, just run `fusion install`
- **Unified CLI**: Single `fusion` command for all operations
- **Development Shell**: Pre-configured environment with all dependencies

## Installation

### Using Nix Flakes
If Fusion360 is already installed in the expected location, it will be launched, otherwise it will be installed first. 

Note: You may still need to auth manually if the mime launch doesn't work. See [Authentication](#authentication)
```bash
nix run github:nullstring1/fusion-360-flake
```

### Development Shell

Enter a development environment with all dependencies:

```bash
nix develop
```

This provides:
- Wine and Winetricks
- All required system utilities
- The `fusion` CLI command

## Usage

The `fusion` command provides a unified interface for all Fusion 360 operations:

```bash
fusion                 # Check if installed and run Fusion 360
fusion install         # Install Fusion 360 (headless, automatic)
fusion run             # Run Fusion 360
fusion update          # Update/reinstall Fusion 360
fusion uninstall       # Remove installation
fusion login <url>     # Authenticate with Autodesk using signin URL
fusion --help          # Show all commands
```

### Installation Options

```bash
fusion install --force           # Force reinstall
fusion install --use-backup      # Restore from backup
fusion install --create-backup   # Create backup before install
```

## Authentication

After installing Fusion 360, you'll need to authenticate with your Autodesk account. Due to limitations with the mime setup, the authentication flow may require a workaround:

### Login Steps

1. **Launch Fusion 360**:
   ```bash
   fusion
   ```

2. **Click Login** in the Fusion 360 window

3. **Sign in** using your browser when the Autodesk login page opens

4. **Inspect the Launch Button**:
   - After signing in, you'll see a "Launch" or "Open" button
   - Right-click on the button and select "Inspect Element" (or "Inspect")
   
5. **Copy the Authentication URL**:
   - Look at the HTML element in the developer tools
   - Find the URL inside the element (it will start with `adskidmgr://`)
   - Copy the entire URL

6. **Authenticate via CLI**:
   ```bash
   fusion login "adskidmgr://..."
   ```
   Replace `adskidmgr://...` with the URL you copied

After running the login command, Fusion 360 should authenticate and launch successfully.

## Project Structure

```
.
├── flake.nix                          # Nix flake definition
├── package.nix                        # Package derivation
├── fusion-cli.sh                      # Unified CLI interface
├── fusion360-installer-headless.sh    # Headless installer wrapper
├── fusion360-run.sh                   # Runtime launcher
└── locale/                            # Translation files (13 languages)
```

## How It Works

1. **Flake Configuration**: Downloads the original installer from cryinkfly's repository
2. **Headless Wrapper**: Automates the installation process without GUI interaction
3. **Runtime Environment**: Configures Wine prefix and launches Fusion 360
4. **CLI Interface**: Provides a unified command for all operations

## Installation Location

By default, Fusion 360 is installed to:
```
$HOME/.autodesk_fusion/
├── wineprefixes/
│   └── default/           # Wine prefix for Fusion 360
├── logs/                  # Installation and runtime logs
├── downloads/             # Downloaded installers and extensions
└── .install-state         # Installation state tracking
```

## Requirements

- NixOS or Nix with flakes enabled
- x86_64 Linux system
- Active internet connection for installation
- Autodesk account for authentication

## Configuration

Set the `FUSION360_INSTALL_DIR` environment variable to change the installation directory:

```bash
export FUSION360_INSTALL_DIR=/custom/path
fusion install
```

## Troubleshooting

### View Installation Logs

```bash
cat ~/.autodesk_fusion/logs/install-*.log
```

### View Runtime Logs

```bash
cat ~/.autodesk_fusion/logs/run-*.log
```

### Clean Reinstall

```bash
fusion uninstall
fusion install --force
```

## Modifications to Original Installer

This wrapper applies several patches to the original cryinkfly installer to enable headless operation and fix compatibility issues:

### Headless Installation Patches

1. **Automated Prompts**: All interactive `read -p` prompts are automatically answered:
   - Installation confirmation: auto-yes
   - GPU choice: defaults to option 1
   - Wine repository: defaults to option 1
   - Firefox snap: skipped

2. **Qt6WebEngineCore.dll Path Fix**: The installer downloads `Qt6WebEngineCore.dll.7z` to the host downloads directory but expects it in Wine's `C:\users\$USER\Downloads`. Added a copy step before extraction.

3. **Qt6WebEngineCore.dll Patch Fix**: After extraction, the DLL is in Wine's Downloads folder, not the host downloads folder. Updated the copy path in the patching function.

4. **Disabled Auto-Launch**: Commented out the `run_wine_autodesk_fusion` function call that automatically launches Fusion 360 after installation, allowing for headless completion.

5. **Disabled Browser Opening**: Commented out `xdg-open` calls for sponsorship links to prevent browser windows during headless installation.

6. **MIME Handler Management**: Disabled the installer's MIME handler setup since the flake creates its own `adskidmgr-opener.desktop` file in the Nix store (the installer can't write to read-only locations).

### Graphics Optimization

Added automatic graphics settings configuration for optimal Linux performance:
- **Graphics Driver**: Set to `VirtualDeviceGLCore`. You may have better performance with DX9 or DX11, try these out too.
- **Chromium Backend**: Set to `Vulkan` for embedded browser frames
- **Qt Rendering API**: Set to `OpenGL` for UI rendering

These settings are written to `NMachineSpecificOptions.xml` automatically after installation.

### Development Features

1. **Wine Prefix Backup**: Optional backup/restore of Wine prefix to speed up development iterations
   - Use `--create-backup` to backup after Wine setup
   - Use `--use-backup` to restore from backup and skip Wine setup

2. **State Tracking**: Creates `.install-state` file with installation metadata (version, timestamp, installer hash)

3. **Comprehensive Logging**: All installation output is logged to timestamped files in `~/.autodesk_fusion/logs/`

## Credits

This project is a NixOS wrapper around the original [Autodesk Fusion 360 for Linux](https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux) installer created by **[cryinkfly](https://cryinkfly.com/sponsors/)**.

All credit for the core installation logic and Wine configuration goes to cryinkfly. This flake simply packages it for NixOS users and adds a streamlined CLI interface.

Please consider [supporting cryinkfly](https://cryinkfly.com/sponsors/) for their excellent work making Fusion 360 available on Linux.

## License

This wrapper is licensed under the MIT License.

The original [Autodesk Fusion 360 for Linux](https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux) installer by cryinkfly has its own license terms.

Autodesk Fusion 360 itself is proprietary software owned by Autodesk, Inc. You must have a valid license to use it.
