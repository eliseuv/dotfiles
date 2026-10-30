{ pkgs, lib, defaultWorkspace ? null, ... }:
let
  configureWorkspace = pkgs.writeShellScript "chatgpt-default-workspace" ''
    ${pkgs.python3.withPackages (p: [ p.tomlkit ])}/bin/python ${./configure-workspace.py} ${lib.escapeShellArg (if defaultWorkspace == null then "" else defaultWorkspace)}
  '';
  # Nixpkgs' chatgpt package currently only provides the macOS app.
  # Keep OpenAI's Linux binaries intact in an FHS environment, including
  # the bundled browser, Node runtime and Codex subprocesses.
  app = pkgs.stdenvNoCC.mkDerivation {
    pname = "chatgpt-linux-unwrapped";
    version = "26.1027.30824";
    src = pkgs.fetchurl {
      url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
      sha256 = "4e139a44f7c917a643f2dd014ad32298dd30aec6d324d323524b190f7667684c";
    };
    nativeBuildInputs = [ pkgs.dpkg ];
    # Just an unpack of an unfree .deb, which no binary cache has. Also
    # changes the output path, retiring one whose bundled node was corrupted
    # by a defective DIMM: reverting this while that path is still in the
    # store would bring it back.
    preferLocalBuild = true;
    allowSubstitutes = false;
    unpackPhase = ''
      dpkg --fsys-tarfile "$src" | tar -x
    '';
    installPhase = ''
      mkdir -p "$out"
      cp -a usr/lib usr/share "$out/"
    '';
  };
in
pkgs.buildFHSEnv {
  name = "chatgpt";
  targetPkgs = p: with p; [
    alsa-lib at-spi2-core atk cairo cups dbus expat fontconfig freetype
    gdk-pixbuf glib gtk3 libGL libdrm libgbm libnotify libusb1 libxcb
    libxkbcommon nspr nss openssl pango stdenv.cc.cc systemd tpm2-tss
    libx11 libxcomposite libxdamage libxext libxfixes libxrandr libxshmfence
    libxcursor libxi libxtst libxscrnsaver
    libpulseaudio wayland pipewire vulkan-loader
    xdg-utils git bash coreutils xz zlib
  ];
  runScript = if defaultWorkspace == null then "${app}/lib/chatgpt/codex-launcher" else pkgs.writeShellScript "chatgpt-launcher" ''
    ${configureWorkspace}
    exec ${app}/lib/chatgpt/codex-launcher "$@"
  '';
  extraBwrapArgs = [ "--bind-try" "/etc/dotfiles" "/etc/dotfiles" ];
  extraInstallCommands = ''
    ln -s ${app}/share "$out/share"
  '';
  passthru = { inherit app configureWorkspace; };
  meta = {
    description = "Official ChatGPT desktop app for Linux";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
}
