{
  lib,
  stdenv,
  makeWrapper,
  installerSrc,
  gawk,
  cabextract,
  coreutils,
  curl,
  lsb-release,
  mesa-demos,
  p7zip,
  polkit,
  samba,
  spacenavd,
  wget,
  xdg-utils,
  bc,
  xorg,
  mokutil,
  wineWowPackages,
  winetricks,
  gettext,
}:

stdenv.mkDerivation rec {
  pname = "fusion360-installer";
  version = "2.0.4-alpha";

  src = installerSrc;

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [
    gawk
    cabextract
    coreutils
    curl
    lsb-release
    mesa-demos
    p7zip
    polkit
    samba
    spacenavd
    wget
    xdg-utils
    bc
    xorg.xrandr
    mokutil
    wineWowPackages.stable
    winetricks
    gettext
  ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/share/fusion360

    # Copy the original installation script
    cp ${installerSrc}/files/setup/autodesk_fusion_installer_x86-64.sh $out/share/fusion360/autodesk_fusion_installer_x86-64.sh  
    chmod +x $out/share/fusion360/autodesk_fusion_installer_x86-64.sh

    # Install the headless installer wrapper (backend)
    substitute ${./fusion360-installer-headless.sh} $out/bin/fusion360-install \
      --subst-var-by bin_path "${lib.makeBinPath buildInputs}" \
      --subst-var-by installer "$out/share/fusion360/autodesk_fusion_installer_x86-64.sh" \
      --subst-var-by version "${version}" \
      --subst-var-by installer_hash "${builtins.hashString "sha256" (builtins.readFile "${installerSrc}/files/setup/autodesk_fusion_installer_x86-64.sh")}"
    chmod +x $out/bin/fusion360-install

    # Install the runner (backend)
    substitute ${./fusion360-run.sh} $out/bin/fusion360-run \
      --subst-var-by bin_path "${lib.makeBinPath buildInputs}"
    chmod +x $out/bin/fusion360-run

    # Install the unified CLI (main entry point)
    substitute ${./fusion-cli.sh} $out/bin/fusion \
      --subst-var-by out "$out" \
      --subst-var-by bin_path "${lib.makeBinPath buildInputs}"
    chmod +x $out/bin/fusion

    runHook postInstall
  '';

  meta = with lib; {
    description = "Autodesk Fusion 360 on Linux via Wine with unified CLI";
    longDescription = ''
      This package provides Fusion 360 for Linux with a unified CLI:
      - fusion           - Main command with subcommands (install, update, uninstall, run)
      - fusion install   - Headless installation
      - fusion update    - Update/reinstall
      - fusion uninstall - Remove installation
      - fusion run       - Launch Fusion 360

      Features:
      - Automatically detects if Fusion 360 is installed
      - Runs headless installation on first use
      - Automatic graphics configuration (Vulkan + OpenGL + VirtualDeviceGLCore)
      - Fast flake evaluation (Wine setup only happens at runtime)

      The package follows Nix principles:
      - All immutable components are stored in /nix/store
      - Mutable Wine prefix and user data in ~/.autodesk_fusion
      - Idempotent installation (safe to run multiple times)

      Note: You need a valid Autodesk Fusion 360 license to use this software.
    '';
    homepage = "https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    mainProgram = "fusion";
  };
}
